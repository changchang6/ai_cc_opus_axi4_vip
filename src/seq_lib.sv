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
        axi4_transaction txn;
        logic [31:0] cur_addr;

        cur_addr = m_start_addr;

        `uvm_info(get_type_name(),
            $sformatf("Starting: start_addr=0x%08h num_txns=%0d len=0 size=7",
                      cur_addr, m_num_txns),
            UVM_LOW)

        // Step 3: Send m_num_txns transactions
        repeat (m_num_txns) begin
            txn = axi4_transaction::type_id::create("txn");
            start_item(txn);

            // Step 1: Disable c_size built-in constraint (limits size to <=4)
            //         to allow size=7 (128 bytes/beat)
            txn.c_size.constraint_mode(0);

            // Step 1: Fix len=0 and size=7; Step 2: fix address
            if (!txn.randomize() with {
                m_trans_type  == TRANS_WRITE;
                m_burst       == BURST_INCR;
                m_len         == 8'd0;        // len=0: single beat
                m_size        == 3'd7;        // size=7: 128 bytes/beat
                m_addr[31:0]  == local::cur_addr;
                m_addr[63:32] == 32'h0;
            }) `uvm_fatal(get_type_name(), "Randomization failed")

            // All byte lanes enabled (4'hF for 32-bit bus wstrb)
            txn.m_wstrb[0] = 4'hF;

            finish_item(txn);

            // Advance address by one beat: 2^7 = 128 bytes
            cur_addr += 32'd128;
        end

        `uvm_info(get_type_name(),
            $sformatf("Done: sent %0d transactions, last_addr=0x%08h",
                      m_num_txns, cur_addr - 32'd128),
            UVM_LOW)
    endtask

endclass : axi4_fixed_len0_size7_seq
