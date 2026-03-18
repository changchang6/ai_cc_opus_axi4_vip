//-----------------------------------------------------------------------------
// File: axi4_base_test.sv
// Description: AXI4 Base Test
//-----------------------------------------------------------------------------

class axi4_base_test extends uvm_test;
    `uvm_component_utils(axi4_base_test)

    axi4_env    m_env;
    axi4_config m_cfg;

    function new(string name = "axi4_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_cfg = axi4_config::type_id::create("m_cfg");

        // Get virtual interface from config_db (set by tb_top)
        if (!uvm_config_db #(virtual axi4_if)::get(this, "", "m_vif", m_cfg.m_vif))
            `uvm_fatal("AXI4_TEST", "Cannot get virtual interface from config_db")

        // Push config down to all components
        uvm_config_db #(axi4_config)::set(this, "*", "m_cfg", m_cfg);

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
