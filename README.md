# AXI4 Master VIP

UVM-based AXI4 Master Verification IP supporting single and multi-master environments.

---

## Directory Structure

```
.
├── src/
│   ├── axi4_types.sv          # Enumerations, structs, helper functions
│   ├── axi4_if.sv             # SystemVerilog interface + SVA assertions
│   ├── axi4_pkg.sv            # Package (includes all classes)
│   ├── axi4_config.sv         # Per-agent configuration object
│   ├── axi4_system_cfg.sv     # System-level watchdog / topology config
│   ├── axi4_env_cfg.sv        # Multi-master environment configuration
│   ├── axi4_transaction.sv    # Sequence item (AXI4 transaction)
│   ├── axi4_sequencer.sv      # UVM sequencer
│   ├── axi4_master_driver.sv  # Protocol driver
│   ├── axi4_monitor.sv        # Passive monitor + statistics
│   ├── axi4_master_agent.sv   # Agent (driver + sequencer + monitor)
│   ├── axi4_env.sv            # Environment (single or multi-master)
│   ├── axi4_base_sequence.sv  # Ready-to-use stimulus sequences
│   └── axi4_base_test.sv      # Base test demonstrating env_cfg usage
├── tb/
│   └── axi4_tb_top.sv         # Testbench top with simple slave model
├── Makefile                   # VCS compilation and simulation rules
└── doc/                       # AXI4 protocol reference PDFs
```

---

## Configuration Classes

### `axi4_system_cfg`

System-level settings shared across all masters in one environment.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `allow_slaves_with_overlapping_addr` | `bit` | `0` | Allow overlapping slave address regions |
| `awready_watchdog_timeout` | `int unsigned` | `0` | Max cycles to wait for AWREADY (0 = off) |
| `arready_watchdog_timeout` | `int unsigned` | `0` | Max cycles to wait for ARREADY (0 = off) |

### `axi4_env_cfg`

Top-level environment configuration.  Holds a nested `axi4_system_cfg` and
per-master parameter arrays sized up to `AXI4_ENV_CFG_MAX_MASTERS` (default 32,
override with `` `define AXI4_ENV_CFG_MAX_MASTERS <N> ``).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `num_masters` | `int unsigned` | `1` | Number of master agents to create |
| `num_slaves` | `int unsigned` | `0` | Number of slave agents (informational) |
| `slave_is_active` | `bit` | `0` | Active (`1`) or passive (`0`) slaves |
| `axi4_en` | `bit` | `1` | Enable AXI4 mode (0 = AXI3-compatible) |
| `use_slave_with_overlapping_addr` | `bit` | `0` | Mirror of `u_axi_system_cfg.allow_slaves_with_overlapping_addr` |
| `clk_freq_mhz` | `int unsigned` | `1000` | Clock frequency in MHz (informational) |
| `enable_perf_mon` | `bit` | `0` | Enable bandwidth / latency reporting |
| `u_axi_system_cfg` | `axi4_system_cfg` | auto-created | Nested system config |
| `m_vif[]` | `virtual axi4_if` | — | One virtual interface per master |

**Per-master arrays** (index `0 .. num_masters-1`):

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `master_addr_width[idx]` | `int unsigned` | `32` | Address bus width |
| `master_data_width[idx]` | `int unsigned` | `32` | Data bus width |
| `master_id_width[idx]` | `int unsigned` | `4` | ID bus width |
| `max_read_outstanding[idx]` | `int unsigned` | `8` | Max in-flight read transactions |
| `max_write_outstanding[idx]` | `int unsigned` | `8` | Max in-flight write transactions |
| `awuser_enable[idx]` | `bit` | `0` | Enable AWUSER signal |
| `aruser_enable[idx]` | `bit` | `0` | Enable ARUSER signal |
| `ruser_enable[idx]` | `bit` | `0` | Enable RUSER signal |

**Method:**

```systemverilog
function void set_axi_system_cfg();
```

Call after all parameters are set.  Builds the internal `m_master_cfg[]` array
(one `axi4_config` per master) and propagates system-level settings.

### `axi4_config`

Per-agent low-level config.  Created automatically by `axi4_env_cfg.set_axi_system_cfg()`.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `m_addr_width` | `int unsigned` | `32` | Address width |
| `m_data_width` | `int unsigned` | `32` | Data width |
| `m_id_width` | `int unsigned` | `4` | ID width |
| `m_max_read_outstanding` | `int unsigned` | `8` | Max pending reads |
| `m_max_write_outstanding` | `int unsigned` | `8` | Max pending writes |
| `m_max_outstanding` | `int unsigned` | `8` | Legacy: sets both read and write |
| `m_send_interval` | `int unsigned` | `0` | Idle cycles between transactions |
| `m_support_data_before_addr` | `bit` | `0` | Allow W-before-AW |
| `m_wtimeout` | `int unsigned` | `0` | AW-to-B timeout in cycles (0 = off) |
| `m_rtimeout` | `int unsigned` | `0` | AR-to-RLAST timeout in cycles (0 = off) |
| `m_is_active` | `uvm_active_passive_enum` | `UVM_ACTIVE` | Active or passive |
| `m_vif` | `virtual axi4_if` | — | Virtual interface handle |

---

## Quick Start

### Single-Master Test

```systemverilog
class my_test extends uvm_test;
    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    function void build_phase(uvm_phase phase);
        virtual axi4_if vif;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        // Top-level settings
        m_env_cfg.num_masters                               = 1;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;

        // Per-master settings
        m_env_cfg.master_addr_width    [0] = 32;
        m_env_cfg.master_data_width    [0] = 64;
        m_env_cfg.master_id_width      [0] = 4;
        m_env_cfg.max_read_outstanding [0] = 8;
        m_env_cfg.max_write_outstanding[0] = 8;

        // Virtual interface
        void'(uvm_config_db #(virtual axi4_if)::get(this, "", "m_vif", vif));
        m_env_cfg.m_vif    = new[1];
        m_env_cfg.m_vif[0] = vif;

        // Finalise
        m_env_cfg.set_axi_system_cfg();
        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_rand_seq seq = axi4_rand_seq::type_id::create("seq");
        seq.m_num_txns = 20;
        phase.raise_objection(this);
        seq.start(m_env.m_agent.m_sequencer);  // m_agent = m_agents[0]
        phase.drop_objection(this);
    endtask
endclass
```

### Multi-Master Test

```systemverilog
// tb_top must declare multiple interfaces, e.g.:
//   axi4_if vif0(clk, rst_n);
//   axi4_if vif1(clk, rst_n);
//   initial begin
//     uvm_config_db #(virtual axi4_if)::set(null, "uvm_test_top", "m_vif0", vif0);
//     uvm_config_db #(virtual axi4_if)::set(null, "uvm_test_top", "m_vif1", vif1);
//   end

class my_multi_mst_test extends uvm_test;
    axi4_env     m_env;
    axi4_env_cfg m_env_cfg;

    localparam int NUM_MST = 2;

    function void build_phase(uvm_phase phase);
        virtual axi4_if vif0, vif1;
        super.build_phase(phase);

        m_env_cfg = axi4_env_cfg::type_id::create("m_env_cfg");

        m_env_cfg.num_masters                               = NUM_MST;
        m_env_cfg.num_slaves                                = 0;
        m_env_cfg.slave_is_active                           = 0;
        m_env_cfg.axi4_en                                   = 1;
        m_env_cfg.use_slave_with_overlapping_addr           = 0;
        m_env_cfg.u_axi_system_cfg.allow_slaves_with_overlapping_addr = 0;
        m_env_cfg.u_axi_system_cfg.awready_watchdog_timeout = 0;
        m_env_cfg.u_axi_system_cfg.arready_watchdog_timeout = 0;
        m_env_cfg.clk_freq_mhz                              = 1000;
        m_env_cfg.enable_perf_mon                           = 0;

        for (int idx = 0; idx < NUM_MST; idx++) begin
            m_env_cfg.master_addr_width    [idx] = 32;
            m_env_cfg.master_data_width    [idx] = 32;
            m_env_cfg.master_id_width      [idx] = 4;
            m_env_cfg.ruser_enable         [idx] = 0;
            m_env_cfg.aruser_enable        [idx] = 0;
            m_env_cfg.awuser_enable        [idx] = 0;
            m_env_cfg.max_read_outstanding [idx] = 8;
            m_env_cfg.max_write_outstanding[idx] = 8;
        end

        void'(uvm_config_db #(virtual axi4_if)::get(this, "", "m_vif0", vif0));
        void'(uvm_config_db #(virtual axi4_if)::get(this, "", "m_vif1", vif1));
        m_env_cfg.m_vif    = new[NUM_MST];
        m_env_cfg.m_vif[0] = vif0;
        m_env_cfg.m_vif[1] = vif1;

        m_env_cfg.set_axi_system_cfg();
        uvm_config_db #(axi4_env_cfg)::set(this, "*", "m_env_cfg", m_env_cfg);

        m_env = axi4_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_rand_seq seq0, seq1;
        seq0 = axi4_rand_seq::type_id::create("seq0");
        seq1 = axi4_rand_seq::type_id::create("seq1");
        seq0.m_num_txns = 10;
        seq1.m_num_txns = 10;
        phase.raise_objection(this);
        fork
            seq0.start(m_env.m_agents[0].m_sequencer);
            seq1.start(m_env.m_agents[1].m_sequencer);
        join
        phase.drop_objection(this);
    endtask
endclass
```

### Matching the `foreach` Pattern

The env_cfg API is compatible with the style used in integration testbenches:

```systemverilog
// Declaration in your scoreboard/env:
//   axi4_env_cfg u_axi_mst_env_cfg[NUM_ENV];

foreach (u_axi_mst_env_cfg[i]) begin
    u_axi_mst_env_cfg[i] = axi4_env_cfg::type_id::create(
                               $sformatf("u_axi_mst_env_cfg_%0d", i));
    u_axi_mst_env_cfg[i].use_slave_with_overlapping_addr           = 0;
    u_axi_mst_env_cfg[i].num_masters                               = NUM_MST;
    u_axi_mst_env_cfg[i].num_slaves                                = 0;
    u_axi_mst_env_cfg[i].slave_is_active                           = 1;
    u_axi_mst_env_cfg[i].u_axi_system_cfg.allow_slaves_with_overlapping_addr = 0;
    u_axi_mst_env_cfg[i].axi4_en                                   = 1;
    u_axi_mst_env_cfg[i].u_axi_system_cfg.awready_watchdog_timeout = 0;
    u_axi_mst_env_cfg[i].u_axi_system_cfg.arready_watchdog_timeout = 0;

    for (int idx = 0; idx < NUM_MST; idx++) begin
        u_axi_mst_env_cfg[i].master_addr_width    [idx] = ADDR_WIDTH;
        u_axi_mst_env_cfg[i].master_data_width    [idx] = DATA_WIDTH;
        u_axi_mst_env_cfg[i].master_id_width      [idx] = ID_WIDTH;
        u_axi_mst_env_cfg[i].ruser_enable         [idx] = 0;
        u_axi_mst_env_cfg[i].aruser_enable        [idx] = 0;
        u_axi_mst_env_cfg[i].awuser_enable        [idx] = 0;
        u_axi_mst_env_cfg[i].max_read_outstanding [idx] = MAX_OSD;
        u_axi_mst_env_cfg[i].max_write_outstanding[idx] = MAX_OSD;
    end

    u_axi_mst_env_cfg[i].clk_freq_mhz  = 1000;
    u_axi_mst_env_cfg[i].enable_perf_mon = 0;
end

foreach (u_axi_mst_env_cfg[i]) begin
    u_axi_mst_env_cfg[i].set_axi_system_cfg();
end
```

---

## Built-in Sequences

| Class | Description |
|-------|-------------|
| `axi4_write_seq` | Single write transaction |
| `axi4_read_seq` | Single read transaction |
| `axi4_rand_seq` | `m_num_txns` randomised read/write bursts |
| `axi4_wrap_seq` | WRAP bursts of lengths 2, 4, 8, 16 |
| `axi4_split_seq` | 32-beat INCR burst (triggers auto-split) |
| `axi4_unaligned_seq` | Unaligned address write with WSTRB masking |

---

## Simulation

```bash
make          # compile + run axi4_base_test
make run TEST=my_test
make clean
```

---

## Protocol Features

- All AXI4 burst types: FIXED, INCR, WRAP
- Automatic burst splitting at 16-beat and 4 KB boundaries
- Unaligned address support with automatic WSTRB calculation
- Data-before-address (W channel before AW channel)
- Outstanding transaction flow control (separate read/write limits)
- Transaction timeout detection (AWREADY / ARREADY watchdogs)
- 12 SVA protocol-compliance assertions in `axi4_if.sv`
- Bandwidth utilisation and latency statistics in `report_phase`
