# AHB protocol contract — AHB-001 (single AHB UVC POC)

**Status:** PROPOSED — written with the M1 sources on 2026-10-31; every open choice is listed in §12 (Q1–Q6) for owner review. Nothing has been compiled or simulated (§11).
**Date:** 2026-10-31
**Task:** AHB-001 (`WORK_STATUS.md`)
**Normative source:** Arm *AMBA AHB Protocol Specification*, ARM IHI 0033C (ID090921, September 2021; AHB5 and AHB-Lite, Manager/Subordinate terminology), referred to below as **[IHI]**. Earlier issues: IHI 0033A (AMBA 3 AHB-Lite) and IHI 0033B (AMBA 5 AHB). The PDF is Arm copyright and is not stored in this repository.

**Citation note (RISK-013):** the PDF was not available to the authoring session and the Arm documentation hosts were blocked by its network policy. Rules are therefore cited by **section title**. Section numbers are given only where they were confirmed (marked ✓): §3.5.2 "Write strobes rules", §3.7 "Waited transfers" with §3.7.1 (transfer type changes) and §3.7.2 (address changes), Chapter 5 "Subordinate Response Signaling" ("ERROR response"), Chapter 7 "Clock and Reset". A reviewer with the PDF must confirm every title, add the numbers and correct any rule below whose wording differs.

## How to read this document

Every rule carries one of three tags. Only **[IHI …]** rules are protocol requirements.

| Tag | Meaning |
|---|---|
| **[IHI "title"]** | Requirement or definition taken from the named section of IHI 0033C |
| **[ASSUMPTION]** | Our proposed default where the specification is silent, or where its wording was not verified; must be approved, may change |
| **[DECISION]** | Project decision already taken by the repository owner (`DECISION_LOG.md`) |

---

## 1. Revision strategy

- **[DECISION D-001]** The AHB UVC follows the APB UVC architecture and rules; APB-specific choices do not carry over.
- **[ASSUMPTION, Q1]** One AHB UVC is usable for **AHB-Lite** (IHI 0033A) and **AHB5** (IHI 0033B/C) Manager interfaces. AHB5 interface properties are per-instance flags; unused ones stay inactive. **AMBA 2 AHB** (IHI 0011A: multiple Managers with HBUSREQ/HGRANT arbitration, SPLIT/RETRY and a 2-bit HRESP) is **out of scope**.
- **[ASSUMPTION, Q2]** Default instance: **AHB5** with 4-bit HPROT and no optional property, which behaves like AHB-Lite.

### Mechanism (implemented)

1. `ahb_if` declares the **AHB-Lite + AHB5 superset** of Manager-interface pins (§2.1). Widths remain SV parameters, so this is not the "maximum-footprint interface" rejected by ADR-001; only feature pins are a superset. Parity check pins (M3) are not declared yet (§2.2).
2. **Feature presence is per-instance runtime configuration** in `ahb_agent_cfg.features` (`ahb_bfm_pkg::ahb_features_t`: revision + property flags), validated against §2.3 before the run phase. The same compiled image can drive an AHB-Lite and an AHB5 bus.
3. The feature set is pushed to both BFMs through the proxies (`configure()` at start of simulation), so the HDL drive/sample code knows which pins are live.
4. Absent **Manager outputs** are driven to 0 (POL-03). The M1 Manager has no optional inputs it depends on (HEXOKAY, HRUSER, HBUSER are M2).

---

## 2. Signal / property legality matrix

### 2.1 Manager-interface signals [IHI "Signal Descriptions": Global, Manager and Multiplexor signals]

Direction is from the Manager's view. HREADY/HRESP/HRDATA are the interconnect multiplexor's outputs; the Subordinate-side HREADYOUT and HSELx belong to the interconnect, not to this UVC.

| Signal | Width | Dir | AHB-Lite | AHB5 | Property | `ahb_agent_cfg` control | Milestone |
|---|---|---|---|---|---|---|---|
| `HCLK` | 1 | in | Y | Y | — | — | M1 |
| `HRESETn` | 1 | in | Y | Y | — | — | M1 |
| `HADDR` | `ADDR_WIDTH` | out | 32 | 10..64 recommended | `ADDR_WIDTH` | — (physical, CFG-03) | M1 |
| `HBURST` | 3 | out | Y | Y | — | — | M1 |
| `HMASTLOCK` | 1 | out | Y | Y | — | per item (`lock`) | M1 |
| `HPROT` | 4, or 7 | out | 4 | 4, or 7 with `Extended_Memory_Types` | `HPROT_WIDTH` 0/4/7 | `ext_mem_types` | M1 |
| `HSIZE` | 3 | out | Y | Y | — | — | M1 |
| `HNONSEC` | 1 | out | N | `Secure_Transfers` | `Secure_Transfers` | `secure_transfers` | M1 |
| `HEXCL` | 1 | out | N | `Exclusive_Transfers` | `Exclusive_Transfers` | `exclusive_transfers` | M2 |
| `HMASTER` | IMPLEMENTATION DEFINED (parameter `MASTER_WIDTH`, default 4 [ASSUMPTION]) | out | N | `Exclusive_Transfers` | — | `exclusive_transfers` | M2 |
| `HTRANS` | 2 | out | Y | Y | — | — | M1 |
| `HWDATA` | `DATA_WIDTH` | out | Y | Y | `DATA_WIDTH` | — (physical, CFG-04) | M1 |
| `HWSTRB` | `DATA_WIDTH/8` | out | N | Issue C `Write_Strobes` | `Write_Strobes` | `write_strobes` | M2 |
| `HWRITE` | 1 | out | Y | Y | — | — | M1 |
| `HAUSER`, `HWUSER` | user widths | out | N | user signaling | user widths | `user_req_width`, `user_data_width` | M2 |
| `HRDATA` | `DATA_WIDTH` | in | Y | Y | `DATA_WIDTH` | — | M1 |
| `HREADY` | 1 | in | Y | Y | — | — | M1 |
| `HRESP` | 1 | in | Y (OKAY/ERROR) | Y | — | — | M1 |
| `HEXOKAY` | 1 | in | N | `Exclusive_Transfers` | — | `exclusive_transfers` | M2 |
| `HRUSER`, `HBUSER` | user widths | in | N | user signaling | user widths | `user_data_width`, `user_resp_width` | M2 |

`HPROT_WIDTH` of 0 (HPROT absent) is not modelled: the Manager always drives HPROT[3:0] (the recommended 0b0011 by default, AHB-R16).

### 2.2 Interface parity protection [IHI Issue C "interface parity protection"] — milestone M3

Issue C adds optional check signals (`Check_Type`, odd parity per byte). Their names, widths and check-enable terms were **not** verified for this POC, so no parity pin is declared in M1 and `ahb_agent_cfg` rejects `check_type != AHB_CHECK_NONE` (CFG-02). M3 starts by copying the pin table from the PDF into this section.

### 2.3 Configuration legality checks (`ahb_agent_cfg::legality_error()` / `validate()`)

`validate()` fails with `uvm_fatal` when any of these is true; `legality_error()` returns the same verdict as text (prefix = the ID) for `ahb_cfg_negative_test`.

| ID | Illegal configuration | Source |
|---|---|---|
| CFG-01 | Any AHB5 interface property (HPROT[6:4], HNONSEC, exclusive, write strobes, user signals, parity) on revision AHB-Lite | [IHI "AHB revisions" / interface properties] |
| CFG-02 | Exclusive transfers, write strobes or user signals (M2), or parity (M3), before their milestone | project milestone limit |
| CFG-03 | `ADDR_WIDTH` outside 1..64, or not 32 on AHB-Lite | [IHI `ADDR_WIDTH` property: 10..64 recommended; fixed at 32 in Issues A and B] ✓ |
| CFG-04 | `DATA_WIDTH` not in {8, 16, 32, 64, 128, 256, 512, 1024} | [IHI `DATA_WIDTH` property] ✓ |
| CFG-05 | Bus wider than the transaction maxima (`AHB_MAX_*_WIDTH`) | physical consistency; `uvm_fatal` in the adapter constructors |
| CFG-06 | Drive and observe adapters bound to different widths (cross-wiring) | ADR-001 §4 |

Recommended-only limits are warnings (POL-06): `ADDR_WIDTH` below 10 on AHB5, `DATA_WIDTH` outside 32..256 [IHI properties ✓].

---

## 3. Parameters and widths

| Parameter (HDL) | Legal range | Source |
|---|---|---|
| `ADDR_WIDTH` | 1..64 in `ahb_if`; 32 for AHB-Lite (CFG-03) | [IHI `ADDR_WIDTH`] ✓; 64 is also the width of the shared address arithmetic (`AHB_FN_AW`) |
| `DATA_WIDTH` | 8, 16, 32, 64, 128, 256, 512, 1024 | [IHI `DATA_WIDTH`] ✓; POC pair 32 + 64 (ADR-001) |
| `MASTER_WIDTH` | ≥ 1 physical; used from M2 | [ASSUMPTION] default 4 |
| `USER_REQ_WIDTH`, `USER_DATA_WIDTH`, `USER_RESP_WIDTH` | ≥ 1 physical (presence via cfg; 0 = absent) | [IHI "User Signaling"]; M2 |
| `QUEUE_DEPTH` (monitor BFM) | ≥ 1, default 16 | UVC capacity |

---

## 4. Transfer rules for the driver BFM and the monitor checks

These IDs are the traceability keys for checks, coverage and tests.

| ID | Rule | Source |
|---|---|---|
| AHB-R01 | All signals are timed against the rising edge of `HCLK` | [IHI "Clock and Reset"] ✓ (Ch. 7) |
| AHB-R02 | A transfer has an address phase and a data phase. The address phase of the next transfer overlaps the data phase of the current one; at an `HCLK` edge with `HREADY` HIGH the data phase in progress completes and the address phase on the bus is accepted | [IHI "Basic transfers"] |
| AHB-R03 | `HTRANS` IDLE: no data transfer; a Subordinate gives a zero-wait-state OKAY response | [IHI "Transfer types"] |
| AHB-R04 | `HTRANS` BUSY: inserted by the Manager inside a burst, never after a SINGLE; address and control show the next transfer; a Subordinate gives a zero-wait-state OKAY. A fixed-length burst does not end with BUSY; an undefined-length INCR may | [IHI "Transfer types", "Burst termination after a BUSY transfer"] |
| AHB-R05 | NONSEQ starts a single transfer or a burst; SEQ continues it at the previous address plus the transfer size (incrementing) or wrapped (wrapping). Control (`HWRITE`, `HSIZE`, `HBURST`, `HPROT`, `HNONSEC`, `HMASTLOCK`) is identical in every beat | [IHI "Transfer types", "Burst operation"] |
| AHB-R06 | `HSIZE` is not larger than the data bus width | [IHI "Transfer size"] |
| AHB-R07 | `HADDR` is aligned to the transfer size | [IHI "Transfer size", "Burst operation"] |
| AHB-R08 | An incrementing burst does not cross a 1KB address boundary | [IHI "Burst operation"] |
| AHB-R09 | Fixed-length bursts have 4, 8 or 16 beats; a wrapping burst wraps at a boundary of beats × size bytes | [IHI "Burst operation"] |
| AHB-R10 | A fixed-length burst ends before its last beat only after an ERROR response (Manager view of a single-Manager interface) | [IHI "Early burst termination"]; wording [ASSUMPTION] until checked against the PDF |
| AHB-R11 | While `HREADY` is LOW, the Manager keeps a NONSEQ/SEQ address phase (address and control) unchanged. Permitted changes: IDLE to NONSEQ; BUSY to SEQ (fixed-length bursts) or to any type (undefined-length INCR); after the first ERROR cycle the Manager may change the address phase to IDLE | [IHI §3.7 "Waited transfers", §3.7.1, §3.7.2] ✓ |
| AHB-R12 | Write data is driven in the data phase and held stable until `HREADY` is HIGH | [IHI "Basic transfers", "Waited transfers"] |
| AHB-R13 | Read data is valid in the last cycle of the data phase (`HREADY` HIGH) | [IHI "Basic transfers"] |
| AHB-R14 | ERROR is a two-cycle response: `HRESP` HIGH with `HREADY` LOW, then `HRESP` HIGH with `HREADY` HIGH | [IHI Ch. 5 "ERROR response"] ✓ |
| AHB-R15 | After an ERROR the Manager may cancel the remaining beats of the burst (IDLE) or continue them | [IHI Ch. 5 "ERROR response", "Early burst termination"] |
| AHB-R16 | `HPROT[0]` data/opcode, `[1]` privileged, `[2]` bufferable, `[3]` cacheable/modifiable; `[6:4]` exist only with `Extended_Memory_Types`. A Manager that does not generate protection information is recommended to drive 0b0011 | [IHI "Protection control", "Memory types"]; HPROT width 0/4/7 ✓ |
| AHB-R17 | `HNONSEC` marks a transfer non-secure; present only with `Secure_Transfers`; constant in a burst | [IHI "Secure transfers"] |
| AHB-R18 | `HMASTLOCK` marks a locked sequence; an IDLE after the final locked transfer is recommended | [IHI "Locked transfers"] |
| AHB-R19 | `HRESETn` is active LOW. During reset the Manager drives valid address and control with `HTRANS` IDLE | [IHI Ch. 7 "Reset"] ✓ chapter; exact wording [ASSUMPTION] |
| AHB-R20 | The active byte lanes of a transfer follow from `HADDR` and `HSIZE`. The UVC uses the little-endian / byte-invariant lane mapping (lane = address modulo bus bytes); word-invariant big-endian (BE32) is not supported | [IHI "Data buses", "Endianness"] |
| AHB-R21 | `DATA_WIDTH` 8..1024 (32..256 recommended); `ADDR_WIDTH` 10..64 recommended | [IHI properties] ✓ |
| AHB-R22 | `HTRANS` and `HREADY` are never X/Z outside reset | [ASSUMPTION], by analogy with APB IHI 0024D A.1 |

### UVC policies built on top of the rules [ASSUMPTION]

| ID | Policy | Default |
|---|---|---|
| POL-01 | Watchdog: `cfg.max_wait_cycles` consecutive `HREADY` LOW cycles end the item with status `TIMEOUT` and `uvm_error`; 0 disables | 1024 |
| POL-02 | After an ERROR the driver cancels the remaining beats of the burst (IDLE in the second ERROR cycle) | cancel |
| POL-03 | Manager outputs that carry no transfer — IDLE address/control, `HWDATA` outside a write data phase, absent AHB5 outputs — are driven to 0 | zero |
| POL-04 | One item is one burst; INCR items have 1..`AHB_MAX_BEATS` (16) beats. The monitor reports longer INCR bursts of other Managers as `AHB_MON_ERR_CAPACITY` | 16 |
| POL-05 | No cross-item pipelining: the next item's NONSEQ is driven at the edge where the previous item's last data phase completed, so one IDLE address phase separates items | — |
| POL-06 | Recommended-only limits (`DATA_WIDTH` outside 32..256, `ADDR_WIDTH` below 10) are warnings, never errors | warning |

---

## 5. Reset semantics

The AHB specification states that `HRESETn` is the active-LOW bus reset and that Managers drive `HTRANS` IDLE during reset (AHB-R19). **Everything below is [ASSUMPTION] for review**, aligned with the APB contract's RST rules.

| ID | Behaviour |
|---|---|
| RST-1 | While `HRESETn`=0 the driver BFM drives `HTRANS`=IDLE and every other Manager output to 0 |
| RST-2 | Reset assertion is recognised immediately (asynchronously); deassertion at the first `HCLK` rising edge that samples `HRESETn`=1 |
| RST-3 | A burst in flight when reset asserts is abandoned. The item completes with status `RESET_ABORTED` and is not retried |
| RST-4 | The monitor discards a partially observed burst: nothing is published. Reset assertion and release after the first release are reported as separate observe-API events (`ahb_reset_event`, `ahb_monitor.reset_ap`) |
| RST-5 | The first NONSEQ after reset is no earlier than `cfg.post_reset_idle_cycles` (default 1) edges after the release |
| RST-6 | Protocol and X/Z checks are inactive while `HRESETn`=0; they start at the first reset deassertion |
| RST-7 | X/Z on `HRESETn` after the first reset deassertion is an error |

---

## 6. Transaction representation (HVL, not width-parameterized)

`ahb_transaction` extends `uvm_sequence_item`. One object is **one burst**; one class serves every instance width.

| Field | Type | Notes |
|---|---|---|
| `dir` | `ahb_dir_e` {`AHB_READ`, `AHB_WRITE`} | `HWRITE` |
| `addr` | `logic [AHB_MAX_AW-1:0]` | address of the NONSEQ |
| `burst`, `size` | `ahb_burst_e`, `ahb_size_e` | `HBURST`, `HSIZE` encodings (`ahb_bfm_pkg`) |
| `len` | `int unsigned` | beats: 1 (SINGLE), 4/8/16 (fixed), 1..16 (INCR, POL-04) |
| `wdata[]` | `logic [AHB_MAX_DW-1:0]` per beat | whole bus word, lanes as on `HWDATA` (AHB-R20) |
| `busy[]` | `int unsigned` per beat | BUSY phases before the beat; `busy[0]` is 0 (AHB-R04) |
| `prot`, `nonsec`, `lock` | `logic [6:0]`, `logic`, `logic` | `HPROT`, `HNONSEC`, `HMASTLOCK` |
| `idle_cycles` | `int unsigned` | IDLE address phases before the NONSEQ |
| `beat_addr[]`, `rdata[]`, `resp[]`, `wait_states[]` | per beat | filled by the driver (as driven) or the monitor (as observed); 4-state |
| `beats_done` | `int unsigned` | data phases completed (fewer than `len` after an ERROR cancel or a reset) |
| `status` | `ahb_bfm_status_e` | one encoding shared with the BFM: `OK`, `ERROR`, `RESET_ABORTED`, `TIMEOUT`, `NOT_ENABLED`, `BAD_REQUEST`, `FAULT_INJECTED` |
| `start_cycle`, `end_cycle` | `longint unsigned` | monitor only: sample of the NONSEQ acceptance and of the last completion |
| bus context | `bus_addr_width`, `bus_data_width`, `bus_max_size`, `bus_ext_mem`, `bus_secure`, over-width masks | set by `ahb_base_seq::new_item()` before randomization and by the adapters; constraints keep values legal for that bus (size, alignment, 1KB page) |
| `instance_name` | `string` | adapter that drove or observed the item |

### Lossless and 4-state rules

- **No silent narrowing.** The drive adapter checks that every bit at or above the bound bus width (`addr`, every `wdata` beat) is 0, and that size, alignment, length and 1KB page are legal; otherwise `uvm_error`, status `BAD_REQUEST`, nothing on the bus.
- **No sign extension.** Payload fields are unsigned `logic` vectors; the observe adapter zero-extends.
- **4-state preserved.** The monitor captures X/Z verbatim; nothing is converted to `bit`.
- **Driver input check.** X/Z in `addr`, `prot`, `nonsec` or `lock` is an error; X/Z in write data only with `cfg.allow_x_wdata` (fault injection).
- The maxima (`AHB_MAX_ADDR_WIDTH` 32, `AHB_MAX_DATA_WIDTH` 64 by default) are one compile-time choice per simulation image (`hvl/types/ahb_defines.svh`).

---

## 7. Monitor transport (RISK-002) [ASSUMPTION; implemented in `ahb_monitor_bfm_if`]

- The monitor BFM samples through a clocking block (`@(posedge HCLK)`, input skew `#1step`) and reconstructs bursts in an always-running HDL process, independent of HVL timing.
- At each sample it handles, in order: reset; HTRANS/HREADY validity; the waited-transfer rule against the previous sample; the data phase in progress (wait cycle, first ERROR cycle or completion); and, when `HREADY` is HIGH, the address phase accepted at that edge.
- A burst is **published once**, when it ends: at the edge where the next IDLE or NONSEQ is accepted. Without a trailing BUSY this is the edge where its last data phase completes. Bursts go into a bounded HDL queue of plain values (no UVM objects, ADR-002 §6); overflow is reported.
- Reset edges after the first release go into a second bounded queue (RST-4).
- The HVL observe adapter calls the blocking tasks `get_burst(…)` and `get_reset_event(…)`; `ahb_monitor` runs one loop for each and publishes on `ap` and `reset_ap`.
- **Wake-up rule:** a publish pushes the entry and triggers a named event (`obs_ev`, `rst_ev`); the getters run `while (queue empty) @(event);`, so a publish earlier in the same time step is never missed.
- The monitor works whether or not a driver BFM is enabled, because it only reads pins (instance P).
- Not compiled or simulated (§11).

## 8. Driver BFM behaviour [ASSUMPTION; implemented in `ahb_driver_bfm_if`]

- `do_burst()` drives on the `HCLK` rising edge with NBAs. After `idle_cycles` IDLE phases it drives the NONSEQ; at every edge with `HREADY` HIGH the data phase in progress completes (read data and `HRESP` sampled through the clocking block) and the address phase on the bus is accepted, upon which the next beat's SEQ — or BUSY phases first, or IDLE after the last beat — is driven, and the accepted beat's write data is presented for its data phase (AHB-R02/R04/R12).
- While `HREADY` is LOW nothing changes (AHB-R11), except: in the first ERROR cycle the pending address phase is replaced by IDLE, which cancels the remaining beats (AHB-R14/R15, POL-02).
- Returns at the edge where the last data phase completes, after scheduling IDLE; the next call with `idle_cycles == 0` overrides it in the same time step with its NONSEQ (POL-05).
- **Drive release:** when the driver BFM is not enabled its outputs are `'z` and `ahb_if` uses resolved nets, so a passive instance cannot contend (instance P exists to prove it). Unverified until a 4-state simulator run (RISK-009).
- **Reset during a burst:** the burst and a reset watcher run under `fork…join_any` inside an outer `fork…join` (LANG-08); the burst is abandoned at the reset edge with `RESET_ABORTED` (RST-2/RST-3), and an `always @(HRESETn)` block idles the outputs as soon as reset asserts (RST-1).
- **Fault modes** (negative tests): change `HADDR` of a waited SEQ (`AHB_FAULT_ADDR_UNSTABLE` → `AHB_MON_ERR_UNSTABLE_IN_WAIT`), second beat at a wrong address (`AHB_FAULT_BAD_SEQ_ADDR` → `AHB_MON_ERR_BURST_ADDR`), IDLE after two beats of a fixed-length burst (`AHB_FAULT_EARLY_TERMINATION` → `AHB_MON_ERR_BURST_LENGTH`).

---

## 9. Package and compile dependencies

```text
HDL compilation units (no UVM):
  hdl/ahb_bfm_pkg.sv   types + pure functions: revision, HTRANS/HBURST/HSIZE, features,
                       status, fault and monitor-error enums, burst address arithmetic
    └─> hdl/ahb_if.sv   hdl/ahb_driver_bfm_if.sv   hdl/ahb_monitor_bfm_if.sv
        ^ ordinary signal ports wired in examples/ahb_hdl_top.sv (ADR-002 §7)

HVL packages:
  uvm_pkg, ahb_bfm_pkg
    └─> ahb_api_pkg       (hvl/types, hvl/api: transaction, reset event, proxy bases)
          ├─> ahb_uvc_pkg      (hvl/config, hvl/agent, hvl/sequences, hvl/coverage)
          └─> ahb_adapter_pkg  (hvl/adapter: width-specialized proxies; names the
                                BFM interface types via virtual interface handles)

Integration (examples/):
  ahb_hdl_top  : ahb_if + both BFMs per instance (A, B), passive BFM pair P on bus A,
                 ahb_example_slave per bus
  ahb_hvl_top  : imports uvm_pkg, ahb_api_pkg, ahb_uvc_pkg, ahb_adapter_pkg, ahb_poc_test_pkg;
                 constructs adapters, fills one ahb_agent_cfg per instance,
                 uvm_config_db::set once, registers the test reset helper, run_test()
```

Compile order: `ahb_bfm_pkg` → HDL interfaces → `uvm_pkg` → `ahb_api_pkg` → `ahb_uvc_pkg` → `ahb_adapter_pkg` → examples/tests. `ahb_uvc_pkg` must not import `ahb_adapter_pkg`; nothing in the core imports example or test code.

## 10. File manifest and milestone split

| Step (`CLAUDE_GENERATION_PROMPT.md`) | Files | Status |
|---|---|---|
| 2 HDL | `hdl/ahb_bfm_pkg.sv`, `hdl/ahb_if.sv`, `hdl/ahb_driver_bfm_if.sv`, `hdl/ahb_monitor_bfm_if.sv`, `examples/ahb_example_slave.sv`, `examples/ahb_hdl_top.sv`, `tests/ahb_hdl_smoke.sv`, `filelists/ahb_hdl.f`, `filelists/ahb_hdl_smoke.f`, `scripts/{slang_elab.py,make_eda_bundle.py}`, `README.md` | **written; compile NOT RUN** |
| 3 HVL API | `hvl/types/ahb_defines.svh`, `hvl/types/ahb_transaction.sv`, `hvl/types/ahb_reset_event.sv`, `hvl/api/ahb_drive_proxy_base.sv`, `hvl/api/ahb_monitor_proxy_base.sv`, `hvl/pkg/ahb_api_pkg.sv` | **written; compile NOT RUN** |
| 4 HVL concrete | `hvl/adapter/ahb_drive_proxy.sv`, `hvl/adapter/ahb_monitor_proxy.sv`, `hvl/pkg/ahb_adapter_pkg.sv` | **written; compile NOT RUN** |
| 5 UVM | `hvl/config/ahb_agent_cfg.sv`, `hvl/agent/{ahb_driver,ahb_monitor,ahb_sequencer,ahb_agent}.sv`, `hvl/sequences/{ahb_base_seq,ahb_random_seq}.sv`, `hvl/coverage/ahb_coverage.sv`, `hvl/pkg/ahb_uvc_pkg.sv`, `filelists/{ahb_hvl,ahb_poc}.f`, `examples/ahb_hvl_top.sv` | **written; compile NOT RUN** |
| 6 Tests | `tests/ahb_poc_test_pkg.sv` with `ahb_poc_scoreboard.sv`, `ahb_poc_env.sv`, `ahb_poc_seqs.sv`, `ahb_fake_proxies.sv`, `ahb_poc_reset_ctrl.sv`, `ahb_poc_test.sv`, `ahb_fault_injection_test.sv`, `ahb_negative_tests.sv`, `ahb_passive_reset_tests.sv` | **written; NOT RUN** |
| later M2 | same files | exclusive transfers (HEXCL/HMASTER/HEXOKAY + monitor model), write strobes (HWSTRB, IHI §3.5.2 ✓), user signals |
| later M3 | same files + `assertions/` | interface parity generation/checking + parity fault injection |

`hdl/ahb_bfm_pkg.sv` holds the enums and the burst arithmetic because they must be shared by the HDL BFMs **and** the HVL classes (`ahb_transaction`, scoreboard); it is a types-and-pure-functions package with no UVM, no classes and no timing.

## 11. Smallest runnable task and acceptance test

**AHB-003a (step 2):** the HDL files of the step 2 row, with instances A, B and P in `ahb_hdl_top`, exercised by `tests/ahb_hdl_smoke.sv`.

Acceptance (all **NOT RUN** — no tool approved, D-003):
1. Elaboration of `ahb_hdl_smoke` (A, B, P): **0 errors** (log stored with SHA).
2. HDL-only directed smoke on a simulator: per instance, the 20 directed bursts (SINGLE with 0/2 wait states, INCR4 with and without waited SEQ beats, WRAP4, INCR with BUSY, narrow byte write, back-to-back, SINGLE ERROR, INCR4 into ERROR with cancel, read-back). Driver results, read data and every published burst must match, the burst count must be exact, and A, B and P must report no protocol error.
3. Negative controls: `+AHB_FAULT=1|2|3` must each be detected on A (and P) with the matching error code, with B clean.

Then **AHB-004:** elaborate `filelists/ahb_poc.f` with a UVM library, then run the six UVM tests of `WORK_STATUS.md` *Tests available*.

---

## 12. Open questions (need owner decision)

| ID | Question | Recommendation (implemented as default) |
|---|---|---|
| Q1 | Revision scope: AHB-Lite + AHB5 only, or also AMBA 2 multi-manager AHB (arbitration, SPLIT/RETRY)? | AHB-Lite + AHB5; AMBA 2 would need a different Manager model (bus request/grant) |
| Q2 | Default instance | AHB5, 4-bit HPROT, no optional property |
| Q3 | Width pair | DW=32 + DW=64 (both standard), AW=32 |
| Q4 | Milestone split | M1 as implemented; M2 exclusive/write strobes/user; M3 parity |
| Q5 | Approve the reset assumptions RST-1..7 and policies POL-01..06 | — |
| Q6 | Item granularity: one burst per item without cross-item pipelining (POL-05), INCR ≤ 16 beats (POL-04) | Keep for M1; pipelining items into each other needs early `item_done` with response events (M2 candidate) |
| Q7 | Tool approval for this repository (T1/T3/T4 in `WORK_STATUS.md`) | Approve T1 (slang elaboration) and T3 (UVM 1.2) as for APB, then the owner runs T4 on EDA Playground |
