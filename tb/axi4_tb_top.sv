//-----------------------------------------------------------------------------
// File: axi4_tb_top.sv
// Description: AXI4 Testbench Top Module with simple slave model
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module axi4_tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi4_pkg::*;

    // Parameters – inherit compile-time bus-width from SVT_AXI defines
    `ifndef SVT_AXI_MAX_DATA_WIDTH
      `define SVT_AXI_MAX_DATA_WIDTH 32
    `endif
    `ifndef SVT_AXI_MAX_ADDR_WIDTH
      `define SVT_AXI_MAX_ADDR_WIDTH 32
    `endif
    `ifndef SVT_AXI_MAX_ID_WIDTH
      `define SVT_AXI_MAX_ID_WIDTH 4
    `endif
    parameter int DATA_WIDTH = `SVT_AXI_MAX_DATA_WIDTH;
    parameter int ADDR_WIDTH = `SVT_AXI_MAX_ADDR_WIDTH;
    parameter int ID_WIDTH   = `SVT_AXI_MAX_ID_WIDTH;

    //-------------------------------------------------------------------------
    // Clock and Reset
    //-------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
    end

    //-------------------------------------------------------------------------
    // Interface instantiation
    //-------------------------------------------------------------------------
    axi4_system_if #(.NUM_MASTERS(1), .DATA_WIDTH(DATA_WIDTH),
                     .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH))
        sys_if (.clk(clk), .rst_n(rst_n));

    //-------------------------------------------------------------------------
    // Simple Slave Model
    //-------------------------------------------------------------------------
    // Write path: accept AW+W, respond with B
    logic [ID_WIDTH-1:0]  s_awid;
    logic                 s_aw_pending;
    int                   s_w_beats_remaining;

    // AW channel: always ready
    assign sys_if.master_if[0].awready = 1'b1;

    // W channel: always ready
    assign sys_if.master_if[0].wready = 1'b1;

    // B channel: respond after wlast
    logic                s_bvalid;
    logic [ID_WIDTH-1:0] s_bid;
    logic [1:0]          s_bresp;

    assign sys_if.master_if[0].bvalid = s_bvalid;
    assign sys_if.master_if[0].bid    = s_bid;
    assign sys_if.master_if[0].bresp  = s_bresp;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_bvalid <= 0;
            s_bid    <= '0;
            s_bresp  <= 2'b00;
            s_awid   <= '0;
        end else begin
            // Capture AW id
            if (sys_if.master_if[0].awvalid && sys_if.master_if[0].awready)
                s_awid <= sys_if.master_if[0].awid;

            // Issue B after wlast
            if (sys_if.master_if[0].wvalid && sys_if.master_if[0].wready && sys_if.master_if[0].wlast) begin
                s_bvalid <= 1;
                s_bid    <= s_awid;
                s_bresp  <= 2'b00; // OKAY
            end else if (s_bvalid && sys_if.master_if[0].bready) begin
                s_bvalid <= 0;
            end
        end
    end

    // AR channel: always ready
    assign sys_if.master_if[0].arready = 1'b1;

    // R channel: respond with incrementing data
    logic                 s_rvalid;
    logic [ID_WIDTH-1:0]  s_rid;
    logic [DATA_WIDTH-1:0] s_rdata;
    logic [1:0]           s_rresp;
    logic                 s_rlast;
    logic [7:0]           s_r_beats_total;
    logic [7:0]           s_r_beat_cnt;
    logic [ID_WIDTH-1:0]  s_arid_latch;

    assign sys_if.master_if[0].rvalid = s_rvalid;
    assign sys_if.master_if[0].rid    = s_rid;
    assign sys_if.master_if[0].rdata  = s_rdata;
    assign sys_if.master_if[0].rresp  = s_rresp;
    assign sys_if.master_if[0].rlast  = s_rlast;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_rvalid        <= 0;
            s_rid           <= '0;
            s_rdata         <= '0;
            s_rresp         <= 2'b00;
            s_rlast         <= 0;
            s_r_beats_total <= 0;
            s_r_beat_cnt    <= 0;
            s_arid_latch    <= '0;
        end else begin
            if (sys_if.master_if[0].arvalid && sys_if.master_if[0].arready && !s_rvalid) begin
                // Start read response
                s_arid_latch    <= sys_if.master_if[0].arid;
                s_r_beats_total <= sys_if.master_if[0].arlen;
                s_r_beat_cnt    <= 0;
                s_rvalid        <= 1;
                s_rid           <= sys_if.master_if[0].arid;
                s_rdata         <= 32'hDEAD_0000;
                s_rresp         <= 2'b00;
                s_rlast         <= (sys_if.master_if[0].arlen == 0);
            end else if (s_rvalid && sys_if.master_if[0].rready) begin
                if (s_rlast) begin
                    s_rvalid <= 0;
                    s_rlast  <= 0;
                end else begin
                    s_r_beat_cnt <= s_r_beat_cnt + 1;
                    s_rdata      <= s_rdata + 1;
                    s_rlast      <= (s_r_beat_cnt + 1 == s_r_beats_total);
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // Waveform dump
    //-------------------------------------------------------------------------
`ifdef DUMP_WAVE
    initial begin
        string fsdb_file;
        if (!$value$plusargs("FSDB_FILE=%s", fsdb_file))
            fsdb_file = "sim";
        $fsdbDumpfile({fsdb_file, ".fsdb"});
        $fsdbDumpvars(0, axi4_tb_top);
    end
`endif

    //-------------------------------------------------------------------------
    // UVM test launch
    //-------------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual axi4_system_if #(.NUM_MASTERS(1), .DATA_WIDTH(DATA_WIDTH),
                        .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH)))::set(
                        null, "uvm_test_top", "vif", sys_if);
        run_test();
    end

endmodule : axi4_tb_top
