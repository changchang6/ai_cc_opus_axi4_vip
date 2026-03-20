//-----------------------------------------------------------------------------
// File: axi4_tb_top.sv
// Description: AXI4 Testbench Top Module with simple slave model
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module axi4_tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi4_pkg::*;

    //-------------------------------------------------------------------------
    // Parameters
    //-------------------------------------------------------------------------
    parameter int DATA_WIDTH = 32;
    parameter int ADDR_WIDTH = 32;
    parameter int ID_WIDTH   = 4;

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
    axi4_if #(DATA_WIDTH, ADDR_WIDTH, ID_WIDTH) dut_if (clk, rst_n);

    //-------------------------------------------------------------------------
    // Simple Slave Model
    //-------------------------------------------------------------------------
    // Write path: accept AW+W, respond with B
    logic [ID_WIDTH-1:0]  s_awid;
    logic                 s_aw_pending;
    int                   s_w_beats_remaining;

    // AW channel: always ready
    assign dut_if.awready_m = 1'b1;

    // W channel: always ready
    assign dut_if.wready_m = 1'b1;

    // B channel: respond after wlast_m
    logic                s_bvalid;
    logic [ID_WIDTH-1:0] s_bid;
    logic [1:0]          s_bresp;

    assign dut_if.bvalid_m = s_bvalid;
    assign dut_if.bid_m    = s_bid;
    assign dut_if.bresp_m  = s_bresp;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_bvalid <= 0;
            s_bid    <= '0;
            s_bresp  <= 2'b00;
            s_awid   <= '0;
        end else begin
            // Capture AW id
            if (dut_if.awvalid_m && dut_if.awready_m)
                s_awid <= dut_if.awid_m;

            // Issue B after wlast_m
            if (dut_if.wvalid_m && dut_if.wready_m && dut_if.wlast_m) begin
                s_bvalid <= 1;
                s_bid    <= s_awid;
                s_bresp  <= 2'b00; // OKAY
            end else if (s_bvalid && dut_if.bready_m) begin
                s_bvalid <= 0;
            end
        end
    end

    // AR channel: always ready
    assign dut_if.arready_m = 1'b1;

    // R channel: respond with incrementing data
    logic                 s_rvalid;
    logic [ID_WIDTH-1:0]  s_rid;
    logic [DATA_WIDTH-1:0] s_rdata;
    logic [1:0]           s_rresp;
    logic                 s_rlast;
    logic [7:0]           s_r_beats_total;
    logic [7:0]           s_r_beat_cnt;
    logic [ID_WIDTH-1:0]  s_arid_latch;

    assign dut_if.rvalid_m = s_rvalid;
    assign dut_if.rid_m    = s_rid;
    assign dut_if.rdata_m  = s_rdata;
    assign dut_if.rresp_m  = s_rresp;
    assign dut_if.rlast_m  = s_rlast;

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
            if (dut_if.arvalid_m && dut_if.arready_m && !s_rvalid) begin
                // Start read response
                s_arid_latch    <= dut_if.arid_m;
                s_r_beats_total <= dut_if.arlen_m;
                s_r_beat_cnt    <= 0;
                s_rvalid        <= 1;
                s_rid           <= dut_if.arid_m;
                s_rdata         <= 32'hDEAD_0000;
                s_rresp         <= 2'b00;
                s_rlast         <= (dut_if.arlen_m == 0);
            end else if (s_rvalid && dut_if.rready_m) begin
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
    // UVM test launch
    //-------------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual axi4_if)::set(null, "uvm_test_top", "m_vif", dut_if);
        run_test("axi4_base_test");
    end

endmodule : axi4_tb_top
