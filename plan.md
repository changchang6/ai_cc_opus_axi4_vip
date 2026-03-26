# AXI4 Master VIP 实现计划

## 修改记录
- v1.0 初始版本
- v1.1 根据用户反馈：去掉 scoreboard 和 coverage 组件；目标仅 VCS 编译通过（不跑测试）

---

## Context
基于 AXI4_MASTER_VIP_SPEC.md 的要求，使用 UVM 框架构建一个完整的 AXI4 Master VIP。VIP 需要支持规范中列出的全部 10 个 Feature、12 条 SVA 断言，以及完整的 UVM 验证组件架构。代码风格遵循 UVM_coding_style.md 中的 59 条规范。目标：VCS 编译通过。

---

## 目录结构

```
ai_cc_son_axi4_vip/
├── src/
│   ├── axi4_base_test.sv      # base test（含示例 test）
│   ├── axi4_types.sv          # 枚举/struct 类型定义（不在 pkg 内，先编译）
│   ├── axi4_pkg.sv            # 包文件，import axi4_types，include 所有 class
│   ├── axi4_if.sv             # SV 接口 + clocking block + 12 条 SVA
│   ├── axi4_vip_cfg.sv        # 配置对象
│   ├── axi4_transaction.sv    # 核心事务对象
│   ├── axi4_sequence_lib.sv   # base sequence + 多个具体 sequence
│   ├── axi4_sequencer.sv      # UVM sequencer（轻量）
│   ├── axi4_master_driver.sv  # Master 驱动（最复杂）
│   └── axi4_monitor.sv        # 被动监测 + 统计
└── tb/
    └──tb_top.sv              # testbench 顶层（时钟/复位/DUT stub）
```

---

## 各文件实现要点

### axi4_types.sv
- **独立 package `axi4_types_pkg`**，供 axi4_if.sv 和 axi4_pkg.sv 共同 import
- 定义内容：
  ```systemverilog
  package axi4_types_pkg;
    // Burst type
    typedef enum logic [1:0] {
      AXI4_FIXED = 2'b00,
      AXI4_INCR  = 2'b01,
      AXI4_WRAP  = 2'b10
    } axi4_burst_e;

    // Response type
    typedef enum logic [1:0] {
      AXI4_OKAY   = 2'b00,
      AXI4_EXOKAY = 2'b01,
      AXI4_SLVERR = 2'b10,
      AXI4_DECERR = 2'b11
    } axi4_resp_e;

    // Transaction direction
    typedef enum bit {
      AXI4_WRITE = 1'b1,
      AXI4_READ  = 1'b0
    } axi4_dir_e;

    // Lock type
    typedef enum logic [0:0] {
      AXI4_NORMAL    = 1'b0,
      AXI4_EXCLUSIVE = 1'b1
    } axi4_lock_e;

    // W beat struct（用于 driver mailbox）
    typedef struct packed {
      logic [63:0] wdata;   // 最大 64-bit，driver 内按实际宽度截位
      logic [7:0]  wstrb;
      logic        wlast;
    } axi4_w_beat_t;

    // 统计结构体
    typedef struct {
      longint unsigned total_bytes;
      longint unsigned latency_max;
      real             latency_sum;
      int unsigned     latency_cnt;
      logic [7:0]      latency_max_id;
    } axi4_stat_t;
  endpackage
  ```

### axi4_if.sv
- 参数：`DATA_WIDTH=32`, `ADDR_WIDTH=32`, `ID_WIDTH=4`, `USER_WIDTH=1`
- 5 个 AXI4 通道完整信号（logic）
- `import axi4_types_pkg::*`
- **clocking block**：
  - `master_cb`：`@(posedge ACLK)`，输出 `##1`，输入 `#1step`
  - `monitor_cb`：仅输入，`#1step`
- modport：`master_mp`、`monitor_mp`
- **12 条 SVA**（`disable iff (!ARESETn)`）：
  1. AWVALID 稳定：`(AWVALID && !AWREADY) |=> AWVALID`
  2. ARVALID 稳定：同上
  3. WVALID 稳定：`(WVALID && !WREADY) |=> WVALID`
  4. WLAST 正确性：用 `logic [8:0] wbeat_cnt` 辅助变量追踪，AW 握手时装载 AWLEN+1
  5. RLAST 正确性：AR 握手时装载 ARLEN+1，检查最后拍 RLAST=1
  6. AXLEN 范围：FIXED→AWLEN≤15，WRAP→AWLEN∈{1,3,7,15}
  7. AXBURST 编码：`AWBURST inside {0,1,2}`
  8. AXSIZE 范围：`(1<<AWSIZE) <= DATA_WIDTH/8`
  9. W 通道稳定：`(WVALID && !WREADY) |=> $stable({WDATA,WSTRB,WLAST})`
  10. AR 通道稳定：`(ARVALID && !ARREADY) |=> $stable({ARADDR,ARID,...})`
  11. WSTRB 宽度：参数化断言（编译时检查 `$bits(WSTRB)==DATA_WIDTH/8`）
  12. 非对齐首拍 WSTRB：用 `saved_awaddr` 寄存器记录地址，首拍 W beat 检查低位 strobe 为 0

### axi4_vip_cfg.sv
- 继承 `uvm_object`，`uvm_object_utils` 注册
- 成员变量（`m_` 前缀，全部 `int unsigned` 或 `bit`）：
  - `m_data_width`、`m_addr_width`、`m_id_width`
  - `m_max_outstanding`、`m_send_interval`
  - `m_data_before_addr_osd`
  - `m_wtimeout`、`m_rtimeout`
  - `m_is_active`（`uvm_active_passive_enum`）
  - `m_vif`（`virtual axi4_if`）
- 默认值：data_width=32, addr_width=32, id_width=4, max_outstanding=8, timeout=1000
- `function void check_config()`：验证 data_width 为 2 的幂，addr_width∈{32,64}

### axi4_transaction.sv
- 继承 `uvm_sequence_item`，`uvm_object_utils`（首行）
- **不使用** field macros
- `rand` 成员（`m_` 前缀）：
  - `m_axid [ID_WIDTH-1:0]`、`m_axaddr`、`m_axlen [7:0]`、`m_axsize [2:0]`、`m_axburst [1:0]`
  - `m_axlock [0:0]`、`m_axcache [3:0]`、`m_axprot [2:0]`、`m_axqos [3:0]`
  - `m_is_write`（bit）
  - 动态数组：`m_wdata[]`、`m_wstrb[]`
- 非 rand：`m_bresp`、`m_bid`、`m_rdata[]`、`m_rresp[]`、`m_start_time`、`m_end_time`
- **约束**：FIXED axlen≤15，WRAP axlen∈{1,3,7,15}，axburst≠3，axsize合法，动态数组大小=axlen+1
- 覆写：`convert2string`、`do_copy`（foreach 深拷贝动态数组）、`do_compare`、`do_print`

### axi4_master_driver.sv（最复杂）
- 继承 `uvm_driver #(axi4_transaction)`
- `run_phase` fork 四个并行线程：
  1. `drive_aw_w_channels()`
  2. `drive_w_channel()`（从 mailbox 消费）
  3. `collect_b_channel()`（含超时）
  4. `drive_ar_r_channels()`（含读超时）
- **事务处理流程**（drive_aw_w_channels 内）：
  1. `try_get` 获取事务（非阻塞）
  2. 先做 **2KB 地址分割**：`split_2k_boundary()` 返回子事务队列
  3. 对每个子事务做 **INCR>16 分割**：`split_incr_long()` 最大 32 beats/sub，分配不同 ID
  4. 计算非对齐首拍 WSTRB mask：`~((1<<byte_offset)-1)`
  5. 若 `data_before_addr_osd>0`，先 push 前 N 个 W beats 到 mailbox
  6. 驱动 AWVALID，等待 AWREADY
  7. push 剩余 W beats 到 mailbox
- **超时**：WLAST 握手后 fork/join_any 竞争 BVALID 与 wtimeout 周期计数
- **outstanding 控制**：信号量 `m_wr_sem`（m_max_outstanding）控制并发

### axi4_monitor.sv
- 继承 `uvm_monitor`，**不驱动任何信号**
- `m_wr_ap`、`m_rd_ap`（`uvm_analysis_port`）
- fork 五个线程：collect_aw / collect_w / collect_b / collect_ar / collect_r
- **WID 缺失**：维护 `m_aw_id_fifo[$]` 按 AW 握手顺序，W beats 按 FIFO 顺序分配
- **统计**（`axi4_stat_t` 类型，import from axi4_types_pkg）：
  - 写/读延迟：AW/AR 握手 → B/RLAST 握手的周期差
  - 带宽：累计有效字节数 / 仿真时长
- `report_phase`：输出带宽利用率、最大/平均读写延迟及对应 ID

### axi4_sequence_lib.sv
- `axi4_base_seq`：`pre_start` 获取 cfg，`post_start` drop objection
- `axi4_write_seq`：单次写 burst
- `axi4_read_seq`：单次读 burst
- `axi4_incr_long_seq`：axlen>16 触发 split
- `axi4_unaligned_seq`：非对齐地址
- **不使用** `uvm_do` 宏，用 `start_item` / `randomize()` / `finish_item`
- `pre_start` raise objection，`post_start` drop objection

### axi4_sequencer.sv
- 继承 `uvm_sequencer #(axi4_transaction)`，无额外逻辑

### axi4_master_agent.sv
- `build_phase`：从 config_db 获取 cfg
- 按 `m_is_active` 条件创建 driver/sequencer（passive 模式只创建 monitor）
- `connect_phase`：driver.seq_item_port → sequencer.seq_item_export

### axi4_env.sv
- 创建 cfg（若未从外部注入则新建），push 到子组件
- 创建 master_agent
- 不包含 scoreboard/coverage

### tb/tb_top.sv
- 时钟：`always #5 ACLK = ~ACLK`（100MHz，仅在 module 中生成）
- 复位：10 周期后拉高 ARESETn
- 实例化 `axi4_if`（参数化）
- `uvm_config_db::set` 注入 vif
- `run_test()` 启动

### tb/axi4_base_test.sv
- 获取 vif，设置 cfg，创建 env
- `run_phase` 调用 `axi4_write_seq` + `axi4_read_seq`

### scripts/compile.sh（VCS）
```bash
#!/bin/bash
VCS="vcs -full64 -sverilog -timescale=1ns/1ps \
    +incdir+../src \
    -ntb_opts uvm-1.2 \
    +define+UVM_NO_DEPRECATED \
    -debug_access+all"

$VCS \
    ../src/axi4_types.sv \
    ../src/axi4_if.sv \
    ../src/axi4_pkg.sv \
    ../tb/tb_top.sv \
    ../tb/axi4_base_test.sv \
    -top tb_top \
    -o simv 2>&1 | tee compile.log
```

---

## 编译顺序（VCS）
```
1. axi4_types.sv    → package axi4_types_pkg（无依赖）
2. axi4_if.sv       → import axi4_types_pkg（SV module）
3. axi4_pkg.sv      → import axi4_types_pkg，包含以下 include 顺序：
   axi4_vip_cfg.sv → axi4_transaction.sv → axi4_sequence_lib.sv →
   axi4_sequencer.sv → axi4_master_driver.sv → axi4_monitor.sv →
   axi4_master_agent.sv → axi4_env.sv
4. tb_top.sv
5. axi4_base_test.sv
```

---

## 额外支持的 Feature（超出规范）

| Feature | 说明 |
|---------|------|
| 窄传输（Narrow Transfer） | AXSIZE < 总线宽度时，每拍 WSTRB 随地址偏移自动计算 |
| BREADY/RREADY 背压控制 | 默认持续拉高，可通过 cfg 配置延迟断言 |
| 复位处理 | ARESETn 异步复位时中止 in-flight 操作，置 VALID 为 0 |
| AW/AR 发送间隔控制 | `m_send_interval` 周期延迟 |
| 最大 outstanding 控制 | 信号量控制同时进行的写/读事务数 |
