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
    logic [ADDR_WIDTH-1:0]  awaddr_m;
    logic [ID_WIDTH-1:0]    awid_m;
    logic [7:0]             awlen_m;
    logic [2:0]             awsize_m;
    logic [1:0]             awburst_m;
    logic                   awlock_m;
    logic [3:0]             awcache_m;
    logic [2:0]             awprot_m;
    logic [3:0]             awqos_m;
    logic [3:0]             awregion_m;
    logic                   awvalid_m;
    logic                   awready_m;

    // Write Data Channel
    logic [DATA_WIDTH-1:0]      wdata_m;
    logic [DATA_WIDTH/8-1:0]    wstrb_m;
    logic                       wlast_m;
    logic                       wvalid_m;
    logic                       wready_m;

    // Write Response Channel
    logic [ID_WIDTH-1:0]    bid_m;
    logic [1:0]             bresp_m;
    logic                   bvalid_m;
    logic                   bready_m;

    // Read Address Channel
    logic [ADDR_WIDTH-1:0]  araddr_m;
    logic [ID_WIDTH-1:0]    arid_m;
    logic [7:0]             arlen_m;
    logic [2:0]             arsize_m;
    logic [1:0]             arburst_m;
    logic                   arlock_m;
    logic [3:0]             arcache_m;
    logic [2:0]             arprot_m;
    logic [3:0]             arqos_m;
    logic [3:0]             arregion_m;
    logic                   arvalid_m;
    logic                   arready_m;

    // Read Data Channel
    logic [DATA_WIDTH-1:0]  rdata_m;
    logic [ID_WIDTH-1:0]    rid_m;
    logic [1:0]             rresp_m;
    logic                   rlast_m;
    logic                   rvalid_m;
    logic                   rready_m;

    //-------------------------------------------------------------------------
    // Clocking Blocks
    //-------------------------------------------------------------------------
    clocking master_cb @(posedge clk);
        default input #1step output #1;
        // Write Address Channel - outputs
        output awaddr_m, awid_m, awlen_m, awsize_m, awburst_m, awlock_m, awcache_m, awprot_m, awqos_m, awregion_m, awvalid_m;
        input  awready_m;
        // Write Data Channel - outputs
        output wdata_m, wstrb_m, wlast_m, wvalid_m;
        input  wready_m;
        // Write Response Channel - inputs
        output bready_m;
        input  bid_m, bresp_m, bvalid_m;
        // Read Address Channel - outputs
        output araddr_m, arid_m, arlen_m, arsize_m, arburst_m, arlock_m, arcache_m, arprot_m, arqos_m, arregion_m, arvalid_m;
        input  arready_m;
        // Read Data Channel - inputs
        output rready_m;
        input  rid_m, rdata_m, rresp_m, rlast_m, rvalid_m;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input awaddr_m, awid_m, awlen_m, awsize_m, awburst_m, awlock_m, awcache_m, awprot_m, awqos_m, awregion_m, awvalid_m, awready_m;
        input wdata_m, wstrb_m, wlast_m, wvalid_m, wready_m;
        input bid_m, bresp_m, bvalid_m, bready_m;
        input araddr_m, arid_m, arlen_m, arsize_m, arburst_m, arlock_m, arcache_m, arprot_m, arqos_m, arregion_m, arvalid_m, arready_m;
        input rid_m, rdata_m, rresp_m, rlast_m, rvalid_m, rready_m;
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
            if (awvalid_m && awready_m) begin
                aw_len_latch <= awlen_m;
                aw_beat_cnt  <= 0;
            end else if (wvalid_m && wready_m) begin
                aw_beat_cnt <= aw_beat_cnt + 1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_beat_cnt  <= 0;
            ar_len_latch <= 0;
        end else begin
            if (arvalid_m && arready_m) begin
                ar_len_latch <= arlen_m;
                ar_beat_cnt  <= 0;
            end else if (rvalid_m && rready_m) begin
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
        (awvalid_m && !awready_m) |=> awvalid_m;
    endproperty
    AST_AWVALID_STABLE: assert property (p_awvalid_stable)
        else $error("AST_AWVALID_STABLE: AWVALID deasserted before AWREADY");

    // 2. ARVALID stable: once asserted, must hold until ARREADY
    property p_arvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (arvalid_m && !arready_m) |=> arvalid_m;
    endproperty
    AST_ARVALID_STABLE: assert property (p_arvalid_stable)
        else $error("AST_ARVALID_STABLE: ARVALID deasserted before ARREADY");

    // 3. WVALID stable: once asserted, must hold until WREADY
    property p_wvalid_stable;
        @(posedge clk) disable iff (!rst_n)
        (wvalid_m && !wready_m) |=> wvalid_m;
    endproperty
    AST_WVALID_STABLE: assert property (p_wvalid_stable)
        else $error("AST_WVALID_STABLE: WVALID deasserted before WREADY");

    // 4. WLAST correct: wlast_m must be high only on beat awlen_m+1
    property p_wlast_correct;
        @(posedge clk) disable iff (!rst_n)
        (wvalid_m && wready_m) |->
            (wlast_m == (aw_beat_cnt == aw_len_latch));
    endproperty
    AST_WLAST_CORRECT: assert property (p_wlast_correct)
        else $error("AST_WLAST_CORRECT: WLAST incorrect at beat %0d (expected beat %0d)", aw_beat_cnt, aw_len_latch);

    // 5. RLAST correct: rlast_m must be high only on beat arlen_m+1
    property p_rlast_correct;
        @(posedge clk) disable iff (!rst_n)
        (rvalid_m && rready_m) |->
            (rlast_m == (ar_beat_cnt == ar_len_latch));
    endproperty
    AST_RLAST_CORRECT: assert property (p_rlast_correct)
        else $error("AST_RLAST_CORRECT: RLAST incorrect at beat %0d (expected beat %0d)", ar_beat_cnt, ar_len_latch);

    // 6. AXLEN range: FIXED<=15, WRAP in {1,3,7,15}, INCR<=255
    property p_axlen_range_aw;
        @(posedge clk) disable iff (!rst_n)
        awvalid_m |->
            ((awburst_m == 2'b00) ? (awlen_m <= 8'd15) :
             (awburst_m == 2'b10) ? (awlen_m == 8'd1 || awlen_m == 8'd3 || awlen_m == 8'd7 || awlen_m == 8'd15) :
             1'b1);
    endproperty
    property p_axlen_range_ar;
        @(posedge clk) disable iff (!rst_n)
        arvalid_m |->
            ((arburst_m == 2'b00) ? (arlen_m <= 8'd15) :
             (arburst_m == 2'b10) ? (arlen_m == 8'd1 || arlen_m == 8'd3 || arlen_m == 8'd7 || arlen_m == 8'd15) :
             1'b1);
    endproperty
    AST_AXLEN_RANGE_AW: assert property (p_axlen_range_aw)
        else $error("AST_AXLEN_RANGE: AWLEN=%0d invalid for AWBURST=%0b", awlen_m, awburst_m);
    AST_AXLEN_RANGE_AR: assert property (p_axlen_range_ar)
        else $error("AST_AXLEN_RANGE: ARLEN=%0d invalid for ARBURST=%0b", arlen_m, arburst_m);

    // 7. AXBURST encoding: must not be 2'b11
    property p_axburst_encode;
        @(posedge clk) disable iff (!rst_n)
        awvalid_m |-> (awburst_m != 2'b11);
    endproperty
    property p_arburst_encode;
        @(posedge clk) disable iff (!rst_n)
        arvalid_m |-> (arburst_m != 2'b11);
    endproperty
    AST_AXBURST_ENCODE_AW: assert property (p_axburst_encode)
        else $error("AST_AXBURST_ENCODE: AWBURST=2'b11 is reserved");
    AST_AXBURST_ENCODE_AR: assert property (p_arburst_encode)
        else $error("AST_AXBURST_ENCODE: ARBURST=2'b11 is reserved");

    // 8. AXSIZE range: (1<<axsize) <= DATA_WIDTH/8
    property p_axsize_range_aw;
        @(posedge clk) disable iff (!rst_n)
        awvalid_m |-> ((1 << awsize_m) <= DATA_WIDTH/8);
    endproperty
    property p_axsize_range_ar;
        @(posedge clk) disable iff (!rst_n)
        arvalid_m |-> ((1 << arsize_m) <= DATA_WIDTH/8);
    endproperty
    AST_AXSIZE_RANGE_AW: assert property (p_axsize_range_aw)
        else $error("AST_AXSIZE_RANGE: AWSIZE=%0d exceeds DATA_WIDTH/8=%0d", awsize_m, DATA_WIDTH/8);
    AST_AXSIZE_RANGE_AR: assert property (p_axsize_range_ar)
        else $error("AST_AXSIZE_RANGE: ARSIZE=%0d exceeds DATA_WIDTH/8=%0d", arsize_m, DATA_WIDTH/8);

    // 9. WDATA stable: wdata_m/wstrb_m/wlast_m stable while wvalid_m && !wready_m
    property p_wdata_stable;
        @(posedge clk) disable iff (!rst_n)
        (wvalid_m && !wready_m) |=> $stable(wdata_m) && $stable(wstrb_m) && $stable(wlast_m);
    endproperty
    AST_WDATA_STABLE: assert property (p_wdata_stable)
        else $error("AST_WDATA_STABLE: WDATA/WSTRB/WLAST changed while WVALID held without WREADY");

    // 10. AR channel stable: all AR signals stable while arvalid_m && !arready_m
    property p_archan_stable;
        @(posedge clk) disable iff (!rst_n)
        (arvalid_m && !arready_m) |=> $stable(araddr_m) && $stable(arid_m) && $stable(arlen_m) &&
                                   $stable(arsize_m) && $stable(arburst_m);
    endproperty
    AST_ARCHAN_STABLE: assert property (p_archan_stable)
        else $error("AST_ARCHAN_STABLE: AR channel signals changed while ARVALID held without ARREADY");

    // 11. WSTRB width: guaranteed by parameter (DATA_WIDTH/8 == $bits(wstrb_m))

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
            if (awvalid_m && awready_m) begin
                aw_addr_latch <= awaddr_m;
                aw_size_latch <= awsize_m;
                first_w_beat  <= 1'b1;
            end else if (wvalid_m && wready_m && first_w_beat) begin
                first_w_beat <= 1'b0;
            end
        end
    end

    property p_unaligned_first_beat_wstrb;
        logic [ADDR_WIDTH-1:0] addr_l;
        logic [2:0]            size_l;
        @(posedge clk) disable iff (!rst_n)
        (first_w_beat && wvalid_m && wready_m,
         addr_l = aw_addr_latch, size_l = aw_size_latch) |->
            // byte_offset = addr % (1<<size); low byte_offset bits of wstrb_m must be 0
            ((wstrb_m & ((DATA_WIDTH/8)'((1 << (addr_l % (1 << size_l))) - 1))) == '0);
    endproperty
    AST_UNALIGNED_FIRST_BEAT_WSTRB: assert property (p_unaligned_first_beat_wstrb)
        else $error("AST_UNALIGNED_FIRST_BEAT_WSTRB: First beat WSTRB has non-zero low bytes for unaligned address");

endinterface : axi4_if
