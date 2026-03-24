//-----------------------------------------------------------------------------
// File: axi4_pkg.sv
// Description: AXI4 VIP Package
//-----------------------------------------------------------------------------

package axi4_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi4_types_pkg::*;

    // Compile-time bus-width configuration (SVT AXI naming convention).
    // Override by compiling with +define+SVT_AXI_MAX_DATA_WIDTH=1024 etc.
    `ifndef SVT_AXI_MAX_DATA_WIDTH
      `define SVT_AXI_MAX_DATA_WIDTH 32
    `endif
    `ifndef SVT_AXI_MAX_ADDR_WIDTH
      `define SVT_AXI_MAX_ADDR_WIDTH 32
    `endif
    `ifndef SVT_AXI_MAX_ID_WIDTH
      `define SVT_AXI_MAX_ID_WIDTH 4
    `endif
    `ifndef SVT_AXI_MAX_BURST_LENGTH_WIDTH
      `define SVT_AXI_MAX_BURST_LENGTH_WIDTH 8
    `endif
    `ifndef SVT_AXI_SIZE_WIDTH
      `define SVT_AXI_SIZE_WIDTH 3
    `endif
    `ifndef SVT_AXI_BURST_WIDTH
      `define SVT_AXI_BURST_WIDTH 2
    `endif
    `ifndef SVT_AXI_CACHE_WIDTH
      `define SVT_AXI_CACHE_WIDTH 4
    `endif
    `ifndef SVT_AXI_PROT_WIDTH
      `define SVT_AXI_PROT_WIDTH 3
    `endif
    `ifndef SVT_AXI_LOCK_WIDTH
      `define SVT_AXI_LOCK_WIDTH 1
    `endif
    `ifndef SVT_AXI_RESP_WIDTH
      `define SVT_AXI_RESP_WIDTH 2
    `endif
    `ifndef AXI_USER_WIDTH
      `define AXI_USER_WIDTH 1
    `endif
    // Single virtual-interface typedef used throughout the VIP.
    // All virtual axi4_if handles must use this alias so that the type is
    // consistent when the width is changed via the defines above.
    typedef virtual axi4_if #(.DATA_WIDTH(`SVT_AXI_MAX_DATA_WIDTH),
                               .ADDR_WIDTH(`SVT_AXI_MAX_ADDR_WIDTH),
                               .ID_WIDTH  (`SVT_AXI_MAX_ID_WIDTH)) axi4_vif_t;

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
    `include "axi4_base_test.sv"
    `include "axi4_fixed_len0_size7_test.sv"

endpackage : axi4_pkg
