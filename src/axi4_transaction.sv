//-----------------------------------------------------------------------------
// File: axi4_transaction.sv
// Description: AXI4 Transaction (sequence item)
//-----------------------------------------------------------------------------

class axi4_transaction extends uvm_sequence_item;
    `uvm_object_utils(axi4_transaction)

    //-------------------------------------------------------------------------
    // Randomizable fields
    //-------------------------------------------------------------------------
    rand axi4_trans_type_e  m_trans_type;
    rand logic [63:0]       m_addr;
    rand logic [7:0]        m_id;
    rand logic [7:0]        m_len;
    rand logic [2:0]        m_size;
    rand axi4_burst_e       m_burst;
    rand logic              m_lock;
    rand logic [3:0]        m_cache;
    rand logic [2:0]        m_prot;
    rand logic [3:0]        m_qos;
    rand logic [3:0]        m_region;
    rand logic [31:0]       m_data[];
    rand logic [3:0]        m_wstrb[];

    //-------------------------------------------------------------------------
    // Non-randomizable response/timing fields
    //-------------------------------------------------------------------------
    logic [1:0]  m_bresp;
    logic [1:0]  m_rresp[];
    logic [31:0] m_rdata[];

    longint unsigned m_aw_accept_time;
    longint unsigned m_wlast_time;
    longint unsigned m_ar_accept_time;
    longint unsigned m_rlast_time;

    //-------------------------------------------------------------------------
    // Split burst support
    //-------------------------------------------------------------------------
    axi4_transaction m_sub_bursts[$];
    bit              m_is_sub_burst;
    int              m_sub_burst_idx;

    //-------------------------------------------------------------------------
    // Constraints
    //-------------------------------------------------------------------------
    constraint c_burst_len {
        if (m_burst == BURST_FIXED)
            m_len <= 8'd15;
        else if (m_burst == BURST_WRAP)
            m_len inside {8'd1, 8'd3, 8'd7, 8'd15};
        else
            m_len <= 8'd255;
    }

    constraint c_size {
        (1 << m_size) <= (`AI_AXI4_MAX_DATA_WIDTH / 8);
    }

    constraint c_data_size {
        m_data.size()  == m_len + 1;
        m_wstrb.size() == m_len + 1;
    }

    constraint c_burst_valid {
        m_burst != BURST_RSVD;
    }

    constraint c_fixed_signals {
        m_lock  == 1'b0;
        m_cache == 4'b0;
        m_prot  == 3'b0;
    }

    //-------------------------------------------------------------------------
    // Constructor
    //-------------------------------------------------------------------------
    function new(string name = "axi4_transaction");
        super.new(name);
        m_is_sub_burst  = 0;
        m_sub_burst_idx = 0;
    endfunction

    //-------------------------------------------------------------------------
    // do_burst_split: split INCR burst at 16-beat and 2KB boundaries
    //-------------------------------------------------------------------------
    function void do_burst_split();
        int          total_beats;
        int          beat_idx;
        int          sub_idx;
        logic [31:0] cur_addr;
        int          beat_size;
        int          beats_remaining;
        int          beats_to_2kb;
        int          sub_beats;
        int          bytes_to_2kb;
        axi4_transaction sub;

        m_sub_bursts.delete();

        if (m_burst != BURST_INCR) return;

        total_beats    = int'(m_len) + 1;
        beat_size      = 1 << int'(m_size);
        cur_addr       = m_addr[31:0];
        beat_idx       = 0;
        sub_idx        = 0;
        beats_remaining = total_beats;

        while (beats_remaining > 0) begin
            // Beats until next 2KB boundary
            bytes_to_2kb   = int'(2048) - int'(cur_addr % 2048);
            beats_to_2kb   = bytes_to_2kb / beat_size;
            if (beats_to_2kb == 0) beats_to_2kb = 16;

            // Sub-burst length: min(remaining, 16, beats_to_2kb)
            sub_beats = beats_remaining;
            if (sub_beats > 16)          sub_beats = 16;
            if (sub_beats > beats_to_2kb) sub_beats = beats_to_2kb;

            sub = axi4_transaction::type_id::create(
                $sformatf("%s_sub%0d", get_name(), sub_idx));
            sub.m_trans_type    = m_trans_type;
            sub.m_addr          = {m_addr[63:32], cur_addr};
            sub.m_id            = m_id + sub_idx;
            sub.m_len           = 8'(sub_beats - 1);
            sub.m_size          = m_size;
            sub.m_burst         = BURST_INCR;
            sub.m_lock          = m_lock;
            sub.m_cache         = m_cache;
            sub.m_prot          = m_prot;
            sub.m_qos           = m_qos;
            sub.m_region        = m_region;
            sub.m_is_sub_burst  = 1;
            sub.m_sub_burst_idx = sub_idx;

            // Copy data/wstrb slices
            sub.m_data  = new[sub_beats];
            sub.m_wstrb = new[sub_beats];
            for (int i = 0; i < sub_beats; i++) begin
                sub.m_data[i]  = m_data[beat_idx + i];
                sub.m_wstrb[i] = m_wstrb[beat_idx + i];
            end

            m_sub_bursts.push_back(sub);

            cur_addr        = cur_addr + logic'(sub_beats * beat_size);
            beat_idx        += sub_beats;
            beats_remaining -= sub_beats;
            sub_idx++;
        end
    endfunction

    //-------------------------------------------------------------------------
    // calc_unaligned_wstrb: fix first-beat wstrb for unaligned address
    //-------------------------------------------------------------------------
    function void calc_unaligned_wstrb();
        int byte_offset;
        logic [3:0] full_mask;
        int beat_size;

        beat_size   = 1 << int'(m_size);
        byte_offset = int'(m_addr[31:0]) % beat_size;

        if (byte_offset == 0) return;

        full_mask      = (beat_size >= 4) ? 4'hF : 4'((1 << beat_size) - 1);
        m_wstrb[0]     = full_mask & ~4'((1 << byte_offset) - 1);
    endfunction

    //-------------------------------------------------------------------------
    // UVM field methods (manual — no field macros)
    //-------------------------------------------------------------------------
    function string convert2string();
        string s;
        s = $sformatf(
            "axi4_txn: type=%s addr=0x%0h id=0x%0h len=%0d size=%0d burst=%s lock=%0b",
            m_trans_type.name(), m_addr, m_id, m_len, m_size, m_burst.name(), m_lock
        );
        if (m_trans_type == TRANS_WRITE && m_bresp !== 2'bxx)
            s = {s, $sformatf(" bresp=%0b", m_bresp)};
        return s;
    endfunction

    function void do_copy(uvm_object rhs);
        axi4_transaction rhs_;
        if (!$cast(rhs_, rhs))
            `uvm_fatal("AXI4_TXN", "do_copy: type mismatch")
        super.do_copy(rhs);
        m_trans_type        = rhs_.m_trans_type;
        m_addr              = rhs_.m_addr;
        m_id                = rhs_.m_id;
        m_len               = rhs_.m_len;
        m_size              = rhs_.m_size;
        m_burst             = rhs_.m_burst;
        m_lock              = rhs_.m_lock;
        m_cache             = rhs_.m_cache;
        m_prot              = rhs_.m_prot;
        m_qos               = rhs_.m_qos;
        m_region            = rhs_.m_region;
        m_data              = rhs_.m_data;
        m_wstrb             = rhs_.m_wstrb;
        m_bresp             = rhs_.m_bresp;
        m_rresp             = rhs_.m_rresp;
        m_rdata             = rhs_.m_rdata;
        m_aw_accept_time    = rhs_.m_aw_accept_time;
        m_wlast_time        = rhs_.m_wlast_time;
        m_ar_accept_time    = rhs_.m_ar_accept_time;
        m_rlast_time        = rhs_.m_rlast_time;
        m_is_sub_burst      = rhs_.m_is_sub_burst;
        m_sub_burst_idx     = rhs_.m_sub_burst_idx;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        axi4_transaction rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (super.do_compare(rhs, comparer) &&
                m_trans_type == rhs_.m_trans_type &&
                m_addr       == rhs_.m_addr       &&
                m_id         == rhs_.m_id         &&
                m_len        == rhs_.m_len        &&
                m_size       == rhs_.m_size       &&
                m_burst      == rhs_.m_burst);
    endfunction

    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_string("m_trans_type", m_trans_type.name());
        printer.print_field_int("m_addr",  m_addr,  64, UVM_HEX);
        printer.print_field_int("m_id",    m_id,     8, UVM_HEX);
        printer.print_field_int("m_len",   m_len,    8, UVM_DEC);
        printer.print_field_int("m_size",  m_size,   3, UVM_DEC);
        printer.print_string("m_burst",    m_burst.name());
    endfunction

    function void do_record(uvm_recorder recorder);
        super.do_record(recorder);
        `uvm_record_string("m_trans_type", m_trans_type.name())
        `uvm_record_field("m_addr",  m_addr)
        `uvm_record_field("m_id",    m_id)
        `uvm_record_field("m_len",   m_len)
        `uvm_record_field("m_size",  m_size)
    endfunction

endclass : axi4_transaction
