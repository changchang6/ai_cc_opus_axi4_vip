//-----------------------------------------------------------------------------
// File: axi4_env.sv
// Description: AXI4 Verification Environment
//
//  Supports two configuration modes:
//
//  1. Multi-master (preferred) – set an axi4_env_cfg in config_db:
//       uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", env_cfg);
//     The env creates one axi4_master_agent per env_cfg.num_masters and
//     pushes the matching axi4_config to each agent.
//
//  2. Legacy single-master – set an axi4_config in config_db (old style):
//       uvm_config_db #(axi4_config)::set(this, "*", "m_cfg", cfg);
//     The env wraps it in an axi4_env_cfg transparently.
//-----------------------------------------------------------------------------

class axi4_env extends uvm_env;
    `uvm_component_utils(axi4_env)

    axi4_env_cfg      m_env_cfg;
    axi4_master_agent m_agents[];

    // Convenience handle: points to m_agents[0] for single-master tests
    axi4_master_agent m_agent;

    function new(string name = "axi4_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        _resolve_cfg();
        _build_agents();
    endfunction

    function void connect_phase(uvm_phase phase);
        // No cross-component connections needed at env level
    endfunction

    //-------------------------------------------------------------------------
    // Private helpers
    //-------------------------------------------------------------------------

    // Resolve configuration: prefer axi4_env_cfg; fall back to axi4_config.
    local function void _resolve_cfg();
        axi4_config        legacy_cfg;
        virtual axi4_system_if sys_vif;

        if (!uvm_config_db #(axi4_env_cfg)::get(this, "", "m_env_cfg", m_env_cfg)) begin
            // Fall back: build an env_cfg from a legacy axi4_config
            m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");
            m_env_cfg.num_masters = 1;

            if (uvm_config_db #(axi4_config)::get(this, "", "m_cfg", legacy_cfg)) begin
                m_env_cfg.master_addr_width    [0] = legacy_cfg.m_addr_width;
                m_env_cfg.master_data_width    [0] = legacy_cfg.m_data_width;
                m_env_cfg.master_id_width      [0] = legacy_cfg.m_id_width;
                m_env_cfg.max_read_outstanding [0] = legacy_cfg.m_max_read_outstanding;
                m_env_cfg.max_write_outstanding[0] = legacy_cfg.m_max_write_outstanding;
                m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout =
                    legacy_cfg.m_wtimeout;
                m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout =
                    legacy_cfg.m_rtimeout;
                m_env_cfg.m_vif    = new[1];
                m_env_cfg.m_vif[0] = legacy_cfg.m_vif;
            end else begin
                `uvm_warning("AXI4_ENV",
                    "Neither axi4_env_cfg nor axi4_config found in config_db. Using defaults.")
            end
        end

        // If m_vif not yet populated, try resolving from axi4_system_if.
        // Access master_vif[] (virtual axi4_if array) instead of master_if[]
        // (nested interface instance) to allow variable indexing.
        if (m_env_cfg.m_vif.size() < m_env_cfg.num_masters) begin
            if (uvm_config_db #(virtual axi4_system_if)::get(this, "*", "vif", sys_vif)) begin
                m_env_cfg.m_vif = new[m_env_cfg.num_masters];
                for (int i = 0; i < m_env_cfg.num_masters; i++)
                    m_env_cfg.m_vif[i] = sys_vif.master_vif[i];
            end
        end

        m_env_cfg.set_axi_system_cfg();
    endfunction

    // Create one agent per master and push its axi4_config.
    local function void _build_agents();
        m_agents = new[m_env_cfg.num_masters];
        for (int i = 0; i < m_env_cfg.num_masters; i++) begin
            string aname = $sformatf("m_agents_%0d", i);
            m_agents[i] = axi4_master_agent::type_id::create(aname, this);
            uvm_config_db #(axi4_config)::set(
                this, aname, "m_cfg", m_env_cfg.m_master_cfg[i]);
        end
        if (m_env_cfg.num_masters > 0)
            m_agent = m_agents[0];  // backward-compatibility shortcut
    endfunction

endclass : axi4_env
