//-----------------------------------------------------------------------------
// File: axi4_system_cfg.sv
// Description: AXI4 VIP System-Level Configuration Object
//              Contains bus-topology and protocol watchdog settings shared
//              across all masters in a single environment instance.
//-----------------------------------------------------------------------------

class axi4_system_cfg extends uvm_object;
    `uvm_object_utils(axi4_system_cfg)

    // Allow multiple slave regions with overlapping address ranges
    bit          allow_slaves_with_overlapping_addr = 0;

    // Watchdog timeouts (in clock cycles; 0 = disabled)
    // awready_watchdog_timeout: max cycles to wait for AWREADY after AWVALID
    int unsigned awready_watchdog_timeout           = 0;
    // arready_watchdog_timeout: max cycles to wait for ARREADY after ARVALID
    int unsigned arready_watchdog_timeout           = 0;

    function new(string name = "axi4_system_cfg");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "axi4_system_cfg: allow_ovlp_addr=%0b aw_wdog=%0d ar_wdog=%0d",
            allow_slaves_with_overlapping_addr,
            awready_watchdog_timeout,
            arready_watchdog_timeout
        );
    endfunction

endclass : axi4_system_cfg
