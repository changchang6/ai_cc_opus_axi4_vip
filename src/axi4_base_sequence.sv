//-----------------------------------------------------------------------------
// File: axi4_base_sequence.sv
// Description: AXI4 Base Sequence and derived test sequences
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Base sequence
//-----------------------------------------------------------------------------
class axi4_base_sequence extends uvm_sequence #(axi4_transaction);
    `uvm_object_utils(axi4_base_sequence)

    function new(string name = "axi4_base_sequence");
        super.new(name);
    endfunction

    task pre_start();
        if (starting_phase != null) begin
            starting_phase.raise_objection(this);
            starting_phase.set_propagate_mode(0);
        end
    endtask

    task post_start();
        if (starting_phase != null)
            starting_phase.drop_objection(this);
    endtask

endclass : axi4_base_sequence

//-----------------------------------------------------------------------------
// Single write sequence
//-----------------------------------------------------------------------------
class axi4_write_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_write_seq)

    rand logic [31:0] m_addr;
    rand logic [7:0]  m_len;
    rand logic [2:0]  m_size;

    constraint c_defaults {
        m_len  inside {[0:15]};
        m_size inside {[0:2]};
    }

    function new(string name = "axi4_write_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction txn;
        txn = axi4_transaction::type_id::create("wr_txn");
        start_item(txn);
        if (!txn.randomize() with {
            m_trans_type == TRANS_WRITE;
            m_addr[31:0]  == local::m_addr;
            m_len         == local::m_len;
            m_size        == local::m_size;
            m_burst       == BURST_INCR;
        }) `uvm_fatal("AXI4_SEQ", "Randomization failed")
        txn.calc_unaligned_wstrb();
        finish_item(txn);
    endtask

endclass : axi4_write_seq

//-----------------------------------------------------------------------------
// Single read sequence
//-----------------------------------------------------------------------------
class axi4_read_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_read_seq)

    rand logic [31:0] m_addr;
    rand logic [7:0]  m_len;
    rand logic [2:0]  m_size;

    constraint c_defaults {
        m_len  inside {[0:15]};
        m_size inside {[0:2]};
    }

    function new(string name = "axi4_read_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction txn;
        txn = axi4_transaction::type_id::create("rd_txn");
        start_item(txn);
        if (!txn.randomize() with {
            m_trans_type == TRANS_READ;
            m_addr[31:0]  == local::m_addr;
            m_len         == local::m_len;
            m_size        == local::m_size;
            m_burst       == BURST_INCR;
        }) `uvm_fatal("AXI4_SEQ", "Randomization failed")
        finish_item(txn);
    endtask

endclass : axi4_read_seq

//-----------------------------------------------------------------------------
// Randomized burst of N transactions
//-----------------------------------------------------------------------------
class axi4_rand_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_rand_seq)

    int unsigned m_num_txns = 10;

    function new(string name = "axi4_rand_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction txn;
        repeat (m_num_txns) begin
            txn = axi4_transaction::type_id::create("rand_txn");
            start_item(txn);
            if (!txn.randomize() with {
                m_burst != BURST_RSVD;
                m_len   <= 8'd15;
            }) `uvm_fatal("AXI4_SEQ", "Randomization failed")
            if (txn.m_trans_type == TRANS_WRITE)
                txn.calc_unaligned_wstrb();
            finish_item(txn);
        end
    endtask

endclass : axi4_rand_seq

//-----------------------------------------------------------------------------
// WRAP burst test sequence
//-----------------------------------------------------------------------------
class axi4_wrap_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_wrap_seq)

    function new(string name = "axi4_wrap_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction txn;
        // Test all valid WRAP lengths: 2, 4, 8, 16 beats
        foreach ({8'd1, 8'd3, 8'd7, 8'd15}[i]) begin
            txn = axi4_transaction::type_id::create($sformatf("wrap_txn_%0d", i));
            start_item(txn);
            if (!txn.randomize() with {
                m_trans_type == TRANS_WRITE;
                m_burst      == BURST_WRAP;
                m_len        == {8'd1, 8'd3, 8'd7, 8'd15}[i];
                m_size       == 3'd2;
                // Aligned address for WRAP
                m_addr[1:0]  == 2'b00;
            }) `uvm_fatal("AXI4_SEQ", "WRAP randomization failed")
            finish_item(txn);
        end
    endtask

endclass : axi4_wrap_seq

//-----------------------------------------------------------------------------
// Split burst sequence: long INCR that triggers splitting
//-----------------------------------------------------------------------------
class axi4_split_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_split_seq)

    function new(string name = "axi4_split_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction txn;
        txn = axi4_transaction::type_id::create("split_txn");
        start_item(txn);
        if (!txn.randomize() with {
            m_trans_type == TRANS_WRITE;
            m_burst      == BURST_INCR;
            m_len        == 8'd31;   // 32 beats -> triggers split
            m_size       == 3'd2;    // 4 bytes/beat
            m_addr[11:0] == 12'h000; // aligned, no 2KB crossing
        }) `uvm_fatal("AXI4_SEQ", "Split randomization failed")
        finish_item(txn);
    endtask

endclass : axi4_split_seq

//-----------------------------------------------------------------------------
// Unaligned address transfer sequence
//-----------------------------------------------------------------------------
class axi4_unaligned_seq extends axi4_base_sequence;
    `uvm_object_utils(axi4_unaligned_seq)

    function new(string name = "axi4_unaligned_seq");
        super.new(name);
    endfunction

    task body();
        axi4_transaction txn;
        txn = axi4_transaction::type_id::create("unaligned_txn");
        start_item(txn);
        if (!txn.randomize() with {
            m_trans_type == TRANS_WRITE;
            m_burst      == BURST_INCR;
            m_len        == 8'd3;
            m_size       == 3'd2;    // 4 bytes/beat
            m_addr[1:0]  != 2'b00;  // unaligned
        }) `uvm_fatal("AXI4_SEQ", "Unaligned randomization failed")
        txn.calc_unaligned_wstrb();
        finish_item(txn);
    endtask

endclass : axi4_unaligned_seq
