//-----------------------------------------------------------------------------
// File: axi4_monitor.sv
// Description: AXI4 Monitor with bandwidth and latency statistics
//-----------------------------------------------------------------------------

class axi4_monitor extends uvm_monitor;
    `uvm_component_utils(axi4_monitor)

    axi4_config                         m_cfg;
    axi4_vif_t                          m_vif;
    uvm_analysis_port #(axi4_transaction) m_ap;

    // In-flight write transactions: awid -> transaction
    axi4_transaction m_wr_inflight[logic [7:0]];
    // In-flight read transactions: arid -> transaction
    axi4_transaction m_rd_inflight[logic [7:0]];

    // Bandwidth stats
    longint unsigned m_total_valid_bytes;
    longint unsigned m_total_cycles;
    longint unsigned m_first_cycle;
    bit              m_active;

    // Write latency stats
    longint unsigned m_wr_lat_sum;
    int              m_wr_lat_count;
    longint unsigned m_wr_lat_max;
    logic [7:0]      m_wr_lat_max_id;

    // Read latency stats
    longint unsigned m_rd_lat_sum;
    int              m_rd_lat_count;
    longint unsigned m_rd_lat_max;
    logic [7:0]      m_rd_lat_max_id;

    // Cycle counter
    longint unsigned m_cycle;

    // Timeout ID tracking
    logic [7:0] m_wr_timeout_ids[$];
    logic [7:0] m_rd_timeout_ids[$];

    function new(string name = "axi4_monitor", uvm_component parent = null);
        super.new(name, parent);
        m_total_valid_bytes = 0;
        m_total_cycles      = 0;
        m_active            = 0;
        m_wr_lat_sum        = 0;
        m_wr_lat_count      = 0;
        m_wr_lat_max        = 0;
        m_rd_lat_sum        = 0;
        m_rd_lat_count      = 0;
        m_rd_lat_max        = 0;
        m_cycle             = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_ap = new("m_ap", this);
        if (!uvm_config_db #(axi4_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("AXI4_MON", "Cannot get axi4_config from config_db")
        m_vif = m_cfg.m_vif;
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge m_vif.rst_n);
        @(m_vif.monitor_cb);
        m_first_cycle = 0;
        m_active      = 1;

        fork
            count_cycles();
            observe_aw_channel();
            observe_w_channel();
            observe_b_channel();
            observe_ar_channel();
            observe_r_channel();
        join
    endtask

    task count_cycles();
        forever begin
            @(m_vif.monitor_cb);
            m_cycle++;
            m_total_cycles++;
        end
    endtask

    //-------------------------------------------------------------------------
    // X-value checkers: called on handshake, report any X/Z via uvm_error
    //-------------------------------------------------------------------------
    function void check_x_aw();
        if ($isunknown(m_vif.monitor_cb.awaddr) || $isunknown(m_vif.monitor_cb.awid)   ||
            $isunknown(m_vif.monitor_cb.awlen)  || $isunknown(m_vif.monitor_cb.awsize) ||
            $isunknown(m_vif.monitor_cb.awburst))
            `uvm_error("AXI4_MON_X",
                $sformatf("X/Z on AW channel at handshake: awaddr=%0h awid=%0h awlen=%0h awsize=%0h awburst=%0h",
                    m_vif.monitor_cb.awaddr, m_vif.monitor_cb.awid,
                    m_vif.monitor_cb.awlen,  m_vif.monitor_cb.awsize,
                    m_vif.monitor_cb.awburst))
    endfunction

    function void check_x_w();
        if ($isunknown(m_vif.monitor_cb.wdata) || $isunknown(m_vif.monitor_cb.wstrb) ||
            $isunknown(m_vif.monitor_cb.wlast))
            `uvm_error("AXI4_MON_X",
                $sformatf("X/Z on W channel at handshake: wdata=%0h wstrb=%0h wlast=%0h",
                    m_vif.monitor_cb.wdata, m_vif.monitor_cb.wstrb, m_vif.monitor_cb.wlast))
    endfunction

    function void check_x_ar();
        if ($isunknown(m_vif.monitor_cb.araddr) || $isunknown(m_vif.monitor_cb.arid)   ||
            $isunknown(m_vif.monitor_cb.arlen)  || $isunknown(m_vif.monitor_cb.arsize) ||
            $isunknown(m_vif.monitor_cb.arburst))
            `uvm_error("AXI4_MON_X",
                $sformatf("X/Z on AR channel at handshake: araddr=%0h arid=%0h arlen=%0h arsize=%0h arburst=%0h",
                    m_vif.monitor_cb.araddr, m_vif.monitor_cb.arid,
                    m_vif.monitor_cb.arlen,  m_vif.monitor_cb.arsize,
                    m_vif.monitor_cb.arburst))
    endfunction

    function void check_x_b();
        if ($isunknown(m_vif.monitor_cb.bid) || $isunknown(m_vif.monitor_cb.bresp))
            `uvm_error("AXI4_MON_X",
                $sformatf("X/Z on B channel at handshake: bid=%0h bresp=%0h",
                    m_vif.monitor_cb.bid, m_vif.monitor_cb.bresp))
    endfunction

    function void check_x_r();
        if ($isunknown(m_vif.monitor_cb.rid)   || $isunknown(m_vif.monitor_cb.rdata) ||
            $isunknown(m_vif.monitor_cb.rresp) || $isunknown(m_vif.monitor_cb.rlast))
            `uvm_error("AXI4_MON_X",
                $sformatf("X/Z on R channel at handshake: rid=%0h rdata=%0h rresp=%0h rlast=%0h",
                    m_vif.monitor_cb.rid, m_vif.monitor_cb.rdata,
                    m_vif.monitor_cb.rresp, m_vif.monitor_cb.rlast))
    endfunction

    //-------------------------------------------------------------------------
    // Observe AW channel
    //-------------------------------------------------------------------------
    task observe_aw_channel();
        forever begin
            @(m_vif.monitor_cb);
            if (m_vif.monitor_cb.awvalid && m_vif.monitor_cb.awready) begin
                axi4_transaction txn;
                check_x_aw();
                txn = axi4_transaction::type_id::create("mon_wr_txn");
                txn.m_trans_type    = TRANS_WRITE;
                txn.m_addr          = {32'h0, m_vif.monitor_cb.awaddr};
                txn.m_id            = {4'h0, m_vif.monitor_cb.awid};
                txn.m_len           = m_vif.monitor_cb.awlen;
                txn.m_size          = m_vif.monitor_cb.awsize;
                txn.m_burst         = axi4_burst_e'(m_vif.monitor_cb.awburst);
                txn.m_lock          = m_vif.monitor_cb.awlock;
                txn.m_cache         = m_vif.monitor_cb.awcache;
                txn.m_prot          = m_vif.monitor_cb.awprot;
                txn.m_qos           = m_vif.monitor_cb.awqos;
                txn.m_region        = m_vif.monitor_cb.awregion;
                txn.m_aw_accept_time = m_cycle;
                txn.m_data  = new[int'(m_vif.monitor_cb.awlen) + 1];
                txn.m_wstrb = new[int'(m_vif.monitor_cb.awlen) + 1];
                m_wr_inflight[m_vif.monitor_cb.awid] = txn;

                // Timeout check
                if (m_cfg.m_wtimeout > 0)
                    fork
                        automatic logic [7:0] tid = m_vif.monitor_cb.awid;
                        automatic longint unsigned tstart = m_cycle;
                        begin
                            repeat (m_cfg.m_wtimeout) @(m_vif.monitor_cb);
                            if (m_wr_inflight.exists(tid)) begin
                                m_wr_timeout_ids.push_back(tid);
                                `uvm_warning("AXI4_MON",
                                    $sformatf("Write timeout warning: awid=0x%0h at cycle %0d", tid, tstart))
                            end
                        end
                    join_none
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Observe W channel (data beats)
    //-------------------------------------------------------------------------
    task observe_w_channel();
        // Track which AW we're filling (simple: use first inflight)
        forever begin
            @(m_vif.monitor_cb);
            if (m_vif.monitor_cb.wvalid && m_vif.monitor_cb.wready) begin
                // Accumulate bandwidth
                check_x_w();
                m_total_valid_bytes += $countones(m_vif.monitor_cb.wstrb);
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Observe B channel
    //-------------------------------------------------------------------------
    task observe_b_channel();
        forever begin
            @(m_vif.monitor_cb);
            if (m_vif.monitor_cb.bvalid && m_vif.monitor_cb.bready) begin
                logic [7:0] bid_val;
                check_x_b();
                bid_val = {4'h0, m_vif.monitor_cb.bid};
                if (m_wr_inflight.exists(bid_val)) begin
                    axi4_transaction txn;
                    longint unsigned lat;
                    txn = m_wr_inflight[bid_val];
                    txn.m_bresp = m_vif.monitor_cb.bresp;
                    // Latency: aw_accept to wlast (approximated as current cycle)
                    lat = m_cycle - txn.m_aw_accept_time;
                    m_wr_lat_sum += lat;
                    m_wr_lat_count++;
                    if (lat > m_wr_lat_max) begin
                        m_wr_lat_max    = lat;
                        m_wr_lat_max_id = bid_val;
                    end
                    m_ap.write(txn);
                    m_wr_inflight.delete(bid_val);
                end
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Observe AR channel
    //-------------------------------------------------------------------------
    task observe_ar_channel();
        forever begin
            @(m_vif.monitor_cb);
            if (m_vif.monitor_cb.arvalid && m_vif.monitor_cb.arready) begin
                axi4_transaction txn;
                check_x_ar();
                txn = axi4_transaction::type_id::create("mon_rd_txn");
                txn.m_trans_type    = TRANS_READ;
                txn.m_addr          = {32'h0, m_vif.monitor_cb.araddr};
                txn.m_id            = {4'h0, m_vif.monitor_cb.arid};
                txn.m_len           = m_vif.monitor_cb.arlen;
                txn.m_size          = m_vif.monitor_cb.arsize;
                txn.m_burst         = axi4_burst_e'(m_vif.monitor_cb.arburst);
                txn.m_ar_accept_time = m_cycle;
                txn.m_rdata = new[int'(m_vif.monitor_cb.arlen) + 1];
                txn.m_rresp = new[int'(m_vif.monitor_cb.arlen) + 1];
                m_rd_inflight[m_vif.monitor_cb.arid] = txn;

                // Timeout check
                if (m_cfg.m_rtimeout > 0)
                    fork
                        automatic logic [7:0] tid = m_vif.monitor_cb.arid;
                        automatic longint unsigned tstart = m_cycle;
                        begin
                            repeat (m_cfg.m_rtimeout) @(m_vif.monitor_cb);
                            if (m_rd_inflight.exists(tid)) begin
                                m_rd_timeout_ids.push_back(tid);
                                `uvm_warning("AXI4_MON",
                                    $sformatf("Read timeout warning: arid=0x%0h at cycle %0d", tid, tstart))
                            end
                        end
                    join_none
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Observe R channel
    //-------------------------------------------------------------------------
    task observe_r_channel();
        forever begin
            @(m_vif.monitor_cb);
            if (m_vif.monitor_cb.rvalid && m_vif.monitor_cb.rready) begin
                logic [7:0] rid_val;
                check_x_r();
                rid_val = {4'h0, m_vif.monitor_cb.rid};
                if (m_vif.monitor_cb.rlast && m_rd_inflight.exists(rid_val)) begin
                    axi4_transaction txn;
                    longint unsigned lat;
                    txn = m_rd_inflight[rid_val];
                    txn.m_rlast_time = m_cycle;
                    lat = m_cycle - txn.m_ar_accept_time;
                    m_rd_lat_sum += lat;
                    m_rd_lat_count++;
                    if (lat > m_rd_lat_max) begin
                        m_rd_lat_max    = lat;
                        m_rd_lat_max_id = rid_val;
                    end
                    m_ap.write(txn);
                    m_rd_inflight.delete(rid_val);
                end
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // report_phase: print stats
    //-------------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        real utilization;
        real avg_wr_lat;
        real avg_rd_lat;
        int  dw_bytes;

        dw_bytes = int'(m_cfg.m_data_width) / 8;

        if (m_total_cycles > 0 && dw_bytes > 0)
            utilization = (real'(m_total_valid_bytes) / (real'(m_total_cycles) * real'(dw_bytes))) * 100.0;
        else
            utilization = 0.0;

        avg_wr_lat = (m_wr_lat_count > 0) ? real'(m_wr_lat_sum) / real'(m_wr_lat_count) : 0.0;
        avg_rd_lat = (m_rd_lat_count > 0) ? real'(m_rd_lat_sum) / real'(m_rd_lat_count) : 0.0;

        `uvm_info("AXI4_MON", $sformatf(
            "\n========== AXI4 Monitor Statistics ==========\n  Bandwidth Utilization : %.2f%%\n    Total valid bytes   : %0d\n    Total cycles        : %0d\n    Data width (bytes)  : %0d\n  Write Latency:\n    Max  : %0d cycles (awid=0x%0h)\n    Avg  : %.2f cycles\n    Count: %0d\n  Read Latency:\n    Max  : %0d cycles (arid=0x%0h)\n    Avg  : %.2f cycles\n    Count: %0d\n==============================================",
            utilization,
            m_total_valid_bytes,
            m_total_cycles,
            dw_bytes,
            m_wr_lat_max, m_wr_lat_max_id,
            avg_wr_lat,
            m_wr_lat_count,
            m_rd_lat_max, m_rd_lat_max_id,
            avg_rd_lat,
            m_rd_lat_count),
            UVM_NONE)
    endfunction

endclass : axi4_monitor
