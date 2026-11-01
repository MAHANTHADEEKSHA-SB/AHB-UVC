# AHB UVC (proof of concept)

One reusable AHB Manager (master) UVC. Two instances of the same source — **AW=32/DW=32** and **AW=32/DW=64** — run side by side to show width independence (both widths are legal in ARM IHI 0033C, so no non-standard extension is needed; ADR-001 decision 3). A third, **passive** instance P observes bus A with a monitor BFM and a driver BFM that is never enabled.

**Status:** milestone M1 sources for HDL, HVL API, adapters, UVM agent, HVL top and tests are written as **portable IEEE 1800-2017 SystemVerilog/UVM with no tool-specific code paths**. **Nothing has been compiled, elaborated or simulated** (no tool is approved for this repository yet — see `../../docs/dv-architecture/WORK_STATUS.md`, which also lists the known gaps).

Governing documents: `../../docs/dv-architecture/` — `DECISION_LOG.md` (owner decisions), `CODING_GUIDELINES.md` (mandatory coding standard), `AHB_PROTOCOL_CONTRACT.md` (pins, rules, reset, transaction), `ARCHITECTURE_CONTRACT.md`, ADR-001, ADR-002, `WORK_STATUS.md`. They were adapted from the `apb_uvc` repository (`feature/apb-005-passive-reset-apb3-tests`, commit `b406d6a`).

## Supported protocol

Specification: Arm *AMBA AHB Protocol Specification*, ARM IHI 0033C (AHB5 and AHB-Lite).

| Revision / property | Status in M1 |
|---|---|
| AHB-Lite (IHI 0033A), single Manager | Implemented: SINGLE, INCR, INCR4/8/16, WRAP4/8/16, BUSY, wait states, two-cycle ERROR, HPROT[3:0], HMASTLOCK |
| AHB5 (default) | Implemented as AHB-Lite plus `Extended_Memory_Types` (HPROT[6:4]) and `Secure_Transfers` (HNONSEC) |
| AHB5 exclusive transfers, write strobes, user signals | Pins present, driven 0; milestone M2. `configure()` and `ahb_agent_cfg` reject them |
| AHB5 interface parity | Milestone M3; pins not declared yet (pin list to be verified against the PDF) |
| AMBA 2 AHB multi-manager (HBUSREQ/HGRANT, SPLIT/RETRY) | Out of scope (`AHB_PROTOCOL_CONTRACT.md` Q1) |

Revision and properties are **per-instance runtime configuration** (`ahb_agent_cfg.features`, type `ahb_bfm_pkg::ahb_features_t`). An absent property costs nothing: its Manager outputs are driven to 0.

M1 limits (policies, `AHB_PROTOCOL_CONTRACT.md` §4): one burst per item, INCR items up to 16 beats (POL-04); the remaining beats of a burst are cancelled after an ERROR (POL-02); the next item's NONSEQ follows the previous item's last data phase, so consecutive items are not pipelined into each other (POL-05).

## Layout

```text
hdl/ahb_bfm_pkg.sv              types + burst address arithmetic shared by BFMs and adapters
hdl/ahb_if.sv                   Manager-interface pins (AHB-Lite + AHB5 superset) + modports
hdl/ahb_driver_bfm_if.sv        Manager drive BFM; pipelined bursts; outputs 'z until set_enable(1)
hdl/ahb_monitor_bfm_if.sv       passive monitor BFM; burst reconstruction; protocol checks
hvl/types/ahb_defines.svh       transaction maxima (AW 32, DW 64 by default)
hvl/types/ahb_transaction.sv    one burst, every width (4-state)
hvl/types/ahb_reset_event.sv    reset edge published by the monitor (RST-4)
hvl/api/ahb_*_proxy_base.sv     abstract drive / observe capabilities
hvl/adapter/ahb_*_proxy.sv      width-specialized adapters with typed virtual BFM handles
hvl/config/ahb_agent_cfg.sv     per-instance configuration + legality checks
hvl/agent/                      ahb_sequencer, ahb_driver, ahb_monitor, ahb_agent
hvl/coverage/ahb_coverage.sv    protocol coverage
hvl/sequences/                  ahb_base_seq (helpers), ahb_random_seq
hvl/pkg/                        ahb_api_pkg, ahb_uvc_pkg, ahb_adapter_pkg
examples/ahb_example_slave.sv   small AHB Subordinate (test fixture only)
examples/ahb_hdl_top.sv         instances A (DW=32), B (DW=64), passive P on bus A
examples/ahb_hvl_top.sv         binds adapters, registers one cfg per instance, run_test
tests/ahb_hdl_smoke.sv          HDL-only smoke (no UVM)
tests/ahb_poc_test_pkg.sv       UVM POC env, fixture scoreboard and tests
filelists/ahb_hdl.f             reusable HDL core
filelists/ahb_hvl.f             reusable HVL core
filelists/ahb_hdl_smoke.f       HDL core + example + HDL smoke
filelists/ahb_poc.f             everything for the UVM POC
scripts/slang_elab.py           slang elaboration wrapper (proposed check, needs approval)
scripts/make_eda_bundle.py      single-file bundle for EDA Playground (plain text, no tool)
```

Filelists use paths relative to the filelist, so pass them with **`-F`**, not `-f`. Compile order is HDL core, then the simulator's `uvm_pkg`, then `ahb_api_pkg`, `ahb_uvc_pkg`, `ahb_adapter_pkg`.

**Reusable core** = `hdl/` + `hvl/` (`ahb_hdl.f` + `ahb_hvl.f`). `examples/` and `tests/` show integration and are not needed by a consumer.

## Reading the code

Read in dependency order; every file starts with a header, and every task, function and process has a comment naming the contract rule it implements (`CODING_GUIDELINES.md` FMT-09).

1. `hdl/ahb_bfm_pkg.sv` — enums (revision, HTRANS/HBURST/HSIZE, status, faults, monitor errors) and `ahb_next_addr()`.
2. `hdl/ahb_if.sv` — the Manager-side pins and width legality.
3. `hdl/ahb_driver_bfm_if.sv` — `do_burst()`: the address/data pipeline, BUSY, wait states, ERROR cancel, reset abort, fault modes.
4. `hdl/ahb_monitor_bfm_if.sv` — `sample_cycle()`: the checks, burst reconstruction and the single publication per burst; `get_burst()`, `get_reset_event()`.
5. `hvl/types/ahb_transaction.sv`, then `hvl/api/*_base.sv` — the width-independent item and the two capabilities.
6. `hvl/adapter/*.sv` — the only width-specialized classes: request checks and conversion to and from the bus width.
7. `hvl/config/ahb_agent_cfg.sv`, then `hvl/agent/*.sv` — configuration legality, then agent, driver, monitor and sequencer.
8. `examples/ahb_hdl_top.sv` and `examples/ahb_hvl_top.sv` — how the two layers are wired and bound per instance.
9. `tests/` — the HDL smoke, then `ahb_poc_test_pkg.sv` and the tests it includes.

The two data paths:

```text
drive:   sequence -> ahb_sequencer -> ahb_driver -> ahb_drive_proxy_base (cfg.drive)
         -> ahb_drive_proxy #(AW,DW) -> ahb_driver_bfm_if.do_burst() -> ahb_if pins
observe: ahb_if pins -> ahb_monitor_bfm_if.sample_cycle() -> queues -> get_burst() / get_reset_event()
         -> ahb_monitor_proxy #(AW,DW).receive() / wait_reset_event() -> ahb_monitor
         -> ap (bursts) / reset_ap (reset edges) -> coverage / scoreboard
```

## Integrating the UVC

**HDL, per instance:** one `ahb_if`, one `ahb_driver_bfm_if` and one `ahb_monitor_bfm_if` with the **same parameters**. Connect both BFMs to that `ahb_if` instance's nets through their ordinary signal ports (ADR-002 decision 7); `examples/ahb_hdl_top.sv` is the template. The interconnect (decoder, multiplexor, Subordinates) drives `HREADY`, `HRESP` and `HRDATA` of the Manager interface. `ahb_if` rejects `DATA_WIDTH` outside {8, 16, …, 1024} and `ADDR_WIDTH` outside 1..64.

**HVL, per instance** (`examples/ahb_hvl_top.sv` is the template):

```systemverilog
ahb_drive_proxy   #(.ADDR_WIDTH(32), .DATA_WIDTH(64)) drv;
ahb_monitor_proxy #(.ADDR_WIDTH(32), .DATA_WIDTH(64)) mon;
ahb_agent_cfg                                         cfg;

drv = new("drive_b",   ahb_hdl_top.drv_b);   // typed handle to THIS instance's BFMs
mon = new("observe_b", ahb_hdl_top.mon_b);
cfg = ahb_agent_cfg::type_id::create("cfg_b");
cfg.drive   = drv;            // omit for a passive agent (cfg.is_active = UVM_PASSIVE)
cfg.observe = mon;
// cfg.features.revision = AHB_LITE; cfg.features.secure_transfers = 1; ...  (default: AHB5)
uvm_config_db#(ahb_agent_cfg)::set(null, "uvm_test_top.env.agent_b", "cfg", cfg);
```

The agent, driver, monitor, sequencer and sequences are **not** width-parameterized; the same classes serve every instance. Sequences derived from `ahb_base_seq` get the bus context automatically (`new_item()`), so random bursts always fit the instance (aligned, no wider than the bus, inside one 1KB page). The drive adapter rejects anything that would not fit (no silent truncation).

### BFM API (used by the adapters)

| BFM | Call | Purpose |
|---|---|---|
| driver | `configure(ahb_features_t)` → bit | set revision/properties; 0 = rejected |
| driver | `set_enable(bit)` | 0 releases every output to `'z` (passive instance) |
| driver | `wait_for_reset_release(idle_cycles)` | RST-5 |
| driver | `do_burst(...)` | one burst; returns per-beat addresses, read data, HRESP, wait cycles, beats done, `ahb_bfm_status_e` |
| driver | `set_fault(ahb_fault_e)` | deliberate protocol faults for negative tests |
| monitor | `configure(ahb_features_t)` → bit | same feature set as the driver |
| monitor | `set_publish(bit)` | enable the burst and reset-event queues |
| monitor | `get_burst(...)` | blocking; next completed burst |
| monitor | `get_reset_event(...)` | blocking; next reset edge after the first release (RST-4) |
| monitor | `get_error_count(code)` / `get_total_errors()` | protocol violations by `ahb_mon_error_e` |

## Running

Inside this repository's AI workflow, no simulator, compiler, elaborator or lint tool may be run without explicit owner approval of the tool, version and commands (ARCHITECTURE_CONTRACT toolchain gate). The commands below are for the owner.

| Flow | Filelist | Top(s) | Options | Pass line |
|---|---|---|---|---|
| HDL smoke | `ahb_hdl_smoke.f` | `ahb_hdl_smoke` | `+AHB_FAULT=1\|2\|3` for negatives | `SMOKE_RESULT: PASS` |
| UVM POC | `ahb_poc.f` + UVM library | `ahb_hdl_top ahb_hvl_top` | `+UVM_TESTNAME=ahb_poc_test` | `TEST_RESULT: PASS (0 errors)` |
| UVM fault injection | same | same | `+UVM_TESTNAME=ahb_fault_injection_test +AHB_FAULT=1\|2\|3` | `TEST_RESULT: PASS` |
| UVM cfg legality | same | same | `+UVM_TESTNAME=ahb_cfg_negative_test` | `TEST_RESULT: PASS` |
| UVM width boundary | same | same | `+UVM_TESTNAME=ahb_width_negative_test` | `TEST_RESULT: PASS` |
| UVM passive agent | same | same | `+UVM_TESTNAME=ahb_passive_test` | `TEST_RESULT: PASS` |
| UVM reset mid-burst | same | same | `+UVM_TESTNAME=ahb_reset_test` | `TEST_RESULT: PASS` |

Language features the sources rely on: 4-state nets with `'z` release on interface nets, clocking blocks with `#1step` input skew, `fork…join_any` with `disable fork` in interface tasks, named events, queues of unpacked structs, fixed-size unpacked arrays as task arguments, parameterized classes holding parameterized virtual-interface types, embedded covergroups, a class declared in a module that calls a task through a hierarchical reference (test helper only), and UVM 1.2 or IEEE 1800.2.

### EDA Playground (commercial simulators)

```sh
python3 -I scripts/make_eda_bundle.py filelists/ahb_hdl_smoke.f ahb_hdl_smoke_bundle.sv   # HDL smoke
python3 -I scripts/make_eda_bundle.py filelists/ahb_poc.f       ahb_poc_bundle.sv         # UVM POC
```

The bundle inlines every project `include`, so no include path is needed; `uvm_macros.svh` comes from the simulator's UVM library. Paste the file into the *testbench.sv* pane, leave *design.sv* empty, pick a SystemVerilog simulator (for the UVM bundle also select a UVM library), set the top(s) from the table above and add the run options.

## Portability policy

The sources contain **no tool-specific code paths, pragmas or workarounds** (owner rule inherited from the APB POC, `DECISION_LOG.md` D-002). A simulator that cannot handle the standard constructs above is recorded as a tool limitation in `../../docs/dv-architecture/REVIEW_FEEDBACK.md`; the code is not bent to fit it.
