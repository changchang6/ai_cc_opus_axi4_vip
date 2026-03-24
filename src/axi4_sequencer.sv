//-----------------------------------------------------------------------------
// File: axi4_sequencer.sv
// Description: AXI4 Sequencer
//-----------------------------------------------------------------------------

class axi4_sequencer extends uvm_sequencer #(axi4_transaction);
    `uvm_component_utils(axi4_sequencer)

    function new(string name = "axi4_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        uvm_object_wrapper seq_type;
        if (!uvm_config_db #(uvm_object_wrapper)::get(
                this, "main_phase", "default_sequence", seq_type))
            `uvm_fatal("AXI4_SEQ",
                $sformatf("No sequence set on sequencer main_phase. sequencer path: %s",
                          get_full_name()))
    endfunction

endclass : axi4_sequencer
