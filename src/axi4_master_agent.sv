//-----------------------------------------------------------------------------
// File: axi4_master_agent.sv
// Description: AXI4 Master Agent
//-----------------------------------------------------------------------------

class axi4_master_agent extends uvm_agent;
    `uvm_component_utils(axi4_master_agent)

    axi4_config         m_cfg;
    axi4_master_driver  m_driver;
    axi4_sequencer      m_sequencer;
    axi4_monitor        m_monitor;

    function new(string name = "axi4_master_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(axi4_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("AXI4_AGT", "Cannot get axi4_config from config_db")

        m_monitor = axi4_monitor::type_id::create("m_monitor", this);

        if (m_cfg.m_is_active == UVM_ACTIVE) begin
            m_driver    = axi4_master_driver::type_id::create("m_driver",    this);
            m_sequencer = axi4_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (m_cfg.m_is_active == UVM_ACTIVE)
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    endfunction

endclass : axi4_master_agent
