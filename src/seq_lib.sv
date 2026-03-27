//-----------------------------------------------------------------------------
// File: seq_lib.sv
// Description: AXI4 VIP Sequence Library
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// axi4_fixed_len0_size7_seq
//
// Test steps:
//   1. Set AXI transfer parameters: len=0 (single beat), size=7 (128 bytes/beat)
//   2. Set aligned start address (128-byte aligned) and transaction count (10)
//   3. Master VIP sends m_num_txns write transactions, address auto-increments
//      by 128 bytes per transaction
//   4. After ALL write transactions complete, read back each written address and
//      compare read data with write data; mismatch reported via uvm_error
//
// NOTE: size=7 exceeds the default 32-bit interface bus width and will trigger
// AST_AXSIZE_RANGE assertion. Adjust DATA_WIDTH to >= 1024 in axi4_tb_top.sv
// or disable the assertion when using this sequence.
//-----------------------------------------------------------------------------
class axi4_fixed_len0_size7_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_fixed_len0_size7_seq)

    // Step 2: Configurable start address (128-byte aligned for size=7)
    rand bit [31:0] m_start_addr;

    // Step 2: Number of transactions to send (default 10)
    int unsigned m_num_txns = 10;

    // Constrain start address to 128-byte alignment (2^size = 2^7 = 128)
    constraint c_addr_128b_aligned {
        m_start_addr[6:0] == 7'h00;
    }

    function new(string name = "axi4_fixed_len0_size7_seq");
        super.new(name);
    endfunction

    task body();
        typedef logic [31:0] word_arr_t[];

        axi4_transaction wr_txn, rd_txn;
        logic [31:0] cur_addr;
        logic [31:0] wr_addr_q[$];  // saved write addresses
        word_arr_t   wr_data_q[$];  // saved write data (one dynamic array per txn)
        word_arr_t   tmp_data;

        cur_addr = m_start_addr;

        `uvm_info(get_type_name(),
            $sformatf("Starting: start_addr=0x%08h num_txns=%0d len=0 size=7",
                      cur_addr, m_num_txns),
            UVM_LOW)

        // Step 3: Send ALL m_num_txns write transactions first
        repeat (m_num_txns) begin
            wr_txn = axi4_transaction::type_id::create("wr_txn");
            start_item(wr_txn);

            // Step 1: Disable c_size built-in constraint (limits size to <=4)
            //         to allow size=7 (128 bytes/beat)
            wr_txn.c_size.constraint_mode(0);

            // Step 1: Fix len=0 and size=7; Step 2: fix address
            if (!wr_txn.randomize() with {
                m_trans_type  == TRANS_WRITE;
                m_burst       == BURST_INCR;
                m_len         == 8'd0;        // len=0: single beat
                m_size        == 3'd7;        // size=7: 128 bytes/beat
                m_addr[31:0]  == local::cur_addr;
                m_addr[63:32] == 32'h0;
            }) `uvm_fatal(get_type_name(), "Write randomization failed")

            // All byte lanes enabled (4'hF for 32-bit bus wstrb)
            wr_txn.m_wstrb[0] = 4'hF;

            finish_item(wr_txn);

            // Save address and a copy of write data for later read-back comparison
            wr_addr_q.push_back(cur_addr);
            tmp_data = wr_txn.m_data;
            wr_data_q.push_back(tmp_data);

            // Advance address by one beat: 2^7 = 128 bytes
            cur_addr += 32'd128;
        end

        `uvm_info(get_type_name(),
            $sformatf("All %0d write transactions done, last_addr=0x%08h",
                      m_num_txns, cur_addr - 32'd128),
            UVM_LOW)

        // Step 4: Read back ALL written addresses and compare with write data
        `uvm_info(get_type_name(), "Starting read-back verification", UVM_LOW)

        foreach (wr_addr_q[i]) begin
            rd_txn = axi4_transaction::type_id::create($sformatf("rd_txn_%0d", i));
            start_item(rd_txn);

            rd_txn.c_size.constraint_mode(0);

            if (!rd_txn.randomize() with {
                m_trans_type  == TRANS_READ;
                m_burst       == BURST_INCR;
                m_len         == 8'd0;
                m_size        == 3'd7;
                m_addr[31:0]  == local::wr_addr_q[i];
                m_addr[63:32] == 32'h0;
            }) `uvm_fatal(get_type_name(), "Read randomization failed")

            finish_item(rd_txn);

            // Compare read data vs write data beat by beat
            foreach (wr_data_q[i][j]) begin
                if (rd_txn.m_rdata[j] !== wr_data_q[i][j]) begin
                    `uvm_error(get_type_name(),
                        $sformatf("MISMATCH addr=0x%08h beat[%0d]: exp=0x%08h got=0x%08h",
                                  wr_addr_q[i], j, wr_data_q[i][j], rd_txn.m_rdata[j]))
                end
            end

            `uvm_info(get_type_name(),
                $sformatf("Read-back pass: addr=0x%08h", wr_addr_q[i]),
                UVM_MEDIUM)
        end

        `uvm_info(get_type_name(), "Read-back verification complete", UVM_LOW)
    endtask

endclass : axi4_fixed_len0_size7_seq

//-----------------------------------------------------------------------------
// axi4_burst_incr_seq
//
// Test steps:
//   1. Set AXI transfer parameters: len inside [1:16], size=max_width
//      (2^size = DATA_WIDTH/8 bytes/beat), burst=INCR
//   2. Set aligned start address and transaction count (default 5000)
//   3. Master VIP sends m_num_txns write transactions; address advances by
//      (len+1)*2^size bytes per transaction
//   4. After ALL write transactions complete, read back each written address
//      with the same len/size and compare read data with write data;
//      mismatches reported via uvm_error
//-----------------------------------------------------------------------------
class axi4_burst_incr_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_burst_incr_seq)

    // Compile-time max transfer size: log2(DATA_WIDTH_BYTES)
    localparam int MAX_SIZE = $clog2(`AI_AXI4_MAX_DATA_WIDTH / 8);

    // Step 2: Configurable start address (aligned to 2^MAX_SIZE bytes)
    rand bit [31:0] m_start_addr;

    // Step 2: Number of transactions to send (default 5000)
    int unsigned m_num_txns = 5000;

    // Constrain start address alignment to transfer size boundary
    constraint c_addr_aligned {
        (m_start_addr & ((1 << MAX_SIZE) - 1)) == 0;
    }

    function new(string name = "axi4_burst_incr_seq");
        super.new(name);
    endfunction

    task body();
        typedef logic [31:0] word_arr_t[];

        axi4_transaction  wr_txn, rd_txn;
        logic [31:0]      cur_addr;
        logic [31:0]      wr_addr_q[$];   // saved write addresses
        logic [7:0]       wr_len_q[$];    // saved write lengths
        word_arr_t        wr_data_q[$];   // saved write data per transaction
        word_arr_t        tmp_data;
        int unsigned      bytes_per_beat;
        int unsigned      bytes_per_txn;
        logic [7:0]       txn_len;

        bytes_per_beat = 1 << MAX_SIZE;
        cur_addr       = m_start_addr;

        `uvm_info(get_type_name(),
            $sformatf("Starting burst_incr_seq: start_addr=0x%08h num_txns=%0d size=%0d burst=INCR len=[1:16]",
                      cur_addr, m_num_txns, MAX_SIZE),
            UVM_LOW)

        // Step 3: Send ALL m_num_txns write transactions first
        repeat (m_num_txns) begin
            wr_txn = axi4_transaction::type_id::create("wr_txn");
            wr_txn.m_addr.rand_mode(0);

            start_item(wr_txn);

            if (!wr_txn.randomize() with {
                m_trans_type  == TRANS_WRITE;
                m_burst       == BURST_INCR;
                m_len         inside {[8'd1:8'd16]};
                m_size        == MAX_SIZE[2:0];
            }) `uvm_fatal(get_type_name(), "Write randomization failed")

            // Set address after randomize
            wr_txn.m_addr[31:0]  = cur_addr;
            wr_txn.m_addr[63:32] = 32'h0;

            foreach (wr_txn.m_wstrb[k])
                wr_txn.m_wstrb[k] = 4'hF;

            finish_item(wr_txn);

            wr_addr_q.push_back(cur_addr);
            wr_len_q.push_back(wr_txn.m_len);
            tmp_data = wr_txn.m_data;
            wr_data_q.push_back(tmp_data);

            bytes_per_txn = (int'(wr_txn.m_len) + 1) * bytes_per_beat;
            cur_addr += bytes_per_txn;
        end

        `uvm_info(get_type_name(),
            $sformatf("All %0d write transactions done, last_addr=0x%08h",
                      m_num_txns, cur_addr - bytes_per_beat),
            UVM_LOW)

        // Step 4: Read back ALL written addresses and compare with write data
        `uvm_info(get_type_name(), "Starting read-back verification", UVM_LOW)

        foreach (wr_addr_q[i]) begin
            rd_txn = axi4_transaction::type_id::create($sformatf("rd_txn_%0d", i));
            start_item(rd_txn);

            if (!rd_txn.randomize() with {
                m_trans_type  == TRANS_READ;
                m_burst       == BURST_INCR;
                m_len         == local::wr_len_q[i];
                m_size        == MAX_SIZE[2:0];
                m_addr[31:0]  == local::wr_addr_q[i];
                m_addr[63:32] == 32'h0;
            }) `uvm_fatal(get_type_name(), "Read randomization failed")

            finish_item(rd_txn);

            // Beat-by-beat data comparison
            foreach (wr_data_q[i][j]) begin
                if (rd_txn.m_rdata[j] !== wr_data_q[i][j]) begin
                    `uvm_error(get_type_name(),
                        $sformatf("MISMATCH addr=0x%08h beat[%0d]: exp=0x%08h got=0x%08h",
                                  wr_addr_q[i], j, wr_data_q[i][j], rd_txn.m_rdata[j]))
                end
            end

            `uvm_info(get_type_name(),
                $sformatf("Read-back done: addr=0x%08h len=%0d", wr_addr_q[i], wr_len_q[i]),
                UVM_HIGH)
        end

        `uvm_info(get_type_name(), "Read-back verification complete", UVM_LOW)
    endtask

endclass : axi4_burst_incr_seq

//-----------------------------------------------------------------------------
// axi4_burst_fixed_seq
//
// Test steps:
//   1. Set AXI transfer parameters: len inside [1:16], size=max_width, burst=FIXED
//   2. Set aligned start address and transaction count (default 5000)
//   3. Master VIP sends m_num_txns write transactions
//   4. After ALL write transactions complete, read back and compare
//-----------------------------------------------------------------------------
class axi4_burst_fixed_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_burst_fixed_seq)

    localparam int MAX_SIZE = $clog2(`AI_AXI4_MAX_DATA_WIDTH / 8);

    rand bit [31:0] m_start_addr;
    int unsigned m_num_txns = 5000;

    constraint c_addr_aligned {
        (m_start_addr & ((1 << MAX_SIZE) - 1)) == 0;
    }

    function new(string name = "axi4_burst_fixed_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction  wr_txn, rd_txn;
        logic [63:0]      cur_addr;
        logic [63:0]      wr_addr_q[$];
        logic [31:0]      wr_last_data_q[$];
        int unsigned      bytes_per_beat;

        bytes_per_beat = 1 << MAX_SIZE;
        cur_addr       = m_start_addr;

        `uvm_info(get_type_name(),
            $sformatf("Starting burst_fixed_seq: start_addr=0x%016h num_txns=%0d size=%0d burst=FIXED len=[1:16]",
                      cur_addr, m_num_txns, MAX_SIZE),
            UVM_LOW)

        repeat (m_num_txns) begin
            wr_txn = axi4_transaction::type_id::create("wr_txn");
            wr_txn.m_addr.rand_mode(0);

            start_item(wr_txn);

            if (!wr_txn.randomize() with {
                m_trans_type  == TRANS_WRITE;
                m_burst       == BURST_FIXED;
                m_len         inside {[8'd1:8'd16]};
                m_size        == MAX_SIZE[2:0];
            }) `uvm_fatal(get_type_name(), "Write randomization failed")

            wr_txn.m_addr[31:0]  = cur_addr;
            wr_txn.m_addr[63:32] = 32'h0;

            foreach (wr_txn.m_wstrb[k])
                wr_txn.m_wstrb[k] = 4'hF;

            finish_item(wr_txn);

            wr_addr_q.push_back(cur_addr);
            wr_last_data_q.push_back(wr_txn.m_data[wr_txn.m_len]);

            cur_addr += (int'(wr_txn.m_len) + 1) * bytes_per_beat;
        end

        `uvm_info(get_type_name(),
            $sformatf("All %0d write transactions done", m_num_txns),
            UVM_LOW)

        `uvm_info(get_type_name(), "Starting read-back verification", UVM_LOW)

        foreach (wr_addr_q[i]) begin
            rd_txn = axi4_transaction::type_id::create($sformatf("rd_txn_%0d", i));
            start_item(rd_txn);

            if (!rd_txn.randomize() with {
                m_trans_type  == TRANS_READ;
                m_burst       == BURST_FIXED;
                m_len         == 8'd0;
                m_size        == MAX_SIZE[2:0];
                m_addr[31:0]  == local::wr_addr_q[i];
                m_addr[63:32] == 32'h0;
            }) `uvm_fatal(get_type_name(), "Read randomization failed")

            finish_item(rd_txn);

            if (rd_txn.m_rdata[0] !== wr_last_data_q[i]) begin
                `uvm_error(get_type_name(),
                    $sformatf("MISMATCH addr=0x%016h: exp=0x%08h got=0x%08h",
                              wr_addr_q[i], wr_last_data_q[i], rd_txn.m_rdata[0]))
            end

            `uvm_info(get_type_name(),
                $sformatf("Read-back pass: addr=0x%016h", wr_addr_q[i]),
                UVM_HIGH)
        end

        `uvm_info(get_type_name(), "Read-back verification complete", UVM_LOW)
    endtask

endclass : axi4_burst_fixed_seq
