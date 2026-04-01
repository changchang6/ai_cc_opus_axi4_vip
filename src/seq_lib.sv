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
            wr_txn.m_wstrb[0] = '1;

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
                wr_txn.m_wstrb[k] = '1;

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
                wr_txn.m_wstrb[k] = '1;

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

//-----------------------------------------------------------------------------
// axi4_burst_wrap_seq
//
// Test steps:
//   1. Set AXI transfer parameters: len inside {2,4,8,16}, size=max_width, burst=WRAP
//   2. Set aligned start address and transaction count (default 5000)
//   3. Master VIP sends m_num_txns write transactions
//   4. After ALL write transactions complete, read back and compare
//-----------------------------------------------------------------------------
class axi4_burst_wrap_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_burst_wrap_seq)

    localparam int MAX_SIZE = $clog2(`AI_AXI4_MAX_DATA_WIDTH / 8);

    int unsigned m_num_txns = 5000;
    logic [31:0] m_start_addr = 32'h0;

    function new(string name = "axi4_burst_wrap_seq");
        super.new(name);
    endfunction

    task body();
        typedef logic [31:0] word_arr_t[];

        axi4_transaction  wr_txn, rd_txn;
        logic [31:0]      wr_addr_q[$];
        logic [7:0]       wr_len_q[$];
        word_arr_t        wr_data_q[$];
        word_arr_t        tmp_data;

        byte unsigned     valid_lens[4] = '{8'd1, 8'd3, 8'd7, 8'd15};
        logic [7:0]       rand_len;
        logic [31:0]      rand_addr, current_addr;
        int unsigned      bytes_per_beat, wrap_size, max_wrap_size;
        int               addr_used[logic[31:0]];

        bytes_per_beat = 1 << MAX_SIZE;
        max_wrap_size = 16 * bytes_per_beat;
        current_addr = m_start_addr;

        `uvm_info(get_type_name(),
            $sformatf("Starting burst_wrap_seq: num_txns=%0d size=%0d burst=WRAP len={2,4,8,16}",
                      m_num_txns, MAX_SIZE),
            UVM_LOW)

        repeat (m_num_txns) begin
            rand_len  = valid_lens[$urandom_range(0,3)];
            wrap_size = (int'(rand_len) + 1) * bytes_per_beat;

            do begin
                rand_addr = current_addr & ~(wrap_size - 1);
                current_addr += max_wrap_size;
            end while (addr_used.exists(rand_addr));

            addr_used[rand_addr] = 1;

            wr_txn = axi4_transaction::type_id::create("wr_txn");
            wr_txn.m_addr.rand_mode(0);

            start_item(wr_txn);

            if (!wr_txn.randomize() with {
                m_trans_type == TRANS_WRITE;
                m_burst      == BURST_WRAP;
                m_len        == local::rand_len;
                m_size       == MAX_SIZE[2:0];
            }) `uvm_fatal(get_type_name(), "Write randomization failed")

            wr_txn.m_addr[31:0]  = rand_addr;
            wr_txn.m_addr[63:32] = 32'h0;

            foreach (wr_txn.m_wstrb[k])
                wr_txn.m_wstrb[k] = '1;

            finish_item(wr_txn);

            wr_addr_q.push_back(rand_addr);
            wr_len_q.push_back(rand_len);
            tmp_data = wr_txn.m_data;
            wr_data_q.push_back(tmp_data);
        end

        `uvm_info(get_type_name(),
            $sformatf("All %0d write transactions done", m_num_txns),
            UVM_LOW)

        `uvm_info(get_type_name(), "Starting read-back verification", UVM_LOW)

        foreach (wr_addr_q[i]) begin
            rd_txn = axi4_transaction::type_id::create($sformatf("rd_txn_%0d", i));
            rd_txn.m_addr.rand_mode(0);

            start_item(rd_txn);

            if (!rd_txn.randomize() with {
                m_trans_type == TRANS_READ;
                m_burst      == BURST_WRAP;
                m_len        == local::wr_len_q[i];
                m_size       == MAX_SIZE[2:0];
            }) `uvm_fatal(get_type_name(), "Read randomization failed")

            rd_txn.m_addr[31:0]  = wr_addr_q[i];
            rd_txn.m_addr[63:32] = 32'h0;

            finish_item(rd_txn);

            foreach (wr_data_q[i][j]) begin
                if (rd_txn.m_rdata[j] !== wr_data_q[i][j]) begin
                    `uvm_error(get_type_name(),
                        $sformatf("MISMATCH addr=0x%08h len=%0d beat[%0d]: exp=0x%08h got=0x%08h",
                                  wr_addr_q[i], wr_len_q[i], j, wr_data_q[i][j], rd_txn.m_rdata[j]))
                end
            end

            `uvm_info(get_type_name(),
                $sformatf("Read-back pass: addr=0x%08h len=%0d", wr_addr_q[i], wr_len_q[i]),
                UVM_HIGH)
        end

        `uvm_info(get_type_name(), "Read-back verification complete", UVM_LOW)
    endtask

endclass : axi4_burst_wrap_seq

//-----------------------------------------------------------------------------
// axi4_burst_random_seq
//
// Test steps:
//   1. Set AXI transfer parameters: len inside [1:16], size=max_width, burst=random
//   2. Set aligned start address and transaction count (default 5000)
//   3. Master VIP sends m_num_txns write transactions with random burst types
//   4. After ALL write transactions complete, read back and compare
//-----------------------------------------------------------------------------
class axi4_burst_random_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_burst_random_seq)

    localparam int MAX_SIZE = $clog2(`AI_AXI4_MAX_DATA_WIDTH / 8);

    rand bit [31:0] m_start_addr;
    int unsigned m_num_txns = 5000;

    constraint c_addr_aligned {
        (m_start_addr & ((1 << MAX_SIZE) - 1)) == 0;
    }

    function new(string name = "axi4_burst_random_seq");
        super.new(name);
    endfunction

    task body();
        typedef logic [31:0] word_arr_t[];

        axi4_transaction  wr_txn, rd_txn;
        logic [31:0]      wr_addr_q[$];
        logic [7:0]       wr_len_q[$];
        axi4_burst_e      wr_burst_q[$];
        word_arr_t        wr_data_q[$];
        word_arr_t        tmp_data;
        int unsigned      bytes_per_beat, bytes_per_txn;
        logic [31:0]      incr_addr, fixed_addr, wrap_addr;
        int               addr_used[logic[31:0]];

        bytes_per_beat = 1 << MAX_SIZE;
        incr_addr = m_start_addr;
        fixed_addr = m_start_addr + 32'h1000000;
        wrap_addr = m_start_addr + 32'h2000000;

        `uvm_info(get_type_name(),
            $sformatf("Starting burst_random_seq: start_addr=0x%08h num_txns=%0d size=%0d burst=RANDOM len=[1:16]",
                      m_start_addr, m_num_txns, MAX_SIZE),
            UVM_LOW)

        repeat (m_num_txns) begin
            wr_txn = axi4_transaction::type_id::create("wr_txn");
            wr_txn.m_addr.rand_mode(0);

            start_item(wr_txn);

            if (!wr_txn.randomize() with {
                m_trans_type == TRANS_WRITE;
                m_burst inside {BURST_INCR, BURST_FIXED, BURST_WRAP};
                m_len inside {[8'd1:8'd16]};
                m_size == MAX_SIZE[2:0];
                if (m_burst == BURST_WRAP) {
                    m_len inside {8'd1, 8'd3, 8'd7, 8'd15};
                }
            }) `uvm_fatal(get_type_name(), "Write randomization failed")

            if (wr_txn.m_burst == BURST_INCR) begin
                wr_txn.m_addr[31:0] = incr_addr;
                bytes_per_txn = (int'(wr_txn.m_len) + 1) * bytes_per_beat;
                incr_addr += bytes_per_txn;
            end else if (wr_txn.m_burst == BURST_FIXED) begin
                wr_txn.m_addr[31:0] = fixed_addr;
                bytes_per_txn = (int'(wr_txn.m_len) + 1) * bytes_per_beat;
                fixed_addr += bytes_per_txn;
            end else begin
                int wrap_size = (int'(wr_txn.m_len) + 1) * bytes_per_beat;
                logic [31:0] aligned_addr;
                do begin
                    aligned_addr = wrap_addr & ~(wrap_size - 1);
                    wrap_addr += 16 * bytes_per_beat;
                end while (addr_used.exists(aligned_addr));
                addr_used[aligned_addr] = 1;
                wr_txn.m_addr[31:0] = aligned_addr;
            end

            wr_txn.m_addr[63:32] = 32'h0;

            foreach (wr_txn.m_wstrb[k])
                wr_txn.m_wstrb[k] = '1;

            finish_item(wr_txn);

            wr_addr_q.push_back(wr_txn.m_addr[31:0]);
            wr_len_q.push_back(wr_txn.m_len);
            wr_burst_q.push_back(wr_txn.m_burst);

            if (wr_txn.m_burst == BURST_FIXED) begin
                tmp_data = new[1];
                tmp_data[0] = wr_txn.m_data[wr_txn.m_len];
            end else begin
                tmp_data = wr_txn.m_data;
            end
            wr_data_q.push_back(tmp_data);
        end

        `uvm_info(get_type_name(),
            $sformatf("All %0d write transactions done", m_num_txns),
            UVM_LOW)

        `uvm_info(get_type_name(), "Starting read-back verification", UVM_LOW)

        foreach (wr_addr_q[i]) begin
            rd_txn = axi4_transaction::type_id::create($sformatf("rd_txn_%0d", i));
            start_item(rd_txn);

            if (wr_burst_q[i] == BURST_FIXED) begin
                if (!rd_txn.randomize() with {
                    m_trans_type == TRANS_READ;
                    m_burst == BURST_FIXED;
                    m_len == 8'd0;
                    m_size == MAX_SIZE[2:0];
                    m_addr[31:0] == local::wr_addr_q[i];
                    m_addr[63:32] == 32'h0;
                }) `uvm_fatal(get_type_name(), "Read randomization failed")
            end else begin
                if (!rd_txn.randomize() with {
                    m_trans_type == TRANS_READ;
                    m_burst == local::wr_burst_q[i];
                    m_len == local::wr_len_q[i];
                    m_size == MAX_SIZE[2:0];
                    m_addr[31:0] == local::wr_addr_q[i];
                    m_addr[63:32] == 32'h0;
                }) `uvm_fatal(get_type_name(), "Read randomization failed")
            end

            finish_item(rd_txn);

            if (wr_burst_q[i] == BURST_FIXED) begin
                if (rd_txn.m_rdata[0] !== wr_data_q[i][0]) begin
                    `uvm_error(get_type_name(),
                        $sformatf("MISMATCH addr=0x%08h: exp=0x%08h got=0x%08h",
                                  wr_addr_q[i], wr_data_q[i][0], rd_txn.m_rdata[0]))
                end
            end else begin
                foreach (wr_data_q[i][j]) begin
                    if (rd_txn.m_rdata[j] !== wr_data_q[i][j]) begin
                        `uvm_error(get_type_name(),
                            $sformatf("MISMATCH addr=0x%08h beat[%0d]: exp=0x%08h got=0x%08h",
                                      wr_addr_q[i], j, wr_data_q[i][j], rd_txn.m_rdata[j]))
                    end
                end
            end

            `uvm_info(get_type_name(),
                $sformatf("Read-back pass: addr=0x%08h len=%0d burst=%s",
                          wr_addr_q[i], wr_len_q[i], wr_burst_q[i].name()),
                UVM_HIGH)
        end

        `uvm_info(get_type_name(), "Read-back verification complete", UVM_LOW)
    endtask

endclass : axi4_burst_random_seq

//-----------------------------------------------------------------------------
// axi4_burst_slice_seq
//
// Test steps:
//   1. Set AXI transfer parameters: len inside [16:256], size=max_width, burst=INCR
//   2. Set aligned start address and transaction count (5000)
//   3. Master VIP sends 5000 write transactions
//   4. After ALL write transactions complete, read back and compare
//-----------------------------------------------------------------------------
class axi4_burst_slice_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_burst_slice_seq)

    localparam int MAX_SIZE = $clog2(`AI_AXI4_MAX_DATA_WIDTH / 8);

    rand bit [31:0] m_start_addr;
    int unsigned m_num_txns = 5000;

    constraint c_addr_aligned {
        (m_start_addr & ((1 << MAX_SIZE) - 1)) == 0;
    }

    function new(string name = "axi4_burst_slice_seq");
        super.new(name);
    endfunction

    task body();
        typedef logic [31:0] word_arr_t[];

        axi4_transaction  wr_txn, rd_txn;
        logic [31:0]      cur_addr;
        logic [31:0]      wr_addr_q[$];
        logic [7:0]       wr_len_q[$];
        word_arr_t        wr_data_q[$];
        word_arr_t        tmp_data;
        int unsigned      bytes_per_beat;
        int unsigned      bytes_per_txn;

        bytes_per_beat = 1 << MAX_SIZE;
        cur_addr       = m_start_addr;

        `uvm_info(get_type_name(),
            $sformatf("Starting burst_slice_seq: start_addr=0x%08h num_txns=%0d size=%0d burst=INCR len=[16:256]",
                      cur_addr, m_num_txns, MAX_SIZE),
            UVM_LOW)

        repeat (m_num_txns) begin
            wr_txn = axi4_transaction::type_id::create("wr_txn");
            wr_txn.m_addr.rand_mode(0);

            start_item(wr_txn);

            if (!wr_txn.randomize() with {
                m_trans_type  == TRANS_WRITE;
                m_burst       == BURST_INCR;
                m_len         inside {[8'd16:8'd255]};
                m_size        == MAX_SIZE[2:0];
            }) `uvm_fatal(get_type_name(), "Write randomization failed")

            wr_txn.m_addr[31:0]  = cur_addr;
            wr_txn.m_addr[63:32] = 32'h0;

            foreach (wr_txn.m_wstrb[k])
                wr_txn.m_wstrb[k] = '1;

            finish_item(wr_txn);

            wr_addr_q.push_back(cur_addr);
            wr_len_q.push_back(wr_txn.m_len);
            tmp_data = wr_txn.m_data;
            wr_data_q.push_back(tmp_data);

            bytes_per_txn = (int'(wr_txn.m_len) + 1) * bytes_per_beat;
            cur_addr += bytes_per_txn;
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
                m_burst       == BURST_INCR;
                m_len         == local::wr_len_q[i];
                m_size        == MAX_SIZE[2:0];
                m_addr[31:0]  == local::wr_addr_q[i];
                m_addr[63:32] == 32'h0;
            }) `uvm_fatal(get_type_name(), "Read randomization failed")

            finish_item(rd_txn);

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

endclass : axi4_burst_slice_seq

//-----------------------------------------------------------------------------
// axi4_unaligned_addr_seq
//
// Test steps:
//   1. Set AXI transfer parameters: len inside [0:255], size=max_width,
//      burst=INCR
//   2. Set unaligned start address and transaction count per iteration (100)
//   3. Repeat 50 iterations, each with a newly randomized unaligned base addr
//   4. Master VIP sends 50*100=5000 write transactions total
//      - First beat WSTRB: low byte_offset bits cleared (non-aligned bytes)
//      - Remaining beats: all byte lanes enabled (full WSTRB)
//      - Bursts crossing 2KB boundary are auto-split by the driver
//   5. After ALL write transactions complete, read back each written address
//      and compare (first beat masked by wstrb to ignore unwritten bytes)
//-----------------------------------------------------------------------------
class axi4_unaligned_addr_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_unaligned_addr_seq)

    localparam int MAX_SIZE      = $clog2(`AI_AXI4_MAX_DATA_WIDTH / 8);
    localparam int BYTES_PER_BEAT = 1 << MAX_SIZE;  // e.g. 128 for 1024-bit bus
    localparam int STRB_WIDTH     = `AI_AXI4_MAX_DATA_WIDTH / 8;

    int unsigned m_txns_per_iter = 100;
    int unsigned m_num_iters     = 50;

    function new(string name = "axi4_unaligned_addr_seq");
        super.new(name);
    endfunction

    task body();
        typedef logic [31:0]            word_arr_t[];
        typedef logic [`AI_AXI4_MAX_DATA_WIDTH/8-1:0]  strb_arr_t[];

        axi4_transaction  wr_txn, rd_txn;
        logic [31:0]      cur_addr;
        logic [31:0]      wr_addr_q[$];
        logic [7:0]       wr_len_q[$];
        word_arr_t        wr_data_q[$], tmp_data;
        strb_arr_t        wr_wstrb_q[$], tmp_wstrb;  // save wstrb for read-back mask
        int unsigned      bytes_per_txn;
        logic [31:0]      base_addr;
        int               addr_offset;
        int               num_beats;
        // Declare at task level to avoid VCS scoped-block variable re-init bug
        logic [STRB_WIDTH-1:0] beat0_strb;

        `uvm_info(get_type_name(),
            $sformatf("Starting unaligned_addr_seq: iters=%0d txns_per_iter=%0d bytes_per_beat=%0d",
                      m_num_iters, m_txns_per_iter, BYTES_PER_BEAT), UVM_LOW)

        // Step 3 & 4: 50 iterations, each with a random unaligned base address
        for (int iter = 0; iter < m_num_iters; iter++) begin
            // Step 2: Random unaligned start address (offset 1 ~ BYTES_PER_BEAT-1)
            base_addr = iter * 32'h10_0000 + $urandom_range(1, BYTES_PER_BEAT - 1);
            cur_addr  = base_addr;

            // Step 4: Send 100 write transactions per iteration
            repeat (m_txns_per_iter) begin
                wr_txn = axi4_transaction::type_id::create("wr_txn");
                wr_txn.m_addr.rand_mode(0);
                start_item(wr_txn);

                // Step 1: len inside [0:255], size=MAX_SIZE, burst=INCR
                if (!wr_txn.randomize() with {
                    m_trans_type == TRANS_WRITE;
                    m_burst      == BURST_INCR;
                    m_len        inside {[8'd0:8'd255]};
                    m_size       == MAX_SIZE[2:0];
                }) `uvm_fatal(get_type_name(), "Write randomization failed")

                wr_txn.m_addr[31:0]  = cur_addr;
                wr_txn.m_addr[63:32] = 32'h0;

                num_beats   = int'(wr_txn.m_len) + 1;
                addr_offset = int'(cur_addr[31:0]) % BYTES_PER_BEAT;

                // Set WSTRB for all beats:
                //   beat 0: low addr_offset byte lanes cleared using shift
                //   all other beats: fully enabled
                foreach (wr_txn.m_wstrb[k])
                    wr_txn.m_wstrb[k] = '1;
                beat0_strb = {STRB_WIDTH{1'b1}} << addr_offset;
                wr_txn.m_wstrb[0] = beat0_strb;

                finish_item(wr_txn);

                // Save transaction info for read-back verification
                wr_addr_q.push_back(cur_addr);
                wr_len_q.push_back(wr_txn.m_len);
                tmp_data  = wr_txn.m_data;
                wr_data_q.push_back(tmp_data);
                tmp_wstrb = wr_txn.m_wstrb;
                wr_wstrb_q.push_back(tmp_wstrb);

                bytes_per_txn = num_beats * BYTES_PER_BEAT;
                // Second and subsequent txns in the same iteration start aligned
                cur_addr += bytes_per_txn;
            end
        end

        `uvm_info(get_type_name(),
            $sformatf("All %0d write transactions done", m_num_iters * m_txns_per_iter), UVM_LOW)

        // Step 5: Read back ALL written addresses and compare with write data
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

            // Beat-by-beat comparison; apply wstrb mask to skip unwritten bytes
            foreach (wr_data_q[i][j]) begin
                logic [31:0] exp_data, got_data;
                logic [`AI_AXI4_MAX_DATA_WIDTH/8-1:0] beat_strb;
                bit   mismatch = 0;

                beat_strb = wr_wstrb_q[i][j];
                exp_data  = wr_data_q[i][j];
                got_data  = rd_txn.m_rdata[j];

                // Compare only bytes that were actually written (wstrb=1)
                // For first beat of unaligned txn, low bytes were not written -> skip
                for (int b = 0; b < 4; b++) begin
                    // Which wstrb bit covers byte b of the 32-bit data word?
                    // m_data is 32-bit per word; STRB_WIDTH covers full beat
                    // beat j covers byte range [j*4 .. j*4+3] within the beat
                    int strb_bit = j * 4 + b;
                    if (strb_bit < (`AI_AXI4_MAX_DATA_WIDTH/8)) begin
                        if (beat_strb[strb_bit]) begin
                            if (exp_data[b*8 +: 8] !== got_data[b*8 +: 8])
                                mismatch = 1;
                        end
                    end
                end

                if (mismatch) begin
                    `uvm_error(get_type_name(),
                        $sformatf("MISMATCH addr=0x%08h beat[%0d]: exp=0x%08h got=0x%08h wstrb=0x%0h",
                                  wr_addr_q[i], j, exp_data, got_data, beat_strb))
                end
            end

            `uvm_info(get_type_name(),
                $sformatf("Read-back done: addr=0x%08h len=%0d", wr_addr_q[i], wr_len_q[i]),
                UVM_HIGH)
        end

        `uvm_info(get_type_name(), "Read-back verification complete", UVM_LOW)
    endtask

endclass : axi4_unaligned_addr_seq

//-----------------------------------------------------------------------------
// axi4_narrow_seq
//
// Test steps:
//   1. Set AXI transfer parameters: len inside [0:255],
//      size inside {0,1,2} (byte/half-word/word), burst=INCR
//   2. Set random start address (aligned/unaligned random) and transaction count (5000)
//   3. Master VIP sends 50 write transactions
//   4. After ALL write transactions complete, read back and compare
//-----------------------------------------------------------------------------
class axi4_narrow_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_narrow_seq)

    rand bit [31:0] m_start_addr;
    int unsigned m_num_txns = 50;

    function new(string name = "axi4_narrow_seq");
        super.new(name);
    endfunction

    task body();
        typedef logic [31:0] word_arr_t[];
        typedef logic [`AI_AXI4_MAX_DATA_WIDTH/8-1:0] strb_arr_t[];

        axi4_transaction wr_txn, rd_txn;
        logic [31:0] wr_addr_q[$];
        logic [7:0] wr_len_q[$];
        logic [2:0] wr_size_q[$];
        word_arr_t wr_data_q[$], tmp_data;
        strb_arr_t wr_wstrb_q[$], tmp_wstrb;
        logic [31:0] cur_addr;
        int bytes_per_txn;

        cur_addr = m_start_addr;

        `uvm_info(get_type_name(),
            $sformatf("Starting narrow_seq: start_addr=0x%08h num_txns=%0d",
                      cur_addr, m_num_txns), UVM_LOW)

        repeat (m_num_txns) begin
            wr_txn = axi4_transaction::type_id::create("wr_txn");
            wr_txn.m_addr.rand_mode(0);
            start_item(wr_txn);

            if (!wr_txn.randomize() with {
                m_trans_type == TRANS_WRITE;
                m_burst == BURST_INCR;
                m_len inside {[8'd0:8'd255]};
                m_size inside {3'd0, 3'd1, 3'd2};
            }) `uvm_fatal(get_type_name(), "Write randomization failed")

            // Align address for size=1 (2-byte) transfers: bit[0] must be 0
            if (wr_txn.m_size == 3'd1 && cur_addr[0])
                cur_addr++;  // Round up to next even address

            wr_txn.m_addr[31:0] = cur_addr;
            wr_txn.m_addr[63:32] = 32'h0;

            wr_txn.calc_unaligned_wstrb();

            finish_item(wr_txn);

            wr_addr_q.push_back(cur_addr);
            wr_len_q.push_back(wr_txn.m_len);
            wr_size_q.push_back(wr_txn.m_size);
            tmp_data = wr_txn.m_data;
            wr_data_q.push_back(tmp_data);
            tmp_wstrb = wr_txn.m_wstrb;
            wr_wstrb_q.push_back(tmp_wstrb);

            bytes_per_txn = (int'(wr_txn.m_len) + 1) * (1 << int'(wr_txn.m_size));
            cur_addr += bytes_per_txn;
        end

        `uvm_info(get_type_name(),
            $sformatf("All %0d write transactions done", m_num_txns), UVM_LOW)

        `uvm_info(get_type_name(), "Starting read-back verification", UVM_LOW)

        foreach (wr_addr_q[i]) begin
            rd_txn = axi4_transaction::type_id::create($sformatf("rd_txn_%0d", i));
            start_item(rd_txn);

            if (!rd_txn.randomize() with {
                m_trans_type == TRANS_READ;
                m_burst == BURST_INCR;
                m_len == local::wr_len_q[i];
                m_size == local::wr_size_q[i];
                m_addr[31:0] == local::wr_addr_q[i];
                m_addr[63:32] == 32'h0;
            }) `uvm_fatal(get_type_name(), "Read randomization failed")

            finish_item(rd_txn);

            // Compare data beat by beat
            foreach (wr_data_q[i][j]) begin
                logic [31:0] exp_data, got_data;
                logic [`AI_AXI4_MAX_DATA_WIDTH/8-1:0] exp_strb;
                bit mismatch = 0;

                exp_strb = wr_wstrb_q[i][j];
                exp_data = wr_data_q[i][j];
                got_data = rd_txn.m_rdata[j];

                // Compare only valid bytes based on wstrb
                for (int b = 0; b < (`AI_AXI4_MAX_DATA_WIDTH/8); b++) begin
                    if (exp_strb[b]) begin
                        if (exp_data[b*8 +: 8] !== got_data[b*8 +: 8])
                            mismatch = 1;
                    end
                end

                if (mismatch) begin
                    `uvm_error(get_type_name(),
                        $sformatf("MISMATCH addr=0x%08h beat[%0d]: exp=0x%08h got=0x%08h strb=0x%h",
                                  wr_addr_q[i], j, exp_data, got_data, exp_strb))
                end
            end

            `uvm_info(get_type_name(),
                $sformatf("Read-back done: addr=0x%08h len=%0d size=%0d",
                          wr_addr_q[i], wr_len_q[i], wr_size_q[i]), UVM_HIGH)
        end

        `uvm_info(get_type_name(), "Read-back verification complete", UVM_LOW)
    endtask

endclass : axi4_narrow_seq
