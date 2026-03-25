//-----------------------------------------------------------------------------
// File: axi4_base_test.sv
// Description: AXI4 Base Test – demonstrates axi4_env_cfg multi-master flow
//-----------------------------------------------------------------------------

class axi4_base_test extends uvm_test;
    `uvm_component_utils(axi4_base_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "axi4_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        // --- Create and configure env_cfg ---
        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        // Top-level settings
        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        // Per-master settings (index 0 only for single-master test)
        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        // Virtual interface (provided by tb_top via config_db)
        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        // Finalise: build internal per-master axi4_config objects
        m_env_cfg.set_axi_system_cfg();

        // Push env_cfg to config_db
        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_rand_seq seq;
        seq = axi4_rand_seq::type_id::create("rand_seq");
        seq.m_num_txns = 20;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : axi4_base_test
