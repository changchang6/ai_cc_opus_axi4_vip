//-----------------------------------------------------------------------------
// File: axi4_tb_top.sv
// Description: AXI4 Testbench Top Module with simple slave model
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module axi4_tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi4_pkg::*;

    // Parameters – inherit compile-time bus-width from AI_AXI4 defines
    `ifndef AI_AXI4_MAX_DATA_WIDTH
      `define AI_AXI4_MAX_DATA_WIDTH 32
    `endif
    `ifndef AI_AXI4_MAX_ADDR_WIDTH
      `define AI_AXI4_MAX_ADDR_WIDTH 32
    `endif
    `ifndef AI_AXI4_MAX_ID_WIDTH
      `define AI_AXI4_MAX_ID_WIDTH 4
    `endif
    parameter int DATA_WIDTH = `AI_AXI4_MAX_DATA_WIDTH;
    parameter int ADDR_WIDTH = `AI_AXI4_MAX_ADDR_WIDTH;
    parameter int ID_WIDTH   = `AI_AXI4_MAX_ID_WIDTH;

    //-------------------------------------------------------------------------
    // Clock and Reset
    //-------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 0;
    always #0.5 clk = ~clk;

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
    // Simple Slave Model with Memory
    //-------------------------------------------------------------------------
    // Memory model: associative array indexed by byte address
    logic [7:0] mem [logic [ADDR_WIDTH-1:0]];

    // Write channel state - support outstanding transactions
    typedef struct {
        logic [ID_WIDTH-1:0]   id;
        logic [ADDR_WIDTH-1:0] addr;
        logic [7:0]            len;
        logic [2:0]            size;
        logic [1:0]            burst;
        logic [7:0]            beat_cnt;
    } aw_info_t;

    aw_info_t aw_queue[$];
    aw_info_t current_aw;
    logic     aw_active;

    // AW channel: always ready
    assign sys_if.master_if[0].awready = 1'b1;

    // W channel: always ready
    assign sys_if.master_if[0].wready = 1'b1;

    // B channel
    logic                s_bvalid;
    logic [ID_WIDTH-1:0] s_bid;
    logic [1:0]          s_bresp;

    assign sys_if.master_if[0].bvalid = s_bvalid;
    assign sys_if.master_if[0].bid    = s_bid;
    assign sys_if.master_if[0].bresp  = s_bresp;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_bvalid     <= 0;
            s_bid        <= '0;
            s_bresp      <= 2'b00;
            aw_queue     = {};
            current_aw   = '{default: '0};
            aw_active    = 0;
        end else begin
            // Capture AW channel and push to queue
            if (sys_if.master_if[0].awvalid && sys_if.master_if[0].awready) begin
                aw_info_t aw_info;
                aw_info.id       = sys_if.master_if[0].awid;
                aw_info.addr     = sys_if.master_if[0].awaddr;
                aw_info.len      = sys_if.master_if[0].awlen;
                aw_info.size     = sys_if.master_if[0].awsize;
                aw_info.burst    = sys_if.master_if[0].awburst;
                aw_info.beat_cnt = 0;
                aw_queue.push_back(aw_info);
                $display("[TB] AW: addr=0x%h len=%0d size=%0d", aw_info.addr, aw_info.len, aw_info.size);
            end

            // Process W channel
            if (sys_if.master_if[0].wvalid && sys_if.master_if[0].wready) begin
                logic [ADDR_WIDTH-1:0] wr_addr;

                // Get new transaction from queue if no active transaction
                if (!aw_active && aw_queue.size() > 0) begin
                    current_aw = aw_queue.pop_front();
                    aw_active = 1;
                end

                wr_addr = current_aw.addr;
                $display("[TB] W: addr=0x%h data=0x%h wstrb=0x%h last=%0d", wr_addr, sys_if.master_if[0].wdata, sys_if.master_if[0].wstrb, sys_if.master_if[0].wlast);

                // Write to memory
                for (int i = 0; i < DATA_WIDTH/8; i++) begin
                    if (sys_if.master_if[0].wstrb[i])
                        mem[wr_addr + i] = sys_if.master_if[0].wdata[i*8 +: 8];
                end

                if (sys_if.master_if[0].wlast) begin
                    s_bvalid  <= 1;
                    s_bid     <= current_aw.id;
                    s_bresp   <= 2'b00;
                    aw_active = 0;
                end else begin
                    current_aw.beat_cnt = current_aw.beat_cnt + 1;
                    if (current_aw.burst == 2'b01)
                        current_aw.addr = wr_addr + (1 << current_aw.size);
                end
            end

            if (s_bvalid && sys_if.master_if[0].bready)
                s_bvalid <= 0;
        end
    end

    // AR channel: always ready
    assign sys_if.master_if[0].arready = 1'b1;

    // R channel: read from memory
    logic                  s_rvalid;
    logic [ID_WIDTH-1:0]   s_rid;
    logic [DATA_WIDTH-1:0] s_rdata;
    logic [1:0]            s_rresp;
    logic                  s_rlast;
    logic [ADDR_WIDTH-1:0] rd_addr;
    logic [7:0]            rd_len;
    logic [2:0]            rd_size;
    logic [1:0]            rd_burst;
    logic [7:0]            rd_beat_cnt;

    assign sys_if.master_if[0].rvalid = s_rvalid;
    assign sys_if.master_if[0].rid    = s_rid;
    assign sys_if.master_if[0].rdata  = s_rdata;
    assign sys_if.master_if[0].rresp  = s_rresp;
    assign sys_if.master_if[0].rlast  = s_rlast;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_rvalid    <= 0;
            s_rid       <= '0;
            s_rdata     <= '0;
            s_rresp     <= 2'b00;
            s_rlast     <= 0;
            rd_addr     <= '0;
            rd_len      <= '0;
            rd_size     <= '0;
            rd_burst    <= '0;
            rd_beat_cnt <= '0;
        end else begin
            if (sys_if.master_if[0].arvalid && sys_if.master_if[0].arready && !s_rvalid) begin
                // Capture AR channel and start read response
                logic [ADDR_WIDTH-1:0] first_addr;
                first_addr  = sys_if.master_if[0].araddr;
                rd_addr     <= first_addr;
                rd_len      <= sys_if.master_if[0].arlen;
                rd_size     <= sys_if.master_if[0].arsize;
                rd_burst    <= sys_if.master_if[0].arburst;
                rd_beat_cnt <= 0;
                s_rvalid    <= 1;
                s_rid       <= sys_if.master_if[0].arid;
                s_rresp     <= 2'b00;
                s_rlast     <= (sys_if.master_if[0].arlen == 0);
                $display("[TB] AR: addr=0x%h len=%0d size=%0d", first_addr, sys_if.master_if[0].arlen, sys_if.master_if[0].arsize);

                // Read first beat from memory (return 0 if not written)
                for (int i = 0; i < DATA_WIDTH/8; i++)
                    s_rdata[i*8 +: 8] <= mem.exists(first_addr + i) ? mem[first_addr + i] : 8'h00;
                $display("[TB] R: addr=0x%h data=0x%h", first_addr, {mem[first_addr+3], mem[first_addr+2], mem[first_addr+1], mem[first_addr]});
            end else if (s_rvalid && sys_if.master_if[0].rready) begin
                if (s_rlast) begin
                    s_rvalid <= 0;
                    s_rlast  <= 0;
                end else begin
                    logic [ADDR_WIDTH-1:0] next_addr;

                    rd_beat_cnt <= rd_beat_cnt + 1;
                    s_rlast     <= (rd_beat_cnt + 1 >= rd_len);

                    // Calculate next address based on burst type
                    if (rd_burst == 2'b01)  // INCR
                        next_addr = rd_addr + (1 << rd_size);
                    else  // FIXED or WRAP
                        next_addr = rd_addr;
                    rd_addr <= next_addr;

                    // Read next beat from memory (return 0 if not written)
                    for (int i = 0; i < DATA_WIDTH/8; i++)
                        s_rdata[i*8 +: 8] <= mem.exists(next_addr + i) ? mem[next_addr + i] : 8'h00;
                    $display("[TB] R: addr=0x%h data=0x%h", next_addr, {mem[next_addr+3], mem[next_addr+2], mem[next_addr+1], mem[next_addr]});
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
