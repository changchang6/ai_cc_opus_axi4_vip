//-----------------------------------------------------------------------------
// File: axi4_pkg.sv
// Description: AXI4 VIP Package
//-----------------------------------------------------------------------------

package axi4_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi4_types_pkg::*;

    `include "axi4_config.sv"
    `include "axi4_system_cfg.sv"
    `include "axi4_env_cfg.sv"
    `include "axi4_transaction.sv"
    `include "axi4_sequencer.sv"
    `include "axi4_master_driver.sv"
    `include "axi4_monitor.sv"
    `include "axi4_master_agent.sv"
    `include "axi4_env.sv"
    `include "axi4_base_sequence.sv"
    `include "axi4_base_test.sv"

endpackage : axi4_pkg
