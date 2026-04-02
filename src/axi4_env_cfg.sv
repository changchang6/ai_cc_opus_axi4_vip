//-----------------------------------------------------------------------------
// File: axi4_env_cfg.sv
// Description: AXI4 VIP Multi-Master Environment Configuration Object
//
//  Usage pattern (mirrors Cadence/Synopsys VIP style):
//
//    axi4_env_cfg env_cfg = axi4_env_cfg::type_id::create("env_cfg");
//
//    // Step 1 – top-level settings
//    env_cfg.num_masters                               = 2;
//    env_cfg.num_slaves                                = 0;
//    env_cfg.slave_is_active                           = 0;
//    env_cfg.axi4_en                                   = 1;
//    env_cfg.use_slave_with_overlapping_addr           = 0;
//    env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
//    env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
//    env_cfg.clk_freq_mhz                              = 1000;
//    env_cfg.enable_perf_mon                           = 0;
//
//    // Step 2 – per-master settings (index 0 … num_masters-1)
//    for (int idx = 0; idx < 2; idx++) begin
//        env_cfg.master_addr_width    [idx] = 32;
//        env_cfg.master_data_width    [idx] = 64;
//        env_cfg.master_id_width      [idx] = 4;
//        env_cfg.ruser_enable         [idx] = 0;
//        env_cfg.aruser_enable        [idx] = 0;
//        env_cfg.awuser_enable        [idx] = 0;
//        env_cfg.max_read_outstanding [idx] = 8;
//        env_cfg.max_write_outstanding[idx] = 8;
//    end
//
//    // Step 3 – set virtual interfaces (one per master)
//    env_cfg.m_vif = new[2];
//    env_cfg.m_vif[0] = vif0;
//    env_cfg.m_vif[1] = vif1;
//
//    // Step 4 – finalise: builds internal per-master axi4_config objects
//    env_cfg.set_axi_system_cfg();
//
//    // Step 5 – push to config_db
//    uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", env_cfg);
//-----------------------------------------------------------------------------

// Maximum number of masters supported per environment instance.
// Increase if your design requires more masters.
`ifndef AXI4_ENV_CFG_MAX_MASTERS
  `define AXI4_ENV_CFG_MAX_MASTERS 32
`endif

class axi4_env_cfg extends uvm_object;
    `uvm_object_utils(axi4_env_cfg)

    //-------------------------------------------------------------------------
    // Top-level environment settings
    //-------------------------------------------------------------------------

    // Allow slave address regions to overlap
    bit          use_slave_with_overlapping_addr = 0;

    // Number of active master agents to create
    int unsigned num_masters                     = 1;

    // Number of slave agents (currently informational; set to 0 for master-only)
    int unsigned num_slaves                      = 0;

    // When 1, slave agents are set to UVM_ACTIVE; when 0, UVM_PASSIVE
    bit          slave_is_active                 = 0;

    // Enable AXI4 protocol (set 0 to run in AXI3-compatible mode)
    bit          axi4_en                         = 1;

    // Clock frequency in MHz (informational; used for timeout calculations)
    int unsigned clk_freq_mhz                    = 1000;

    // Enable performance monitoring in monitors
    bit          enable_perf_mon                 = 0;

    //-------------------------------------------------------------------------
    // Nested system-level config (watchdog timeouts, address-overlap policy)
    //-------------------------------------------------------------------------
    axi4_system_cfg u_axi_system_cfg;

    //-------------------------------------------------------------------------
    // Per-master parameters (fixed-size arrays; valid indices 0..num_masters-1)
    //-------------------------------------------------------------------------
    int unsigned master_addr_width    [`AXI4_ENV_CFG_MAX_MASTERS];
    int unsigned master_data_width    [`AXI4_ENV_CFG_MAX_MASTERS];
    int unsigned master_id_width      [`AXI4_ENV_CFG_MAX_MASTERS];

    // User-signal enables (AWUSER / ARUSER / RUSER)
    bit          awuser_enable        [`AXI4_ENV_CFG_MAX_MASTERS];
    bit          aruser_enable        [`AXI4_ENV_CFG_MAX_MASTERS];
    bit          ruser_enable         [`AXI4_ENV_CFG_MAX_MASTERS];

    // Outstanding transaction limits per master
    int unsigned max_read_outstanding [`AXI4_ENV_CFG_MAX_MASTERS];
    int unsigned max_write_outstanding[`AXI4_ENV_CFG_MAX_MASTERS];

    // Data-before-address per master
    bit          master_data_before_addr    [`AXI4_ENV_CFG_MAX_MASTERS];
    int unsigned master_data_before_addr_osd[`AXI4_ENV_CFG_MAX_MASTERS];

    //-------------------------------------------------------------------------
    // Virtual interface array – set one entry per master before calling
    // set_axi_system_cfg().  The array must be sized to at least num_masters.
    //-------------------------------------------------------------------------
    axi4_vif_t m_vif[];

    //-------------------------------------------------------------------------
    // Internal: per-master axi4_config objects (populated by set_axi_system_cfg)
    //-------------------------------------------------------------------------
    axi4_config m_master_cfg[];

    //-------------------------------------------------------------------------
    function new(string name = "axi4_env_cfg");
        super.new(name);
        u_axi_system_cfg = axi4_system_cfg::type_id::create("u_axi_system_cfg");
        // Initialise per-master arrays to sensible defaults
        for (int i = 0; i < `AXI4_ENV_CFG_MAX_MASTERS; i++) begin
            master_addr_width    [i] = 32;
            master_data_width    [i] = 32;
            master_id_width      [i] = 4;
            awuser_enable        [i] = 0;
            aruser_enable        [i] = 0;
            ruser_enable         [i] = 0;
            max_read_outstanding [i] = 8;
            max_write_outstanding[i] = 8;
        end
    endfunction

    //-------------------------------------------------------------------------
    // set_axi_system_cfg
    //
    // Call this method after all parameters have been configured.
    // It:
    //   1. Propagates use_slave_with_overlapping_addr to u_axi_system_cfg.
    //   2. Allocates and populates one axi4_config per master from the
    //      per-master arrays.
    //   3. Assigns virtual interfaces to each master config (if m_vif is set).
    //-------------------------------------------------------------------------
    function void set_axi_system_cfg();
        // Propagate address-overlap policy
        u_axi_system_cfg.allow_slaves_with_overlapping_addr =
            use_slave_with_overlapping_addr;

        // Build per-master axi4_config objects
        m_master_cfg = new[num_masters];
        for (int i = 0; i < num_masters; i++) begin
            m_master_cfg[i] = axi4_config::type_id::create(
                                  $sformatf("m_master_cfg_%0d", i));

            m_master_cfg[i].m_addr_width           = master_addr_width[i];
            m_master_cfg[i].m_data_width           = master_data_width[i];
            m_master_cfg[i].m_id_width             = master_id_width[i];
            m_master_cfg[i].m_max_read_outstanding  = max_read_outstanding[i];
            m_master_cfg[i].m_max_write_outstanding = max_write_outstanding[i];
            m_master_cfg[i].m_max_outstanding       = max_read_outstanding[i];

            // Map system watchdog timeouts to per-master timeouts
            m_master_cfg[i].m_wtimeout = u_axi_system_cfg.awready_watchdog_timeout;
            m_master_cfg[i].m_rtimeout = u_axi_system_cfg.arready_watchdog_timeout;

            m_master_cfg[i].m_support_data_before_addr = master_data_before_addr[i];
            m_master_cfg[i].m_data_before_addr_osd     = master_data_before_addr_osd[i];

            // Masters are always UVM_ACTIVE (slaves honour slave_is_active)
            m_master_cfg[i].m_is_active = UVM_ACTIVE;

            // Assign virtual interface if available
            if (m_vif.size() > i)
                m_master_cfg[i].m_vif = m_vif[i];
        end
    endfunction

    //-------------------------------------------------------------------------
    function string convert2string();
        string s;
        s = $sformatf(
            "axi4_env_cfg: num_masters=%0d num_slaves=%0d axi4_en=%0b slave_active=%0b clk=%0dMHz perf_mon=%0b ovlp_addr=%0b\n",
            num_masters, num_slaves, axi4_en, slave_is_active,
            clk_freq_mhz, enable_perf_mon, use_slave_with_overlapping_addr
        );
        s = {s, "  ", u_axi_system_cfg.convert2string(), "\n"};
        for (int i = 0; i < num_masters; i++) begin
            s = {s, $sformatf(
                "  master[%0d]: addr_w=%0d data_w=%0d id_w=%0d rd_osd=%0d wr_osd=%0d awuser=%0b aruser=%0b ruser=%0b\n",
                i,
                master_addr_width[i], master_data_width[i], master_id_width[i],
                max_read_outstanding[i], max_write_outstanding[i],
                awuser_enable[i], aruser_enable[i], ruser_enable[i]
            )};
        end
        return s;
    endfunction

endclass : axi4_env_cfg
