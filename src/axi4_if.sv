//-----------------------------------------------------------------------------
// File: axi4_if.sv
// Description: AXI4 Interface with clocking blocks, modports, and SVA assertions
//-----------------------------------------------------------------------------

interface axi4_if #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int ID_WIDTH   = 4
)(
    input logic clk,
    input logic rst_n
);

    // Write Address Channel
    logic [ADDR_WIDTH-1:0]  awaddr;
    logic [ID_WIDTH-1:0]    awid;
    logic [7:0]             awlen;
    logic [2:0]             awsize;
    logic [1:0]             awburst;
    logic                   awlock;
    logic [3:0]             awcache;
    logic [2:0]             awprot;
    logic [3:0]             awqos;
    logic [3:0]             awregion;
    logic                   awvalid;
    logic                   awready;

    // Write Data Channel
    logic [DATA_WIDTH-1:0]      wdata;
    logic [DATA_WIDTH/8-1:0]    wstrb;
    logic                       wlast;
    logic                       wvalid;
    logic                       wready;

    // Write Response Channel
    logic [ID_WIDTH-1:0]    bid;
    logic [1:0]             bresp;
    logic                   bvalid;
    logic                   bready;

    // Read Address Channel
    logic [ADDR_WIDTH-1:0]  araddr;
    logic [ID_WIDTH-1:0]    arid;
    logic [7:0]             arlen;
    logic [2:0]             arsize;
    logic [1:0]             arburst;
    logic                   arlock;
    logic [3:0]             arcache;
    logic [2:0]             arprot;
    logic [3:0]             arqos;
    logic [3:0]             arregion;
    logic                   arvalid;
    logic                   arready;

    // Read Data Channel
    logic [DATA_WIDTH-1:0]  rdata;
    logic [ID_WIDTH-1:0]    rid;
    logic [1:0]             rresp;
    logic                   rlast;
    logic                   rvalid;
    logic                   rready;

    //-------------------------------------------------------------------------
    // Clocking Blocks
    //-------------------------------------------------------------------------
    clocking master_cb @(posedge clk);
        default input #1step output #1;
        // Write Address Channel - outputs
        output awaddr, awid, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awvalid;
        input  awready;
        // Write Data Channel - outputs
        output wdata, wstrb, wlast, wvalid;
        input  wready;
        // Write Response Channel - inputs
        output bready;
        input  bid, bresp, bvalid;
        // Read Address Channel - outputs
        output araddr, arid, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arregion, arvalid;
        input  arready;
        // Read Data Channel - inputs
        output rready;
        input  rid, rdata, rresp, rlast, rvalid;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input awaddr, awid, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awregion, awvalid, awready;
        input wdata, wstrb, wlast, wvalid, wready;
        input bid, bresp, bvalid, bready;
        input araddr, arid, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arregion, arvalid, arready;
        input rid, rdata, rresp, rlast, rvalid, rready;
    endclocking

    //-------------------------------------------------------------------------
    // Modports
    //-------------------------------------------------------------------------
    modport master_mp  (clocking master_cb,  input clk, rst_n);
    modport monitor_mp (clocking monitor_cb, input clk, rst_n);

    //-------------------------------------------------------------------------
    // Beat counters for WLAST/RLAST assertions
    //-------------------------------------------------------------------------
    int aw_beat_cnt;
    int ar_beat_cnt;
    logic [7:0] aw_len_latch;
    logic [7:0] ar_len_latch;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_beat_cnt  <= 0;
            aw_len_latch <= 0;
        end else begin
            if (awvalid && awready) begin
                aw_len_latch <= awlen;
                aw_beat_cnt  <= 0;
            end else if (wvalid && wready) begin
                aw_beat_cnt <= aw_beat_cnt + 1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_beat_cnt  <= 0;
            ar_len_latch <= 0;
        end else begin
            if (arvalid && arready) begin
                ar_len_latch <= arlen;
                ar_beat_cnt  <= 0;
            end else if (rvalid && rready) begin
                ar_beat_cnt <= ar_beat_cnt + 1;
            end
        end
    end

    //-------------------------------------------------------------------------
    // SVA Assertions
    //-------------------------------------------------------------------------

    // 1. AWVALID stable: once asserted, must hold until AWREADY
    property p_awvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (awvalid && !awready) |=> awvalid;
    endproperty
    AST_AWVALID_STABLE: assert property (p_awvalid_stable)
        else $error("AST_AWVALID_STABLE: AWVALID deasserted before AWREADY");

    // 2. ARVALID stable: once asserted, must hold until ARREADY
    property p_arvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (arvalid && !arready) |=> arvalid;
    endproperty
    AST_ARVALID_STABLE: assert property (p_arvalid_stable)
        else $error("AST_ARVALID_STABLE: ARVALID deasserted before ARREADY");

    // 3. WVALID stable: once asserted, must hold until WREADY
    property p_wvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (wvalid && !wready) |=> wvalid;
    endproperty
    AST_WVALID_STABLE: assert property (p_wvalid_stable)
        else $error("AST_WVALID_STABLE: WVALID deasserted before WREADY");

    // 4. WLAST correct: wlast must be high only on beat awlen+1
    property p_wlast_correct;
        @(posedge clk) disable iff (!rst_n)
        (wvalid && wready) |->
            (wlast == (aw_beat_cnt == aw_len_latch));
    endproperty
    AST_WLAST_CORRECT: assert property (p_wlast_correct)
        else $error("AST_WLAST_CORRECT: WLAST incorrect at beat %0d (expected beat %0d)", aw_beat_cnt, aw_len_latch);

    // 5. RLAST correct: rlast must be high only on beat arlen+1
    property p_rlast_correct;
        @(posedge clk) disable iff (!rst_n)
        (rvalid && rready) |->
            (rlast == (ar_beat_cnt == ar_len_latch));
    endproperty
    AST_RLAST_CORRECT: assert property (p_rlast_correct)
        else $error("AST_RLAST_CORRECT: RLAST incorrect at beat %0d (expected beat %0d)", ar_beat_cnt, ar_len_latch);

    // 6. AXLEN range: FIXED<=15, WRAP in {1,3,7,15}, INCR<=255
    property p_axlen_range_aw;
        @(posedge clk) disable iff (!rst_n)
        awvalid |->
            ((awburst == 2'b00) ? (awlen <= 8'd15) :
             (awburst == 2'b10) ? (awlen == 8'd1 || awlen == 8'd3 || awlen == 8'd7 || awlen == 8'd15) :
             1'b1);
    endproperty
    property p_axlen_range_ar;
        @(posedge clk) disable iff (!rst_n)
        arvalid |->
            ((arburst == 2'b00) ? (arlen <= 8'd15) :
             (arburst == 2'b10) ? (arlen == 8'd1 || arlen == 8'd3 || arlen == 8'd7 || arlen == 8'd15) :
             1'b1);
    endproperty
    AST_AXLEN_RANGE_AW: assert property (p_axlen_range_aw)
        else $error("AST_AXLEN_RANGE: AWLEN=%0d invalid for AWBURST=%0b", awlen, awburst);
    AST_AXLEN_RANGE_AR: assert property (p_axlen_range_ar)
        else $error("AST_AXLEN_RANGE: ARLEN=%0d invalid for ARBURST=%0b", arlen, arburst);

    // 7. AXBURST encoding: must not be 2'b11
    property p_axburst_encode;
        @(posedge clk) disable iff (!rst_n)
        awvalid |-> (awburst != 2'b11);
    endproperty
    property p_arburst_encode;
        @(posedge clk) disable iff (!rst_n)
        arvalid |-> (arburst != 2'b11);
    endproperty
    AST_AXBURST_ENCODE_AW: assert property (p_axburst_encode)
        else $error("AST_AXBURST_ENCODE: AWBURST=2'b11 is reserved");
    AST_AXBURST_ENCODE_AR: assert property (p_arburst_encode)
        else $error("AST_AXBURST_ENCODE: ARBURST=2'b11 is reserved");

    // 8. AXSIZE range: (1<<axsize) <= DATA_WIDTH/8
    property p_axsize_range_aw;
        @(posedge clk) disable iff (!rst_n)
        awvalid |-> ((1 << awsize) <= DATA_WIDTH/8);
    endproperty
    property p_axsize_range_ar;
        @(posedge clk) disable iff (!rst_n)
        arvalid |-> ((1 << arsize) <= DATA_WIDTH/8);
    endproperty
    AST_AXSIZE_RANGE_AW: assert property (p_axsize_range_aw)
        else $error("AST_AXSIZE_RANGE: AWSIZE=%0d exceeds DATA_WIDTH/8=%0d", awsize, DATA_WIDTH/8);
    AST_AXSIZE_RANGE_AR: assert property (p_axsize_range_ar)
        else $error("AST_AXSIZE_RANGE: ARSIZE=%0d exceeds DATA_WIDTH/8=%0d", arsize, DATA_WIDTH/8);

    // 9. WDATA stable: wdata/wstrb/wlast stable while wvalid && !wready
    property p_wdata_stable;
        @(posedge clk) disable iff (!rst_n)
        (wvalid && !wready) |=> $stable(wdata) && $stable(wstrb) && $stable(wlast);
    endproperty
    AST_WDATA_STABLE: assert property (p_wdata_stable)
        else $error("AST_WDATA_STABLE: WDATA/WSTRB/WLAST changed while WVALID held without WREADY");

    // 10. AR channel stable: all AR signals stable while arvalid && !arready
    property p_archan_stable;
        @(posedge clk) disable iff (!rst_n)
        (arvalid && !arready) |=> $stable(araddr) && $stable(arid) && $stable(arlen) &&
                                   $stable(arsize) && $stable(arburst);
    endproperty
    AST_ARCHAN_STABLE: assert property (p_archan_stable)
        else $error("AST_ARCHAN_STABLE: AR channel signals changed while ARVALID held without ARREADY");

    // 11. WSTRB width: guaranteed by parameter (DATA_WIDTH/8 == $bits(wstrb))

    // 12. Unaligned first beat WSTRB: low bytes must be zero for unaligned address
    // Track first beat after AW handshake
    logic first_w_beat;
    logic [ADDR_WIDTH-1:0] aw_addr_latch;
    logic [2:0]            aw_size_latch;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            first_w_beat   <= 1'b0;
            aw_addr_latch  <= '0;
            aw_size_latch  <= '0;
        end else begin
            if (awvalid && awready) begin
                aw_addr_latch <= awaddr;
                aw_size_latch <= awsize;
                first_w_beat  <= 1'b1;
            end else if (wvalid && wready && first_w_beat) begin
                first_w_beat <= 1'b0;
            end
        end
    end

    property p_unaligned_first_beat_wstrb;
        logic [ADDR_WIDTH-1:0] addr_l;
        logic [2:0]            size_l;
        @(posedge clk) disable iff (!rst_n)
        (first_w_beat && wvalid && wready,
         addr_l = aw_addr_latch, size_l = aw_size_latch) |->
            // byte_offset = addr % (1<<size); low byte_offset bits of wstrb must be 0
            ((wstrb & ((DATA_WIDTH/8)'((1 << (addr_l % (1 << size_l))) - 1))) == '0);
    endproperty
    AST_UNALIGNED_FIRST_BEAT_WSTRB: assert property (p_unaligned_first_beat_wstrb)
        else $error("AST_UNALIGNED_FIRST_BEAT_WSTRB: First beat WSTRB has non-zero low bytes for unaligned address");

endinterface : axi4_if
