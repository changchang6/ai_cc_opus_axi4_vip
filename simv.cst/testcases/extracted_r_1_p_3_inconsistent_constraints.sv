class c_1_3;
    bit[2:0] max_size = 3'h3;
    rand bit[2:0] m_size; // rand_mode = ON 

    constraint c_size_this    // (constraint_mode = ON) (src/axi4_transaction.sv:70)
    {
       ((1 << m_size) <= (32 / 8));
    }
    constraint WITH_CONSTRAINT_this    // (constraint_mode = ON) (src/seq_lib.sv:1132)
    {
       (m_size == max_size);
    }
endclass

program p_1_3;
    c_1_3 obj;
    string randState;

    initial
        begin
            obj = new;
            randState = "0zz0x1xz1z001x110z00x11xxxz0x00xxzzzxzzzzzxzzxxxxxxzxzzxzzzzxzxz";
            obj.set_randstate(randState);
            obj.randomize();
        end
endprogram
