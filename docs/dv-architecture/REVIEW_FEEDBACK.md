# REVIEW_FEEDBACK — one AHB UVC POC

**Scope:** Independent reviews of the **single AHB UVC** developed under `poc/ahb_uvc/`. Both DW=32 and DW=64 are specializations of **the same UVC**. This log does not certify the existing root-level AHB implementation or `ahb_directory_structure/`.

Risk IDs follow the APB log (`apb_uvc` at `b406d6a`) where the risk is the same, so a reviewer of both UVCs can cross-reference them; APB-only risks are marked *not applicable*.

## Independent evidence loop

1. Pin the exact branch commit SHA before reviewing; read `ARCHITECTURE_CONTRACT.md`, ADR-001/002, and the AHB protocol contract.
2. Claude (or implementing engineer) records generated files and actual compiler/simulator logs in `WORK_STATUS.md`.
3. ChatGPT reviews that commit independently for SV type legality, UVM architecture, AHB pipeline timing, race-free monitor sampling and instance isolation; Gemini performs an independent review before seeing conclusions.
4. Record each concrete issue with file/line, reproduction or evidence, severity, proposed remedy, fix commit and retest result.
5. Re-run targeted checks **and** relevant regression; close only with proof or explicit approved waiver. LLM consensus without executed evidence is not a PASS.

## Review finding template

```markdown
### RV-XXX — Brief AHB-specific title
- Status: OPEN | INVESTIGATING | FIXED_UNVERIFIED | CLOSED_VERIFIED | WAIVED_APPROVED
- Severity: BLOCKER | MAJOR | MINOR | SUGGESTION
- Reviewers:
- Reviewed branch and full SHA:
- AHB revision / width configuration:
- File(s) and line(s):
- Requirement / architecture ADR:
- Failing scenario:
- Evidence (trace, test, compiler error, or concrete reasoning):
- Corrective action:
- Fix commit:
- Retest tool/version + exact command + log + result:
- Closure decision:
```

## Open design risks (not established implementation defects)

### RISK-001 — Two BFM SV interface binding legality
- **Status:** OPEN; **applies to** `hdl/ahb_{driver,monitor}_bfm_if.sv`, `hvl/adapter/*`.
- Do the typed virtual BFM handles compile when two BFMs use **ordinary individual signal ports** wired to the same `ahb_if` instance, with two specializations (DW=32, DW=64) of each parameterized adapter in one image?
- **Related APB evidence (not AHB evidence):** in `apb_uvc`, slang 12.1.0 elaborated the identical pattern with 0 project diagnostics (APB `evidence/APB-004/`); Verilator 5.020 aborted on two specializations of a parameterized class holding parameterized virtual-interface types (a tool defect; APB RISK-001). The AHB sources use the same pattern and must not be changed to suit that tool (D-002).
- **Evidence required:** an approved elaboration of `filelists/ahb_hdl_smoke.f` and `filelists/ahb_poc.f` with both specializations, logs and SHA.

### RISK-002 — AHB pipeline scheduling and observation
- **Status:** OPEN.
- Does the Manager keep address, control and write data stable through `HREADY` LOW, overlap address and data phases correctly, insert BUSY only between beats and cancel after the first ERROR cycle? Does the monitor reconstruct each burst exactly once, at the right edge, race-free, including the edge where the last data phase completes together with the next IDLE/NONSEQ acceptance?
- **Evidence required:** the HDL smoke (20 directed bursts per instance, cycle-stamp consistency check `end - start = Σ(1 + waits + busy)`), the three fault modes, and waveforms of a waited SEQ, a BUSY and an ERROR cancel.

### RISK-003 — Lossless width and per-instance isolation
- **Status:** OPEN.
- Does the same transaction/proxy API represent DW=32 and DW=64 without loss, including the upper 32 bits of the 64-bit bus, narrow transfers on the correct lanes, and 4-state values?
- **Evidence required:** smoke read-back on both instances, the narrow byte-merge case, `ahb_width_negative_test` (unfit write rejected, nothing on the bus), and a deliberate cross-binding verdict (CFG-06 in `ahb_cfg_negative_test`).

### RISK-004 — Passive UVC and deliverability
- **Status:** OPEN; test written.
- Can a passive AHB agent observe when its driver BFM does not drive, without contention? Can a consumer build the reusable AHB core without the example Subordinate/tests or the older repository source?
- **Evidence required:** `ahb_passive_test` and the smoke's P checks on a 4-state simulator; an independent compile of `ahb_hdl.f` + `ahb_hvl.f` alone.

### RISK-005 — AHB revision contract
- **Status:** OPEN.
- Are the supported revisions (AHB-Lite, AHB5) and property subset documented and implemented consistently, including reset, the two-cycle ERROR, HPROT width and HNONSEC?
- **Evidence required:** owner review of `AHB_PROTOCOL_CONTRACT.md` Q1–Q7 and a traceability check against the IHI 0033C PDF (see RISK-013).

### RISK-006 — Scope creep / misleading migration
- **Status:** OPEN pending review.
- Does any change create a second protocol UVC or modify the older AHB UVC (root `ahb_*.sv`, `ahb_m_sequencer.txt`, `ahb_directory_structure/`, the `AHB-UVC` gitlink) without authorization?
- **Evidence required:** branch diff restricted to the root `AGENTS.md`, `docs/dv-architecture/` and new `poc/ahb_uvc/` files.

### RISK-007 — *not applicable* (APB: DW=64 outside IHI 0024D)
- IHI 0033C allows `DATA_WIDTH` up to 1024, so the AHB pair DW=32 + DW=64 is standard and no extension switch exists (ADR-001).

### RISK-008 — AHB5 superset pin interface versus ADR-001 "maximum-footprint" rejection
- **Status:** OPEN (design review).
- `ahb_if` declares the AHB-Lite + AHB5 Manager pins (except parity) with runtime presence flags. Widths stay parameterized; reviewers should confirm that unused-pin, tie-off and debug costs are acceptable, and that the floating M2 inputs (`HEXOKAY`, `HRUSER`, `HBUSER`) in the example top are harmless while unused.

### RISK-009 — 4-state and drive-release behaviour unverified
- **Status:** OPEN; needs a 4-state simulator run (e.g. EDA Playground, UVC README).
- Untested: the never-enabled driver BFM of instance P releasing every output to `'z`, the monitor's X/Z checks (`HTRANS_XZ`, `CONTROL_XZ`, `HREADY_XZ`, `HRESETN_XZ`) and the 4-state round trip of `HRDATA`.
- **Evidence required:** the smoke (P checks) and `ahb_passive_test` on a 4-state simulator, plus an X-injection test (not written yet, *Known gaps*).

### RISK-010 — *no counterpart*
- APB RISK-010 recorded source changes made for unapproved tools. No tool has been run for the AHB sources, and they contain no tool-specific code (NN-01 grep, `CODING_GUIDELINES.md` §14).

### RISK-011 — HDL and HVL/UVM layers written without any compilation
- **Status:** OPEN; raised 2026-10-31 for the first AHB push.
- Every AHB source was written under the toolchain gate with no tool approved for this repository (D-003). Only a static self-review and text-only checks were done (`WORK_STATUS.md` *Static self-review done*).
- Constructs most likely to need attention are listed in `WORK_STATUS.md` *First-compile watch list*. Each failure must be classified as source bug, standard violation or tool limitation, and fixed without tool-specific code.
- **Evidence required:** an approved elaboration of `filelists/ahb_hdl_smoke.f` and `filelists/ahb_poc.f` with 0 errors in project code, then the HDL smoke and the six UVM tests passing with logs and SHA.

### RISK-012 — UVM 1.2 has no `timescale; mixing is an error under slang (expected)
- **Status:** OPEN (expected, not yet observed for AHB).
- APB RISK-012: slang 12.1.0 reports `MissingTimeScale` in `uvm_pkg.sv` because every project file declares `` `timescale 1ns/1ps `` and UVM 1.2 declares none. The AHB sources follow the same LANG-10 rule, so the same diagnostic is expected for any slang + UVM 1.2 run. Classification: library / language rule, not a project source bug. Not worked around in the sources.
- **Proposed resolution:** as for APB, an owner decision on a default-timescale option for the elaborator/simulator (T5 in `WORK_STATUS.md`).

### RISK-013 — IHI 0033C cited by section title; numbers and wording not verified against the PDF
- **Status:** OPEN; raised 2026-10-31.
- The AHB protocol contract and source comments cite IHI 0033C by section title. The PDF was not available and the Arm documentation hosts were blocked by the authoring session's network policy; only the facts marked ✓ in `AHB_PROTOCOL_CONTRACT.md` were confirmed (through search results), e.g. §3.7 "Waited transfers", the width properties, HPROT width 0/4/7, the two-cycle ERROR.
- Rules most in need of checking: AHB-R10 (early termination only after ERROR), AHB-R04 (BUSY at the end of INCR), AHB-R19 (reset wording), AHB-R22 (validity of HTRANS/HREADY, an APB analogy), the `HMASTER` width, and the M2/M3 pin lists.
- **Evidence required:** a reviewer with IHI 0033C updates the citations (numbers + titles) and any rule whose wording differs, in one commit referencing this risk.

### RISK-014 — No cross-item pipelining (POL-05) limits stimulus and coverage
- **Status:** OPEN (design limit, accepted for M1 pending owner review Q6).
- One item is one burst, and the driver completes an item (with its responses) before taking the next, so the next NONSEQ is never presented during the previous burst's last data phase. Real Managers do this; the UVC therefore cannot yet generate that case, although the monitor handles it (a NONSEQ accepted at the completion edge ends the open burst).
- **Proposed remedy (M2 candidate):** early `item_done` after the last address phase, with the data-phase response delivered through `put_response` or an item event; needs sequence API changes.

### RISK-015 — Language features with uneven tool support
- **Status:** OPEN; first-compile watch list.
- Fixed-size unpacked arrays as interface-task arguments called through virtual interfaces (`do_burst`, `get_burst`); queues of unpacked structs holding arrays (monitor BFM); a class declared in a module that calls a module task through a hierarchical reference (`ahb_hvl_top::ahb_hvl_reset_ctrl`); `uvm_analysis_imp_decl` in a test package. All are IEEE 1800-2017 constructs; a tool that rejects one is logged here, not coded around (NN-06).

## Closed findings

_None. No AHB source has been compiled or simulated._
