//-----------------------------------------------------------------------------
// File: axi4_env.sv
// Description: AXI4 Verification Environment
//-----------------------------------------------------------------------------

class axi4_env extends uvm_env;
    `uvm_component_utils(axi4_env)

    axi4_master_agent m_agent;

    function new(string name = "axi4_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_agent = axi4_master_agent::type_id::create("m_agent", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // No cross-component connections needed at env level
    endfunction

endclass : axi4_env
