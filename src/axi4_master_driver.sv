//-----------------------------------------------------------------------------
// File: axi4_master_driver.sv
// Description: AXI4 Master Driver
//-----------------------------------------------------------------------------

class axi4_master_driver extends uvm_driver #(axi4_transaction);
    `uvm_component_utils(axi4_master_driver)

    axi4_config             m_cfg;
    virtual axi4_if         m_vif;

    // Outstanding transaction tracking: id -> start_cycle
    longint unsigned        m_wr_pending[logic [7:0]];
    longint unsigned        m_rd_pending[logic [7:0]];
    longint unsigned        m_cycle;

    function new(string name = "axi4_master_driver", uvm_component parent = null);
        super.new(name, parent);
        m_cycle = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(axi4_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("AXI4_DRV", "Cannot get axi4_config from config_db")
        m_vif = m_cfg.m_vif;
    endfunction

    task run_phase(uvm_phase phase);
        // De-assert all outputs
        m_vif.master_cb.awvalid_m <= 0;
        m_vif.master_cb.wvalid_m  <= 0;
        m_vif.master_cb.bready_m  <= 1;
        m_vif.master_cb.arvalid_m <= 0;
        m_vif.master_cb.rready_m  <= 1;

        // Wait for reset de-assertion
        @(posedge m_vif.rst_n);
        @(m_vif.master_cb);

        fork
            drive_write_channel();
            drive_read_channel();
            count_cycles();
            monitor_timeout();
        join
    endtask

    //-------------------------------------------------------------------------
    // Cycle counter
    //-------------------------------------------------------------------------
    task count_cycles();
        forever begin
            @(m_vif.master_cb);
            m_cycle++;
        end
    endtask

    //-------------------------------------------------------------------------
    // Write channel: AW + W + B
    //-------------------------------------------------------------------------
    task drive_write_channel();
        axi4_transaction txn;
        forever begin
            seq_item_port.get_next_item(txn);
            if (txn.m_trans_type == TRANS_WRITE) begin
                // Check if split needed
                if (txn.m_burst == BURST_INCR &&
                    (txn.m_len > 8'd15 ||
                     crosses_2kb_boundary(txn.m_addr[31:0], txn.m_len, txn.m_size))) begin
                    txn.do_burst_split();
                    foreach (txn.m_sub_bursts[i]) begin
                        wait_for_outstanding_slot();
                        drive_single_write(txn.m_sub_bursts[i]);
                    end
                end else begin
                    wait_for_outstanding_slot();
                    drive_single_write(txn);
                end
                // Send interval
                repeat (m_cfg.m_send_interval) @(m_vif.master_cb);
            end
            seq_item_port.item_done();
        end
    endtask

    task wait_for_outstanding_slot();
        while (m_wr_pending.size() >= m_cfg.m_max_outstanding)
            @(m_vif.master_cb);
    endtask

    task drive_single_write(axi4_transaction txn);
        if (m_cfg.m_support_data_before_addr) begin
            fork
                drive_w_channel(txn);
                begin
                    // Delay AW by up to data_before_addr_osd beats
                    repeat (m_cfg.m_data_before_addr_osd) @(m_vif.master_cb);
                    drive_aw_channel(txn);
                end
            join
        end else begin
            fork
                drive_aw_channel(txn);
                drive_w_channel(txn);
            join
        end
        drive_b_channel(txn);
    endtask

    task drive_aw_channel(axi4_transaction txn);
        m_vif.master_cb.awaddr_m   <= txn.m_addr[31:0];
        m_vif.master_cb.awid_m     <= txn.m_id[3:0];
        m_vif.master_cb.awlen_m    <= txn.m_len;
        m_vif.master_cb.awsize_m   <= txn.m_size;
        m_vif.master_cb.awburst_m  <= txn.m_burst;
        m_vif.master_cb.awlock_m   <= txn.m_lock;
        m_vif.master_cb.awcache_m  <= txn.m_cache;
        m_vif.master_cb.awprot_m   <= txn.m_prot;
        m_vif.master_cb.awqos_m    <= txn.m_qos;
        m_vif.master_cb.awregion_m <= txn.m_region;
        m_vif.master_cb.awvalid_m  <= 1;
        @(m_vif.master_cb);
        while (!m_vif.master_cb.awready_m) @(m_vif.master_cb);
        txn.m_aw_accept_time = m_cycle;
        m_wr_pending[txn.m_id] = m_cycle;
        m_vif.master_cb.awvalid_m <= 0;
    endtask

    task drive_w_channel(axi4_transaction txn);
        int num_beats;
        num_beats = int'(txn.m_len) + 1;
        for (int i = 0; i < num_beats; i++) begin
            m_vif.master_cb.wdata_m  <= txn.m_data[i];
            m_vif.master_cb.wstrb_m  <= txn.m_wstrb[i];
            m_vif.master_cb.wlast_m  <= (i == num_beats - 1);
            m_vif.master_cb.wvalid_m <= 1;
            @(m_vif.master_cb);
            while (!m_vif.master_cb.wready_m) @(m_vif.master_cb);
        end
        txn.m_wlast_time = m_cycle;
        m_vif.master_cb.wvalid_m <= 0;
        m_vif.master_cb.wlast_m  <= 0;
    endtask

    task drive_b_channel(axi4_transaction txn);
        // Wait for B response
        while (!(m_vif.master_cb.bvalid_m && m_vif.bready_m)) @(m_vif.master_cb);
        txn.m_bresp = m_vif.master_cb.bresp_m;
        if (m_wr_pending.exists(txn.m_id))
            m_wr_pending.delete(txn.m_id);
        if (txn.m_bresp != 2'b00)
            `uvm_error("AXI4_DRV", $sformatf("Write response error: bresp=%0b id=0x%0h", txn.m_bresp, txn.m_id))
    endtask

    //-------------------------------------------------------------------------
    // Read channel: AR + R
    //-------------------------------------------------------------------------
    task drive_read_channel();
        axi4_transaction txn;
        forever begin
            seq_item_port.get_next_item(txn);
            if (txn.m_trans_type == TRANS_READ) begin
                drive_ar_channel(txn);
                drive_r_channel(txn);
                repeat (m_cfg.m_send_interval) @(m_vif.master_cb);
            end
            seq_item_port.item_done();
        end
    endtask

    task drive_ar_channel(axi4_transaction txn);
        m_vif.master_cb.araddr_m   <= txn.m_addr[31:0];
        m_vif.master_cb.arid_m     <= txn.m_id[3:0];
        m_vif.master_cb.arlen_m    <= txn.m_len;
        m_vif.master_cb.arsize_m   <= txn.m_size;
        m_vif.master_cb.arburst_m  <= txn.m_burst;
        m_vif.master_cb.arlock_m   <= txn.m_lock;
        m_vif.master_cb.arcache_m  <= txn.m_cache;
        m_vif.master_cb.arprot_m   <= txn.m_prot;
        m_vif.master_cb.arqos_m    <= txn.m_qos;
        m_vif.master_cb.arregion_m <= txn.m_region;
        m_vif.master_cb.arvalid_m  <= 1;
        @(m_vif.master_cb);
        while (!m_vif.master_cb.arready_m) @(m_vif.master_cb);
        txn.m_ar_accept_time = m_cycle;
        m_rd_pending[txn.m_id] = m_cycle;
        m_vif.master_cb.arvalid_m <= 0;
    endtask

    task drive_r_channel(axi4_transaction txn);
        int num_beats;
        num_beats = int'(txn.m_len) + 1;
        txn.m_rdata = new[num_beats];
        txn.m_rresp = new[num_beats];
        for (int i = 0; i < num_beats; i++) begin
            while (!(m_vif.master_cb.rvalid_m && m_vif.rready_m)) @(m_vif.master_cb);
            txn.m_rdata[i] = m_vif.master_cb.rdata_m;
            txn.m_rresp[i] = m_vif.master_cb.rresp_m;
            if (m_vif.master_cb.rlast_m) begin
                txn.m_rlast_time = m_cycle;
                if (m_rd_pending.exists(txn.m_id))
                    m_rd_pending.delete(txn.m_id);
            end
            @(m_vif.master_cb);
        end
    endtask

    //-------------------------------------------------------------------------
    // Timeout monitor
    //-------------------------------------------------------------------------
    task monitor_timeout();
        forever begin
            @(m_vif.master_cb);
            if (m_cfg.m_wtimeout > 0) begin
                foreach (m_wr_pending[id]) begin
                    if ((m_cycle - m_wr_pending[id]) > m_cfg.m_wtimeout)
                        `uvm_error("AXI4_DRV",
                            $sformatf("Write timeout: awid=0x%0h pending for %0d cycles (limit=%0d)",
                                id, m_cycle - m_wr_pending[id], m_cfg.m_wtimeout))
                end
            end
            if (m_cfg.m_rtimeout > 0) begin
                foreach (m_rd_pending[id]) begin
                    if ((m_cycle - m_rd_pending[id]) > m_cfg.m_rtimeout)
                        `uvm_error("AXI4_DRV",
                            $sformatf("Read timeout: arid=0x%0h pending for %0d cycles (limit=%0d)",
                                id, m_cycle - m_rd_pending[id], m_cfg.m_rtimeout))
                end
            end
        end
    endtask

endclass : axi4_master_driver
