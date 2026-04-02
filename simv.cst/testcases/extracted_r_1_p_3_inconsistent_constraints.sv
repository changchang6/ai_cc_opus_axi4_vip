class c_1_3;
    bit[31:0] m_cfg_m_data_width = 32'h20;
    bit[31:0] m_cfg = 32'h1;
    rand bit[2:0] m_size; // rand_mode = ON 

    constraint c_cfg_limits_this    // (constraint_mode = ON) (src/axi4_transaction.sv:53)
    {
       (m_cfg != 32'h0) -> ((1 << m_size) <= (m_cfg_m_data_width / 8));
    }
    constraint WITH_CONSTRAINT_this    // (constraint_mode = ON) (src/seq_lib.sv:67)
    {
       (m_size == 3'h7);
    }
endclass

program p_1_3;
    c_1_3 obj;
    string randState;

    initial
        begin
            obj = new;
            randState = "10zzx01xxxxx0111zxx01110z01zxxz1zzzzxzxxxxzzzxxxzxzxxzzzzxzzzxxz";
            obj.set_randstate(randState);
            obj.randomize();
        end
endprogram
