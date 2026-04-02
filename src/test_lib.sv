//-----------------------------------------------------------------------------
// File: test_lib.sv
// Description: AXI4 VIP Test Library
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// axi4_base_test
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

//-----------------------------------------------------------------------------
// axi4_fixed_len0_size7_test
// Description: Test for axi4_fixed_len0_size7_seq (len=0, size=7, 128B/beat)
//              Requires DATA_WIDTH=1024 in axi4_tb_top.sv
//-----------------------------------------------------------------------------
class axi4_fixed_len0_size7_test extends uvm_test;
    `uvm_component_utils(axi4_fixed_len0_size7_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "axi4_fixed_len0_size7_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_fixed_len0_size7_seq seq;
        seq = axi4_fixed_len0_size7_seq::type_id::create("seq");
        seq.m_num_txns = 10;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : axi4_fixed_len0_size7_test

//-----------------------------------------------------------------------------
// burst_incr_test
// Description: Test for axi4_burst_incr_seq
//              len inside [1:16], size=max_width, burst=INCR
//              5000 write transactions followed by read-back verification
//-----------------------------------------------------------------------------
class burst_incr_test extends uvm_test;
    `uvm_component_utils(burst_incr_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "burst_incr_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_burst_incr_seq seq;
        seq = axi4_burst_incr_seq::type_id::create("seq");
        seq.m_num_txns = 5000;
        seq.c_addr_aligned.constraint_mode(0);  // Disable random address
        seq.m_start_addr = 32'h0;  // Fixed start address to avoid overlap
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : burst_incr_test

//-----------------------------------------------------------------------------
// burst_fixed_test
// Description: Test for axi4_burst_fixed_seq
//              len inside [1:16], size=max_width, burst=FIXED
//              5000 write transactions followed by read-back verification
//-----------------------------------------------------------------------------
class burst_fixed_test extends uvm_test;
    `uvm_component_utils(burst_fixed_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "burst_fixed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_burst_fixed_seq seq;
        seq = axi4_burst_fixed_seq::type_id::create("seq");
        seq.m_num_txns = 5000;
        seq.c_addr_aligned.constraint_mode(0);
        seq.m_start_addr = 32'h0;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : burst_fixed_test

//-----------------------------------------------------------------------------
// burst_wrap_test
// Description: Test for axi4_burst_wrap_seq
//              len inside {1,3,7,15}, size=max_width, burst=WRAP
//              5000 write transactions followed by read-back verification
//-----------------------------------------------------------------------------
class burst_wrap_test extends uvm_test;
    `uvm_component_utils(burst_wrap_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "burst_wrap_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_burst_wrap_seq seq;
        seq = axi4_burst_wrap_seq::type_id::create("seq");
        seq.m_num_txns = 5000;
        seq.m_start_addr = 32'h0;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : burst_wrap_test

//-----------------------------------------------------------------------------
// burst_random_test
// Description: Test for axi4_burst_random_seq
//              len inside [1:16], size=max_width, burst=random
//              5000 write transactions followed by read-back verification
//-----------------------------------------------------------------------------
class burst_random_test extends uvm_test;
    `uvm_component_utils(burst_random_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "burst_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_burst_random_seq seq;
        seq = axi4_burst_random_seq::type_id::create("seq");
        seq.m_num_txns = 5000;
        seq.c_addr_aligned.constraint_mode(0);
        seq.m_start_addr = 32'h0;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : burst_random_test

//-----------------------------------------------------------------------------
// burst_slice_test
// Description: Test for axi4_burst_slice_seq
//              len inside [16:256], size=max_width, burst=INCR
//              5000 write transactions followed by read-back verification
//-----------------------------------------------------------------------------
class burst_slice_test extends uvm_test;
    `uvm_component_utils(burst_slice_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "burst_slice_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_burst_slice_seq seq;
        seq = axi4_burst_slice_seq::type_id::create("seq");
        seq.m_num_txns = 5000;
        seq.c_addr_aligned.constraint_mode(0);
        seq.m_start_addr = 32'h0;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : burst_slice_test

//-----------------------------------------------------------------------------
// unaligned_addr_test
// Description: Test for axi4_unaligned_addr_seq
//              len inside [1:256], size=max_width, burst=INCR
//              50 iterations * 100 txns = 5000 write transactions with unaligned addresses
//              followed by read-back verification
//-----------------------------------------------------------------------------
class unaligned_addr_test extends uvm_test;
    `uvm_component_utils(unaligned_addr_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "unaligned_addr_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_unaligned_addr_seq seq;
        seq = axi4_unaligned_addr_seq::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : unaligned_addr_test

//-----------------------------------------------------------------------------
// narrow_test
// Description: Test for axi4_narrow_seq
//              len inside [0:255], size inside {byte,half-word,word}, burst=INCR
//              Random start address (aligned/unaligned), 50 write transactions
//              followed by read-back verification
//-----------------------------------------------------------------------------
class narrow_test extends uvm_test;
    `uvm_component_utils(narrow_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "narrow_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_narrow_seq seq;
        seq = axi4_narrow_seq::type_id::create("seq");
        seq.m_num_txns = 5000;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : narrow_test

//-----------------------------------------------------------------------------
// para_cfg1_test
// Description: Test with cfg1 parameters (data_width=64, addr_width=48, ID_width=5)
//              5000 write transactions followed by read-back verification
//-----------------------------------------------------------------------------
class para_cfg1_test extends uvm_test;
    `uvm_component_utils(para_cfg1_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "para_cfg1_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        // cfg1 parameters: data_width=64, addr_width=48, ID_width=5
        m_env_cfg.master_addr_width    [0] = 48;
        m_env_cfg.master_data_width    [0] = 64;
        m_env_cfg.master_id_width      [0] = 5;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_max_width_seq seq;
        seq = axi4_max_width_seq::type_id::create("seq");
        seq.m_num_txns = 5000;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : para_cfg1_test

//-----------------------------------------------------------------------------
// boundary_2k_test
// Description: Test for axi4_boundary_2k_seq
//              len=16, size=max_width, burst=INCR
//              50 write transactions crossing 2K boundary
//              followed by read-back verification
//-----------------------------------------------------------------------------
class boundary_2k_test extends uvm_test;
    `uvm_component_utils(boundary_2k_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "boundary_2k_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_boundary_2k_seq seq;
        seq = axi4_boundary_2k_seq::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : boundary_2k_test

//-----------------------------------------------------------------------------
// performance_stat_test
// Description: Test for axi4_performance_stat_seq
//              len inside [1:16], size=max_width, burst=INCR
//              Back-to-back 5000 write transactions with slave ready always high
//              followed by read-back verification
//-----------------------------------------------------------------------------
class performance_stat_test extends uvm_test;
    `uvm_component_utils(performance_stat_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "performance_stat_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_performance_stat_seq seq;
        seq = axi4_performance_stat_seq::type_id::create("seq");
        seq.m_num_txns = 5000;
        seq.c_addr_aligned.constraint_mode(0);
        seq.m_start_addr = 32'h0;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : performance_stat_test

//-----------------------------------------------------------------------------
// data_first_test
// Description: Test for axi4_data_first_seq
//              len inside {legal num}, size=max_width, burst=INCR
//              data_before_addr enabled, before_delay configured
//              500 write transactions followed by read-back verification
//-----------------------------------------------------------------------------
class data_first_test extends uvm_test;
    `uvm_component_utils(data_first_test)

    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function new(string name = "data_first_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                  .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                  .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) sys_vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = 1;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        m_env_cfg.master_addr_width    [0] = `AI_AXI4_MAX_ADDR_WIDTH;
        m_env_cfg.master_data_width    [0] = `AI_AXI4_MAX_DATA_WIDTH;
        m_env_cfg.master_id_width      [0] = `AI_AXI4_MAX_ID_WIDTH;
        m_env_cfg.ruser_enable         [0] = 0;
        m_env_cfg.aruser_enable        [0] = 0;
        m_env_cfg.awuser_enable        [0] = 0;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        if (!uvm_config_db #(virtual axi4_system_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                                                       .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                                                       .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)))::get(
                             this, "", "vif", sys_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual system interface from config_db")
        m_env_cfg.m_vif = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++)
            m_env_cfg.m_vif[i] = sys_vif.master_vif[i];

        // Enable data-before-addr for master 0
        m_env_cfg.master_data_before_addr    [0] = 1;
        m_env_cfg.master_data_before_addr_osd[0] = 4;

        m_env_cfg.set_axi_system_cfg();

        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_data_first_seq seq;
        seq = axi4_data_first_seq::type_id::create("seq");
        seq.m_num_txns = 500;
        seq.c_addr_aligned.constraint_mode(0);
        seq.m_start_addr = 32'h0;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);
        phase.drop_objection(this);
    endtask

endclass : data_first_test
