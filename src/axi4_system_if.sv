//-----------------------------------------------------------------------------
// File: axi4_system_if.sv
// Description: AXI4 System Interface - contains a parameterized array of
//              axi4_if instances to support multiple master agents.
//
// Usage example (testbench top):
//   axi4_system_if #(.NUM_MASTERS(4)) axi_mst_if (.clk(clk), .rst_n(rst_n));
//
// Usage example (UVM test / sequence):
//   force araddr = axi_mst_if.master_if[0].araddr;
//   uvm_config_db #(virtual axi4_if)::set(null, path, "m_vif",
//                                         axi_mst_if.master_if[i]);
//-----------------------------------------------------------------------------

interface axi4_system_if #(
    parameter int NUM_MASTERS = 1,
    parameter int DATA_WIDTH  = 32,
    parameter int ADDR_WIDTH  = 32,
    parameter int ID_WIDTH    = 4
)(
    input logic clk,
    input logic rst_n
);

    //-------------------------------------------------------------------------
    // Array of per-master AXI4 interfaces
    //-------------------------------------------------------------------------
    // Each element is a full axi4_if instance accessible as:
    //   master_if[i].araddr, master_if[i].awvalid, etc.
    //-------------------------------------------------------------------------
    axi4_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH  (ID_WIDTH)
    ) master_if [NUM_MASTERS] (
        .clk  (clk),
        .rst_n(rst_n)
    );

endinterface : axi4_system_if
