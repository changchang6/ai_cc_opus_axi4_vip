//-----------------------------------------------------------------------------
// File: axi4_config.sv
// Description: AXI4 VIP Configuration Object
//-----------------------------------------------------------------------------

class axi4_config extends uvm_object;
    `uvm_object_utils(axi4_config)

    // Bus parameters
    int unsigned m_data_width        = 32;
    int unsigned m_addr_width        = 32;
    int unsigned m_id_width          = 4;

    // Flow control
    int unsigned m_max_outstanding   = 8;
    int unsigned m_send_interval     = 0;

    // Data-before-address
    bit          m_support_data_before_addr  = 0;
    int unsigned m_data_before_addr_osd      = 0;

    // Timeout (0 = disabled)
    int unsigned m_wtimeout          = 0;
    int unsigned m_rtimeout          = 0;

    // Active/passive
    uvm_active_passive_enum m_is_active = UVM_ACTIVE;

    // Virtual interface
    virtual axi4_if m_vif;

    function new(string name = "axi4_config");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "axi4_config: data_width=%0d addr_width=%0d id_width=%0d max_outstanding=%0d send_interval=%0d data_before_addr=%0b dba_osd=%0d wtimeout=%0d rtimeout=%0d is_active=%s",
            m_data_width, m_addr_width, m_id_width,
            m_max_outstanding, m_send_interval,
            m_support_data_before_addr, m_data_before_addr_osd,
            m_wtimeout, m_rtimeout,
            m_is_active.name()
        );
    endfunction

endclass : axi4_config
