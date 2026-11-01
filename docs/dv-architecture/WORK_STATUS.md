# WORK_STATUS — single AHB UVC handoff checkpoint

**Checkpoint date:** 2026-11-01 (end of the first AHB session, after the owner merged PR #7; resume in a new session from *Resume here* — `SESSION_SUMMARY.md` has the one-page overview and a new-chat start prompt)
**Repository:** https://github.com/MAHANTHADEEKSHA-SB/AHB-UVC
**Branch:** the M1 work is on **`dev` at `6a84aa297a23cf26d61c92fe0ff96a99f632636e`**, the merge of [PR #7](https://github.com/MAHANTHADEEKSHA-SB/AHB-UVC/pull/7) from `claude/festive-goodall-33kr39` (commits `63ac0d4`..`634faaf`, created from `dev` = `main` at `ed51c95`; D-008, D-009). `main` is still at `ed51c95`. This status update was made on `claude/festive-goodall-33kr39`, restarted from `dev`. New work starts on a feature branch from `dev` (GIT-01).
**Template source:** `https://github.com/MAHANTHADEEKSHA-SB/apb_uvc`, branch `feature/apb-005-passive-reset-apb3-tests` at `b406d6a9c75aca158671f304257ce9a5ba346710` (same commit as its `dev`)
**Current commit SHA:** read actual `git rev-parse HEAD`; this file cannot self-reference its own commit.
**Working tree:** UNKNOWN for local clones; verify before changing code.
**Phase:** governance docs adapted from APB; M1 sources for steps 2–6 **written and commented** (HDL, HVL API, adapters, UVM agent, HVL top, HDL smoke, UVM tests) as portable IEEE 1800-2017 SystemVerilog/UVM following `CODING_GUIDELINES.md`. **Nothing compiled, elaborated or simulated: no tool is approved for this repository (D-003).**
**Tool results:** none. Text-only checks (grep/awk) only; see *Static self-review done*.
**Next implementer:** Claude or another authorized model/engineer.
**Active task:** none in progress. Next: owner review of `AHB_PROTOCOL_CONTRACT.md` Q1–Q7 and a decision on the toolchain approval request below (merging PR #7 confirmed neither, D-009).
**Spec reference:** Arm AMBA AHB Protocol Specification, ARM IHI 0033C (ID090921, September 2021). The PDF is Arm copyright and is not committed here; citations are by section title (RISK-013).

> Do not trust this status without comparing it to the real files, current Git SHA, and logs. Any difference must be reconciled explicitly.

## Resume here (new session, other model or engineer)

1. `git fetch origin && git switch dev && git pull --ff-only && git status --short && git log --oneline -12`. Compare HEAD with this file (`6a84aa2` or later). Create the task branch from `dev` (`git switch -c feature/ahb-<id>-<short-description>`) unless the session designates a branch. Then set the commit identity to the owner before any commit (D-007, GIT-07): `git config user.name "Mahantha Deeksha S B" && git config user.email "$(git log origin/dev --author='Mahantha Deeksha S B' --format='%ae' -1)"`.
2. Read in order: `SESSION_SUMMARY.md` (orientation) → `AGENTS.md` (root) → `docs/dv-architecture/AGENTS.md` → **`DECISION_LOG.md`** → **`CODING_GUIDELINES.md`** (mandatory standard + pre-commit checklist) → `ARCHITECTURE_CONTRACT.md` → ADR-001 → ADR-002 → `AHB_PROTOCOL_CONTRACT.md` → this file → `REVIEW_FEEDBACK.md` → `poc/ahb_uvc/README.md`.
3. **Owner rules in force** (full list and sources in `DECISION_LOG.md`):
   - **Every code change follows `CODING_GUIDELINES.md`** and its §13 checklist is ticked before commit (D-005, D-006).
   - **No tool execution** (simulator, compiler, elaborator, lint) without explicit owner approval of tool, version, commands **and options** (D-003). **Nothing is approved for this repository**; the APB approvals do not carry over.
   - **No tool-specific workarounds:** no `` `ifdef <TOOL> ``, tool pragmas or tool-motivated rewrites (D-002). Log tool shortfalls in `REVIEW_FEEDBACK.md` instead.
   - Width pair **DW=32 + DW=64** (both standard for AHB), AW=32; passive observer P on bus A.
   - AHB-Lite and AHB5 are per-instance configuration; proposed default AHB5 without optional properties (Q1/Q2, not yet confirmed).
   - Do not touch the root-level legacy `ahb_*.sv`, `ahb_m_sequencer.txt`, `ahb_directory_structure/` or the `AHB-UVC` gitlink. No force-push, no merge into `dev`/`main`.
   - Mark every unexecuted stage **NOT RUN**.
4. **What exists:** see *Source manifest*. **What is missing:** see *Known gaps*.
5. **Next exact step:** see the handoff block at the end.

## Approved scope

Deliver **one reusable AHB Manager UVC** rooted at `poc/ahb_uvc/`, including its **own** signal interface, driver BFM, monitor BFM, AHB-specific abstract/proxy classes, UVM agent, sequences, coverage, filelists, integration example and tests. Two simultaneous 32/64-bit instances demonstrate parameter independence (ADR-001). The existing older AHB UVC is preserved. No other protocol UVC or multi-UVC TB is part of this POC.

## Decision/progress inventory

| ID | Work | Status | Evidence or caveat |
|---|---|---|---|
| DOC-001 | ADR-001: HVL concrete proxies | ACCEPTED_FOR_POC (carried over from APB) | `ADR-001-HVL-PROXY-PLACEMENT.md`; not compiler validated for AHB |
| DOC-002 | ADR-002: distinct drive/observe APIs; 2 BFMs / 1 signal interface | ACCEPTED_LOGIC (carried over from APB) | `ADR-002-SEPARATE-DRIVE-OBSERVE-APIS.md`; wiring not compiled |
| DOC-003 | Single-AHB-UVC directory/contract/prompt/guidelines/decision log | DOCUMENTED | `DIRECTORY_ARCHITECTURE.md`, `ARCHITECTURE_CONTRACT.md` v0.1, `CLAUDE_GENERATION_PROMPT.md`, `CODING_GUIDELINES.md`, `DECISION_LOG.md` |
| DOC-004 | AHB-001 protocol contract | PROPOSED | `AHB_PROTOCOL_CONTRACT.md`; Q1–Q7 open; citations by title (RISK-013) |
| IMP-001 | AHB interface and BFMs | WRITTEN_M1, NOT COMPILED | `poc/ahb_uvc/hdl/*`; M2/M3 features rejected by `configure()` |
| IMP-002 | Proxy bases and concrete adapters | WRITTEN, NOT COMPILED | `hvl/api/*`, `hvl/adapter/*` |
| IMP-003 | Non-parameterized UVM AHB components | WRITTEN, NOT COMPILED | `hvl/config`, `hvl/agent`, `hvl/coverage`, `hvl/sequences`, `hvl/pkg/ahb_uvc_pkg.sv` |
| IMP-004 | 32/64 dual-instance UVM test + passive observer | WRITTEN, NOT COMPILED | `examples/ahb_hvl_top.sv`, `tests/ahb_poc_test.sv`, `tests/ahb_passive_reset_tests.sv` |
| IMP-005 | Negative tests | WRITTEN, NOT RUN | fault injection (3 modes), cfg legality (16 cases), unfit width, reset mid-burst; independent reviews NOT_STARTED |

## Source manifest

All paths under `poc/ahb_uvc/`. Nothing is compiled or simulated.

| Path | Content | Status |
|---|---|---|
| `hdl/ahb_bfm_pkg.sv` | Shared enums (revision, HTRANS/HBURST/HSIZE, status, fault, monitor errors), feature struct, `ahb_next_addr()`, legality helpers; no UVM | WRITTEN |
| `hdl/ahb_if.sv` | AHB-Lite + AHB5 Manager-interface pins (no parity), modports, width legality checks | WRITTEN |
| `hdl/ahb_driver_bfm_if.sv` | Manager BFM: pipelined `do_burst()`, BUSY, wait states, ERROR cancel, `'z` release, reset abort (`fork…join_any`), 3 fault modes | WRITTEN_M1 |
| `hdl/ahb_monitor_bfm_if.sv` | Passive BFM: clocking-block sampling, 16 checks, burst reconstruction, bounded queues, `get_burst()`, `get_reset_event()` | WRITTEN_M1 |
| `hvl/types/ahb_defines.svh` | `AHB_MAX_ADDR_WIDTH` 32, `AHB_MAX_DATA_WIDTH` 64 | WRITTEN |
| `hvl/types/ahb_transaction.sv` | `ahb_dir_e`, `ahb_transaction` (one burst; 4-state; size/alignment/1KB/bus constraints; copy/compare/print) | WRITTEN |
| `hvl/types/ahb_reset_event.sv` | Reset edge object (RST-4) | WRITTEN |
| `hvl/api/ahb_drive_proxy_base.sv` | Abstract drive capability (+ POL-01 and X-wdata policies) | WRITTEN |
| `hvl/api/ahb_monitor_proxy_base.sv` | Abstract observe capability (+ reset events, error and activity counters) | WRITTEN |
| `hvl/adapter/ahb_drive_proxy.sv` | `ahb_drive_proxy #(AW,DW,…)`: typed vif, lossless/legality request checks | WRITTEN |
| `hvl/adapter/ahb_monitor_proxy.sv` | `ahb_monitor_proxy #(…,QUEUE_DEPTH)`: typed vif, new transaction per burst, reset events | WRITTEN |
| `hvl/config/ahb_agent_cfg.sv` | Per-instance cfg; `legality_error()` / `validate()` (CFG-01..04, CFG-06, M1 limits) | WRITTEN |
| `hvl/agent/ahb_sequencer.sv`, `ahb_driver.sv`, `ahb_monitor.sv`, `ahb_agent.sv` | Non-parameterized UVM components; monitor has `ap` and `reset_ap` | WRITTEN |
| `hvl/coverage/ahb_coverage.sv` | Protocol coverage (dir, burst, size kind, INCR length, waits, ERROR, BUSY, b2b, HPROT, lock, crosses) | WRITTEN |
| `hvl/sequences/ahb_base_seq.sv`, `ahb_random_seq.sv` | Helpers `do_burst_write/do_burst_read/do_write/do_read`; random bursts in a window | WRITTEN |
| `hvl/pkg/ahb_api_pkg.sv`, `ahb_uvc_pkg.sv`, `ahb_adapter_pkg.sv` | Packages (compile in this order after HDL + uvm_pkg) | WRITTEN |
| `examples/ahb_example_slave.sv` | Subordinate fixture (512-byte memory, wait states = HADDR[5:4], two-cycle ERROR ≥ 0x200) | WRITTEN |
| `examples/ahb_hdl_top.sv` | Instances A (DW=32) + B (DW=64), own clocks/resets; passive BFM pair P on bus A; `pulse_reset_a/b` | WRITTEN |
| `examples/ahb_hvl_top.sv` | Explicit adapter construction, one cfg per instance (P passive), single `uvm_config_db::set`, reset helper, `run_test` | WRITTEN |
| `tests/ahb_hdl_smoke.sv` | HDL-only directed + fault smoke (no UVM), 20 bursts per instance, P checks | WRITTEN |
| `tests/ahb_poc_test_pkg.sv` + `ahb_poc_scoreboard.sv`, `ahb_poc_env.sv`, `ahb_poc_seqs.sv`, `ahb_fake_proxies.sv`, `ahb_poc_reset_ctrl.sv`, `ahb_poc_test.sv`, `ahb_fault_injection_test.sv`, `ahb_negative_tests.sv`, `ahb_passive_reset_tests.sv` | UVM POC env, reset-aware fixture scoreboard, six tests | WRITTEN |
| `filelists/ahb_hdl.f`, `ahb_hvl.f`, `ahb_hdl_smoke.f`, `ahb_poc.f` | Compile order; use `-F` | WRITTEN |
| `scripts/slang_elab.py`, `scripts/make_eda_bundle.py` | Copied unchanged from the APB POC (generic; running them needs approval / is text processing respectively) | WRITTEN |
| `README.md` | Consumer integration, BFM + HVL API, run instructions, portability policy | WRITTEN |

The original root-level AHB implementation and `ahb_directory_structure/` exist and are **out of scope for modification**.

## Tests available (none run)

| Flow | Top(s) | Test / plusargs | Pass criterion |
|---|---|---|---|
| HDL smoke (no UVM) | `ahb_hdl_smoke` | none; `+AHB_FAULT=1\|2\|3` for negatives | line `SMOKE_RESULT: PASS` |
| UVM POC | `ahb_hdl_top` + `ahb_hvl_top` | `+UVM_TESTNAME=ahb_poc_test` | `TEST_RESULT: PASS (0 errors)` |
| UVM fault injection | same | `+UVM_TESTNAME=ahb_fault_injection_test +AHB_FAULT=1\|2\|3` | `TEST_RESULT: PASS` (A and P detected, B clean) |
| UVM cfg legality | same | `+UVM_TESTNAME=ahb_cfg_negative_test` | `TEST_RESULT: PASS`; 16 verdict lines `ok:` |
| UVM width boundary | same | `+UVM_TESTNAME=ahb_width_negative_test` | `TEST_RESULT: PASS` (unfit write rejected, not on the bus) |
| UVM passive agent | same | `+UVM_TESTNAME=ahb_passive_test` | `TEST_RESULT: PASS`; P identical to agent_a |
| UVM reset mid-burst | same | `+UVM_TESTNAME=ahb_reset_test` | `TEST_RESULT: PASS`; RESET_ABORTED, 1 reset, model cleared, B unaffected |

## Static self-review done (2026-10-31, no tool)

- Every adapter and smoke call matches the BFM task/function signatures in `hdl/ahb_driver_bfm_if.sv` / `hdl/ahb_monitor_bfm_if.sv` (`do_burst` 18 arguments, `get_burst` 16 arguments: order, widths, directions).
- Every pure virtual method of both proxy bases is implemented in the concrete adapters and in the fake proxies.
- Virtual-interface typedefs in the adapters list **all** BFM parameters (including `MASTER_WIDTH`, user widths and `QUEUE_DEPTH`), so they match the `ahb_hdl_top` instances that use defaults.
- Directed addresses are aligned for both instances (8 bytes), stay inside one 1KB page, and the expected beats/wait cycles/ERROR/cancel of every directed burst were traced by hand against the fixture and both BFMs (including `end − start = Σ(1 + waits + busy)` for the INCR4 that runs into ERROR: 10 cycles).
- Only APIs common to UVM 1.2 and IEEE 1800.2 are used: `uvm_config_db`, `type_id::create`, `uvm_declare_p_sequencer`, `phase.get_objection().set_drain_time`, `uvm_root::get().set_timeout`, `uvm_report_server::get_server`, `set_report_severity_id_override`, `uvm_tlm_analysis_fifo`, `uvm_analysis_imp_decl`.
- Text-only checks on the 36 SV/SVH files: no tabs, no trailing whitespace, final newlines, no line over 100 columns, headers present, labelled `end*` keywords, `timescale` only in compilation-unit files, no `TODO`, and the §13 NN-01 grep finds no tool name or pragma.

## First-compile watch list (most likely to need attention)

Classify any failure as **source bug**, **standard violation** or **tool limitation** (contract gate). Never add tool-specific code.

1. `+incdir+` paths in `-F` filelists: some simulators resolve them relative to the filelist, others to the current directory. If includes are not found, pass the include dirs on the command line or use the EDA bundle.
2. Fixed-size unpacked arrays as interface-task arguments called through a virtual interface (`do_burst`, `get_burst`) and array assignment from an unpacked struct member (`beat_addr = o.beat_addr`).
3. Queues of unpacked structs that contain unpacked arrays (`ahb_monitor_bfm_if::obs_q`).
4. Size casts by package parameters (`AHB_FN_AW'(x)`, `ADDR_WIDTH'(x)`, `AHB_MAX_DW'(x)`).
5. Package import in the interface header (`interface … import ahb_bfm_pkg::*; #(…)`).
6. `fork…join_any` + `disable fork` inside an interface task (driver BFM); named-event wake in `get_burst()` / `get_reset_event()` (RISK-002).
7. Two specializations of each parameterized adapter in one image (A and B), the core RISK-001 question. Verilator 5.020 is known to fail here (APB evidence); that is a tool limitation, not a reason to change ADR-001.
8. Constraints with shifts by a random amount (`len << size`, `64'd1 << size`) and `foreach` over dynamic arrays whose size is constrained by `len`.
9. A class declared in `ahb_hvl_top` that calls `ahb_hdl_top.pulse_reset_a()` (hierarchical task call from a class method); hierarchical references from `ahb_hvl_top` into `ahb_hdl_top` (two top modules).
10. `uvm_analysis_imp_decl(_rst)` at package scope in `ahb_poc_test_pkg`.

## Known gaps (not implemented in M1)

- AHB5 exclusive transfers (HEXCL/HMASTER/HEXOKAY with an exclusive-access monitor model), write strobes (HWSTRB, IHI §3.5.2) and user signals: milestone M2. Interface parity: milestone M3 (pin list not declared yet).
- Cross-item pipelining (NONSEQ during the previous burst's last data phase) is not generated (POL-05, RISK-014); continuing a burst after an ERROR is not implemented (POL-02).
- INCR items longer than 16 beats (POL-04); locked sequences spanning several items (HMASTLOCK is per item and the random sequence keeps it 0).
- No AHB-Lite or HPROT[6:4]/HNONSEC-enabled instance runs traffic in the POC tests (only the cfg legality verdicts cover them). An AHB-Lite integration needs only a cfg change on an instance with AW=32.
- No X-injection test for the monitor's X/Z checks (RISK-009); coverage of reset transitions.
- Spec citations by title only (RISK-013).
- Emulation suitability (`fork` in the BFM, strings in BFM messages, dynamic queues) is unassessed.

## Next tasks — in priority order

- [~] **AHB-001 — Review protocol contract:** drafted in `AHB_PROTOCOL_CONTRACT.md`; Q1–Q7 implemented on proposed defaults, awaiting owner review.
- [ ] **AHB-002 — Toolchain approval:** owner decides on T1/T3 (and T5) below; until then everything stays NOT RUN.
- [~] **AHB-003 — HDL + compile:** sources written; elaboration and the HDL smoke NOT RUN.
- [~] **AHB-004 — HVL types/proxies/agent + compile:** sources written; elaboration NOT RUN.
- [~] **AHB-005 — Run AHB POC:** seven flows written (*Tests available*); NOT RUN. The owner can run them on EDA Playground (T4).
- [ ] **AHB-006 — Independent reviews:** ChatGPT and Gemini review the same pinned commit, record findings and rerun failing tests.
- [ ] **AHB-007 — Spec citation check (RISK-013):** a reviewer with IHI 0033C confirms section numbers and the wording of AHB-R04/R10/R19/R22.

## Toolchain (this container, 2026-10-31)

Non-executing discovery only (`command -v`, Python module lookup); no tool was launched.

| Tool | Version | Status | Use |
|---|---|---|---|
| slang (via `pyslang`) | — | **Not installed** (`importlib.util.find_spec('pyslang')` is None) | Would need installation from PyPI (reachable through the session proxy) — part of the T1 approval |
| slang, verilator, iverilog, vcs, xrun, vsim, dsim executables | — | Not found on `PATH` | — |
| Commercial simulators | — | Not in this container | Owner option: EDA Playground (D-004) |
| UVM library | — | Not downloaded | Needed for elaboration of the HVL code (T3) |

## Validation evidence

**Nothing executed.** No evidence directory exists yet; the first approved run creates `docs/dv-architecture/evidence/AHB-003/` (VER-02).

| Stage | Tool/version | Command | Result | Log | Commit |
|---|---|---|---|---|---|
| HDL elaboration (`ahb_hdl_smoke`) | — (T1 proposed) | NOT RUN | NOT RUN | — | — |
| HDL-only smoke A/B/P + 3 fault runs | — (T4 proposed) | NOT RUN | NOT RUN | — | — |
| HVL + UVM elaboration (`ahb_poc.f`) | — (T1 + T3 proposed) | NOT RUN | NOT RUN | — | — |
| UVM `ahb_poc_test`, `ahb_passive_test`, `ahb_reset_test` | — (T4 proposed) | NOT RUN | NOT RUN | — | — |
| UVM `ahb_fault_injection_test` ×3 | — (T4 proposed) | NOT RUN | NOT RUN | — | — |
| UVM `ahb_cfg_negative_test`, `ahb_width_negative_test` | — (T4 proposed) | NOT RUN | NOT RUN | — | — |
| 4-state / drive release / X-Z checks | — | NOT RUN | NOT RUN | — | — |
| Emulation | UNKNOWN | NOT RUN | NOT RUN | — | — |

## Toolchain approval request

**Nothing is approved for this repository (D-003).** The items mirror the APB approvals so the owner can decide quickly; each needs an explicit "approved" with tool, version and commands. Commands are from the repository root.

| # | Tool / version | Scope | Exact commands |
|---|---|---|---|
| T1 | slang via pyslang (PyPI), version to be fixed at approval (APB used 12.1.0) — **PROPOSED** | Install, then elaboration/lint of the HDL smoke and the full UVM POC | Install: `python3 -m pip install pyslang==<version>`. HDL: `python3 -I poc/ahb_uvc/scripts/slang_elab.py -F poc/ahb_uvc/filelists/ahb_hdl_smoke.f --top ahb_hdl_smoke`. UVM: `python3 -I poc/ahb_uvc/scripts/slang_elab.py +incdir+<UVM>/src <UVM>/src/uvm_pkg.sv -F poc/ahb_uvc/filelists/ahb_poc.f --top ahb_hdl_top --top ahb_hvl_top` |
| T2 | ~~Verilator~~ | **Not proposed:** the APB work showed Verilator 5.020 cannot build this architecture (APB RISK-001/009); workarounds are not allowed | — |
| T3 | UVM **1.2** source, owner-named mirror (APB D-009) — **PROPOSED** | Download only, for T1 elaboration; not a simulator; kept outside the repository | `git clone https://github.com/gchinna/uvm-1.2.git /opt/tools/uvm-1.2-gchinna` |
| T4 | Commercial simulator on EDA Playground (owner picks Questa/Xcelium/VCS/…, with its UVM 1.2 or 1800.2 library) — owner-run | HDL smoke and the UVM tests in *Tests available*, 4-state checks (RISK-009) | HDL bundle: `python3 -I poc/ahb_uvc/scripts/make_eda_bundle.py poc/ahb_uvc/filelists/ahb_hdl_smoke.f ahb_hdl_smoke_bundle.sv` (top `ahb_hdl_smoke`). UVM bundle: `python3 -I poc/ahb_uvc/scripts/make_eda_bundle.py poc/ahb_uvc/filelists/ahb_poc.f ahb_poc_bundle.sv` (tops `ahb_hdl_top ahb_hvl_top`, run option `+UVM_TESTNAME=<test>`). The bundle step is plain text processing; record each result here |
| T5 | slang option `--timescale 1ns/1ps` — **PROPOSED, expected to be needed** (RISK-012) | Default time scale for design elements that declare none (UVM 1.2's `uvm_pkg`); project files keep their own `` `timescale 1ns/1ps `` | the T1 UVM command with `--timescale 1ns/1ps` added |

## AI handoff template (fill every session)

```text
HANDOFF FROM:
REPO/BRANCH:
EXACT COMMIT SHA:
GIT STATUS (including uncommitted files):
CURRENT TASK ID:
FILES CREATED/CHANGED:
PROVEN WORKING (with log/command):
FAILED CHECKS (with log/command):
NOT YET RUN:
UNRESOLVED AHB SPEC/PORT/SCHEDULING QUESTIONS:
OPEN REVIEW FINDING IDS:
ARCHITECTURE CONTRACT/ADR AMENDED?:
NEXT EXACT COMMAND/SMALLEST TASK:
```

**Rule:** One model's confidence is not a validation result. If context/tokens are low, write this handoff before starting further generation.

### Latest handoff — 2026-11-01 (PR #7 merged into dev)

```text
HANDOFF FROM: Claude (Claude Code session)
REPO/BRANCH: MAHANTHADEEKSHA-SB/AHB-UVC @ dev 6a84aa2 (merge of PR #7, branch claude/festive-goodall-33kr39,
             commits 63ac0d4..634faaf); this status/summary update on claude/festive-goodall-33kr39 restarted from dev
EXACT COMMIT SHA: dev 6a84aa297a23cf26d61c92fe0ff96a99f632636e; the status update is the branch HEAD (`git log -1`)
GIT STATUS (including uncommitted files): clean after the push
CURRENT TASK ID: none in progress; AHB-001 (contract review) and AHB-002 (toolchain approval) wait for the owner
FILES CREATED/CHANGED: session 1 (PR #7): root AGENTS.md; docs/dv-architecture/* (12 documents adapted from apb_uvc b406d6a);
             poc/ahb_uvc/** (36 SV/SVH sources, 4 filelists, 2 scripts, README, .gitignore). This update: WORK_STATUS.md,
             DECISION_LOG.md (D-009, D-010), new SESSION_SUMMARY.md, read-order/listing notes in README, AGENTS,
             DIRECTORY_ARCHITECTURE and the CODING_GUIDELINES GIT-01 note. No legacy file touched.
PROVEN WORKING (with log/command): nothing executed; text-only checks only (Static self-review done)
FAILED CHECKS (with log/command): none run
NOT YET RUN: every elaboration and simulation (no tool approved, D-003)
UNRESOLVED AHB SPEC/PORT/SCHEDULING QUESTIONS: Q1-Q7 (AHB_PROTOCOL_CONTRACT.md §12); spec citations by title (RISK-013);
             cross-item pipelining (RISK-014)
OPEN REVIEW FINDING IDS: RISK-001..006, 008, 009, 011..015 (007 and 010 not applicable)
ARCHITECTURE CONTRACT/ADR AMENDED?: no (contract v0.1, ADRs as merged in PR #7)
NEXT EXACT COMMAND/SMALLEST TASK: in a new chat paste the start prompt from SESSION_SUMMARY.md §6. Owner decides T1/T3
             (and T5); if approved: install pyslang, clone UVM 1.2 outside the repo, run the T1 HDL command on
             ahb_hdl_smoke.f, record evidence/AHB-003/, fix source bugs generically, then the T1 UVM command.
             Otherwise the owner runs the T4 bundles on EDA Playground and the results are recorded here.
```
