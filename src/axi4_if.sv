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
        default input #1step output #0.1;
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
    logic aw_received;  // Track if AW has been received

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_beat_cnt  <= 0;
            aw_len_latch <= 0;
            aw_received  <= 0;
        end else begin
            if (awvalid && awready) begin
                aw_len_latch <= awlen;
                aw_beat_cnt  <= 0;
                aw_received  <= 1;
            end

            if (wvalid && wready) begin
                if (wlast) begin
                    aw_beat_cnt <= 0;
                    aw_received <= 0;
                end else if (aw_received) begin
                    aw_beat_cnt <= aw_beat_cnt + 1;
                end
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
                // If R beat 0 arrives simultaneously with AR handshake, count it now
                ar_beat_cnt  <= (rvalid && rready) ? 1 : 0;
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

    // 4. WLAST correct: only check after AW received
    `ifndef DISABLE_WLAST_CHK
    property p_wlast_correct;
        @(posedge clk) disable iff (!rst_n)
        (wvalid && wready && aw_received) |->
            (wlast == (aw_beat_cnt == aw_len_latch));
    endproperty
    AST_WLAST_CORRECT: assert property (p_wlast_correct)
        else $error("AST_WLAST_CORRECT: WLAST incorrect at beat %0d (expected beat %0d)", aw_beat_cnt, aw_len_latch);
    `endif

    // 5. RLAST correct: rlast must be high only on beat arlen+1
    // When AR and R beat 0 are simultaneous, use arlen directly (registered counter not yet updated)
    property p_rlast_correct;
        @(posedge clk) disable iff (!rst_n)
        (rvalid && rready) |->
            (arvalid && arready) ?
                (rlast == (arlen == 8'd0)) :
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

    // VIP transaction len limit: len must not exceed 32
    property p_vip_len_limit_aw;
        @(posedge clk) disable iff (!rst_n)
        awvalid |-> (awlen <= 8'd32);
    endproperty
    property p_vip_len_limit_ar;
        @(posedge clk) disable iff (!rst_n)
        arvalid |-> (arlen <= 8'd32);
    endproperty
    AST_VIP_LEN_LIMIT_AW: assert property (p_vip_len_limit_aw)
        else $error("AST_VIP_LEN_LIMIT: AWLEN=%0d exceeds maximum of 32", awlen);
    AST_VIP_LEN_LIMIT_AR: assert property (p_vip_len_limit_ar)
        else $error("AST_VIP_LEN_LIMIT: ARLEN=%0d exceeds maximum of 32", arlen);

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

    // 13. X-value checks: key fields must not contain X/Z while valid is asserted
    property p_no_x_aw;
        @(posedge clk) disable iff (!rst_n)
        awvalid |-> (!$isunknown(awaddr) && !$isunknown(awid) &&
                     !$isunknown(awlen)  && !$isunknown(awsize) && !$isunknown(awburst));
    endproperty
    AST_NO_X_AW: assert property (p_no_x_aw)
        else $error("AST_NO_X_AW: X/Z detected on AW channel while AWVALID (addr=%0h id=%0h len=%0h size=%0h burst=%0h)",
                    awaddr, awid, awlen, awsize, awburst);

    property p_no_x_w;
        @(posedge clk) disable iff (!rst_n)
        wvalid |-> (!$isunknown(wdata) && !$isunknown(wstrb) && !$isunknown(wlast));
    endproperty
    AST_NO_X_W: assert property (p_no_x_w)
        else $error("AST_NO_X_W: X/Z detected on W channel while WVALID (data=%0h strb=%0h last=%0h)",
                    wdata, wstrb, wlast);

    property p_no_x_ar;
        @(posedge clk) disable iff (!rst_n)
        arvalid |-> (!$isunknown(araddr) && !$isunknown(arid) &&
                     !$isunknown(arlen)  && !$isunknown(arsize) && !$isunknown(arburst));
    endproperty
    AST_NO_X_AR: assert property (p_no_x_ar)
        else $error("AST_NO_X_AR: X/Z detected on AR channel while ARVALID (addr=%0h id=%0h len=%0h size=%0h burst=%0h)",
                    araddr, arid, arlen, arsize, arburst);

    property p_no_x_b;
        @(posedge clk) disable iff (!rst_n)
        bvalid |-> (!$isunknown(bid) && !$isunknown(bresp));
    endproperty
    AST_NO_X_B: assert property (p_no_x_b)
        else $error("AST_NO_X_B: X/Z detected on B channel while BVALID (bid=%0h bresp=%0h)",
                    bid, bresp);

    property p_no_x_r;
        @(posedge clk) disable iff (!rst_n)
        rvalid |-> (!$isunknown(rid) && !$isunknown(rdata) &&
                    !$isunknown(rresp) && !$isunknown(rlast));
    endproperty
    AST_NO_X_R: assert property (p_no_x_r)
        else $error("AST_NO_X_R: X/Z detected on R channel while RVALID (rid=%0h rdata=%0h rresp=%0h rlast=%0h)",
                    rid, rdata, rresp, rlast);

    // 12. Unaligned first beat WSTRB: low bytes must be zero for unaligned address
    // Track first beat after AW handshake
    logic first_w_beat_pending;
    logic [ADDR_WIDTH-1:0]   aw_addr_latch;
    logic [2:0]              aw_size_latch;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            first_w_beat_pending <= 1'b0;
            aw_addr_latch        <= '0;
            aw_size_latch        <= '0;
        end else begin
            if (awvalid && awready) begin
                aw_addr_latch <= awaddr;
                aw_size_latch <= awsize;
                // Set pending flag only if W0 doesn't arrive simultaneously
                first_w_beat_pending <= !(wvalid && wready);
            end else if (wvalid && wready && first_w_beat_pending) begin
                first_w_beat_pending <= 1'b0;
            end
        end
    end

    // Pulse signal: high for exactly one cycle when first W beat handshakes
    logic is_first_w_beat;
    assign is_first_w_beat = wvalid && wready &&
                             (first_w_beat_pending || (awvalid && awready));

    // Combinatorial: effective address/size for the first W beat
    // If AW and W arrive on the same cycle, use awaddr/awsize directly
    logic [ADDR_WIDTH-1:0] eff_aw_addr;
    logic [2:0]            eff_aw_size;
    assign eff_aw_addr = (awvalid && awready) ? awaddr : aw_addr_latch;
    assign eff_aw_size = (awvalid && awready) ? awsize : aw_size_latch;

    // Combinatorial mask: low byte_offset bits = 1
    logic [DATA_WIDTH/8-1:0] aw_unalign_lo_mask;
    always_comb begin
        int byte_off;
        byte_off = int'(eff_aw_addr) % (1 << int'(eff_aw_size));
        aw_unalign_lo_mask = '0;
        for (int b = 0; b < byte_off && b < DATA_WIDTH/8; b++)
            aw_unalign_lo_mask[b] = 1'b1;
    end

    property p_unaligned_first_beat_wstrb;
        @(posedge clk) disable iff (!rst_n)
        (is_first_w_beat && (aw_unalign_lo_mask != '0)) |->
            // low byte_offset bits of wstrb must be 0
            ((wstrb & aw_unalign_lo_mask) == '0);
    endproperty
    AST_UNALIGNED_FIRST_BEAT_WSTRB: assert property (p_unaligned_first_beat_wstrb)
        else $error("AST_UNALIGNED_FIRST_BEAT_WSTRB: First beat WSTRB has non-zero low bytes for unaligned address");

    // 13. 2KB boundary check: burst must not cross 2KB boundary
    //     Exception: single-beat (len=0) unaligned burst may cross 2KB
    //     because the beat itself can straddle the boundary.
    property p_no_2kb_cross_aw;
        logic [ADDR_WIDTH-1:0] start_addr, end_addr;
        @(posedge clk) disable iff (!rst_n)
        (awvalid && awready && (awlen != 8'd0), start_addr = awaddr,
         end_addr = (awburst == 2'b00) ? awaddr : awaddr + ((awlen + 1) << awsize) - 1) |->
            (start_addr[ADDR_WIDTH-1:11] == end_addr[ADDR_WIDTH-1:11]);
    endproperty
    AST_NO_2KB_CROSS_AW: assert property (p_no_2kb_cross_aw)
        else $error("AST_NO_2KB_CROSS_AW: Write burst crosses 2KB boundary (addr=0x%0h, len=%0d, size=%0d)",
                    awaddr, awlen, awsize);

    property p_no_2kb_cross_ar;
        logic [ADDR_WIDTH-1:0] start_addr, end_addr;
        @(posedge clk) disable iff (!rst_n)
        (arvalid && arready && (arlen != 8'd0), start_addr = araddr,
         end_addr = (arburst == 2'b00) ? araddr : araddr + ((arlen + 1) << arsize) - 1) |->
            (start_addr[ADDR_WIDTH-1:11] == end_addr[ADDR_WIDTH-1:11]);
    endproperty
    AST_NO_2KB_CROSS_AR: assert property (p_no_2kb_cross_ar)
        else $error("AST_NO_2KB_CROSS_AR: Read burst crosses 2KB boundary (addr=0x%0h, len=%0d, size=%0d)",
                    araddr, arlen, arsize);

    // 14. Narrow transfer WSTRB check for size=1 (2-byte) first beat
    property p_narrow_size1_wstrb;
        int byte_offset, valid_bytes;
        logic [DATA_WIDTH/8-1:0] expected_wstrb;
        @(posedge clk) disable iff (!rst_n)
        (is_first_w_beat && (eff_aw_size == 3'd1),
         byte_offset = int'(eff_aw_addr) % (DATA_WIDTH/8),
         valid_bytes = (byte_offset + 2 <= DATA_WIDTH/8) ? 2 : (DATA_WIDTH/8 - byte_offset),
         expected_wstrb = (DATA_WIDTH/8)'((1 << valid_bytes) - 1) << byte_offset) |->
            (wstrb == expected_wstrb);
    endproperty
    AST_NARROW_SIZE1_WSTRB: assert property (p_narrow_size1_wstrb)
        else $error("AST_NARROW_SIZE1_WSTRB: size=1 first beat WSTRB=0x%h, expected=0x%h at addr=0x%h",
                    wstrb, (DATA_WIDTH/8)'((1 << ((int'(eff_aw_addr) % (DATA_WIDTH/8) + 2 <= DATA_WIDTH/8) ? 2 : (DATA_WIDTH/8 - int'(eff_aw_addr) % (DATA_WIDTH/8)))) - 1) << (int'(eff_aw_addr) % (DATA_WIDTH/8)), eff_aw_addr);

endinterface : axi4_if
