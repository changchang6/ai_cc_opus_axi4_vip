//-----------------------------------------------------------------------------
// File: axi4_pkg.sv
// Description: AXI4 VIP Package
//-----------------------------------------------------------------------------

package axi4_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi4_types_pkg::*;

    // Compile-time bus-width configuration (AI AXI4 naming convention).
    // Override by compiling with +define+AI_AXI4_MAX_DATA_WIDTH=1024 etc.
    `ifndef AI_AXI4_MAX_DATA_WIDTH
      `define AI_AXI4_MAX_DATA_WIDTH 32
    `endif
    `ifndef AI_AXI4_MAX_ADDR_WIDTH
      `define AI_AXI4_MAX_ADDR_WIDTH 32
    `endif
    `ifndef AI_AXI4_MAX_ID_WIDTH
      `define AI_AXI4_MAX_ID_WIDTH 4
    `endif
    `ifndef AI_AXI4_MAX_BURST_LENGTH_WIDTH
      `define AI_AXI4_MAX_BURST_LENGTH_WIDTH 8
    `endif
    `ifndef AI_AXI4_SIZE_WIDTH
      `define AI_AXI4_SIZE_WIDTH 3
    `endif
    `ifndef AI_AXI4_BURST_WIDTH
      `define AI_AXI4_BURST_WIDTH 2
    `endif
    `ifndef AI_AXI4_CACHE_WIDTH
      `define AI_AXI4_CACHE_WIDTH 4
    `endif
    `ifndef AI_AXI4_PROT_WIDTH
      `define AI_AXI4_PROT_WIDTH 3
    `endif
    `ifndef AI_AXI4_LOCK_WIDTH
      `define AI_AXI4_LOCK_WIDTH 1
    `endif
    `ifndef AI_AXI4_RESP_WIDTH
      `define AI_AXI4_RESP_WIDTH 2
    `endif
    `ifndef AXI_USER_WIDTH
      `define AXI_USER_WIDTH 1
    `endif
    // Single virtual-interface typedef used throughout the VIP.
    // All virtual axi4_if handles must use this alias so that the type is
    // consistent when the width is changed via the defines above.
    typedef virtual axi4_if #(.DATA_WIDTH(`AI_AXI4_MAX_DATA_WIDTH),
                               .ADDR_WIDTH(`AI_AXI4_MAX_ADDR_WIDTH),
                               .ID_WIDTH  (`AI_AXI4_MAX_ID_WIDTH)) axi4_vif_t;

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
    `include "seq_lib.sv"
    `include "test_lib.sv"

endpackage : axi4_pkg
