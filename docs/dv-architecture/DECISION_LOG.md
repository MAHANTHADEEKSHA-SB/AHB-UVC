# DECISION_LOG — owner decisions for the single AHB UVC POC

Every decision the repository owner has made, in one place, so a new session, model or engineer can pick up the context without the chat history. Decisions here override everything except later owner decisions (precedence in `CODING_GUIDELINES.md`).

**Rules for this file (DOC-02):** add an entry the moment the owner decides something, with the date, the owner's words (paraphrased if long), and where it is applied. Never edit an old entry's meaning; supersede it with a new entry and mark the old one *Superseded by D-xxx*.

**Origin:** the owner asked to reuse the APB templates and instructions for AHB (D-001). The owner rules of the `apb_uvc` repository that are not APB-specific are therefore in force here; each one is listed below with its APB source (`apb_uvc` `docs/dv-architecture/DECISION_LOG.md` at `b406d6a`). APB-specific decisions (APB revisions, the DW=32/16 pair, the APB tool approvals) do **not** carry over.

| ID | Date | Decision | Applied in |
|---|---|---|---|
| D-001 | 2026-10-31 | Owner: "use the same templates and instructions used for APB to AHB and create a UVC; refer `feature/apb-005-passive-reset-apb3-tests` branch from the apb". Templates taken from `apb_uvc` at `b406d6a` (that branch's HEAD, identical to `dev`). The APB-005 gaps (passive-agent and reset tests, a reset event in the observe API) are built into the AHB M1 from the start. | All files under `docs/dv-architecture/`, root `AGENTS.md`, `poc/ahb_uvc/**`; `tests/ahb_passive_reset_tests.sv`; `ahb_monitor_proxy_base::wait_reset_event()` |
| D-002 | 2026-10-31 (APB D-005, 2026-10-29) | **No tool-specific workarounds; keep the code generic** ("it has to be generic as much as possible"). | `CODING_GUIDELINES.md` NN-01/NN-06; `ARCHITECTURE_CONTRACT.md` toolchain gate |
| D-003 | 2026-10-31 (APB D-006, 2026-10-29) | **Toolchain approval gate:** no simulator, compiler, elaborator or lint tool runs without explicit owner approval of tool, version and commands; everything else is NOT RUN. The APB approvals (T1 slang 12.1.0, T3 UVM 1.2 mirror, APB D-008/D-009) covered the APB repository and its commands only; **no tool is approved for this repository yet**. | `CODING_GUIDELINES.md` NN-02; `WORK_STATUS.md` *Toolchain approval request*; every validation row NOT RUN |
| D-004 | 2026-10-31 (APB D-004, 2026-10-29) | Commercial simulators cannot be installed in the assistant's container; **EDA Playground is the owner's option** for simulation. | `WORK_STATUS.md` T4; `scripts/make_eda_bundle.py`; UVC README |
| D-005 | 2026-10-31 (APB D-011/D-012, 2026-10-29) | Every code change follows the **highest coding standard**; `CODING_GUIDELINES.md` is **mandatory** and makes the context portable to the next session or model. | `CODING_GUIDELINES.md` header and §13 checklist |
| D-006 | 2026-10-31 (APB D-013, 2026-10-30) | **Required comments:** every file, module, interface, class, task, function, process and covergroup carries the comments the next session or model needs to follow the code. | `CODING_GUIDELINES.md` FMT-09; every source under `poc/ahb_uvc/` |
| D-007 | 2026-10-31 (APB D-014/D-015, 2026-10-30) | **Commit identity:** commits are authored and committed as the owner, Mahantha Deeksha S B (same email as the owner's own commits); AI assistance only as the `Co-Authored-By` trailer. Earlier commits keep their authorship (the two `Claude`-authored commits on the separate `refactor` branch are not touched); no history rewrite, no force-push. | `CODING_GUIDELINES.md` GIT-07; repository-local git identity |
| D-008 | 2026-10-31 | Work branch: the session-designated `claude/festive-goodall-33kr39`, created from `dev` (= `main`, `ed51c95`). This is the AHB counterpart of APB D-001; its name differs from the `feature/<task-id>-…` pattern of GIT-01 because the session fixes the branch. The owner may rename it (for example `feature/ahb-001-protocol-contract`) when opening a pull request. | Git history; `CODING_GUIDELINES.md` GIT-01 note |
| D-009 | 2026-11-01 | The owner merged [PR #7](https://github.com/MAHANTHADEEKSHA-SB/AHB-UVC/pull/7) (`claude/festive-goodall-33kr39`, commits `63ac0d4`..`634faaf`) into `dev` as `6a84aa2`. The merge accepts the documents and M1 sources into `dev`; it does **not** by itself confirm the proposed defaults Q1–Q7 or approve any tool (D-003 still applies). Follow-up work starts from `dev`. | `WORK_STATUS.md` header, *Resume here*, handoff; `SESSION_SUMMARY.md` §1 |
| D-010 | 2026-11-01 | Owner: "save any of the workstatus and the summary so that I can re-use in the new context window chat". A one-page summary with a copy-paste start prompt and a session log is kept in `SESSION_SUMMARY.md` and updated at the end of every session, together with `WORK_STATUS.md`. | `SESSION_SUMMARY.md`; read order in `README.md`, `AGENTS.md`, `WORK_STATUS.md` |

## Defaults in force, not yet confirmed by the owner

These were proposed by the implementer and are implemented, but the owner has not explicitly accepted them. Treat them as defaults that may change. Each has an entry in `AHB_PROTOCOL_CONTRACT.md` §12.

| ID | Topic | Default in force | Where |
|---|---|---|---|
| Q1 | AHB revision scope | AHB-Lite (IHI 0033A) and AHB5 (IHI 0033B/C) as per-instance configuration; AMBA 2 multi-manager AHB (HBUSREQ/HGRANT, SPLIT/RETRY, 2-bit HRESP) out of scope | `AHB_PROTOCOL_CONTRACT.md` §1 |
| Q2 | Default instance | AHB5, 4-bit HPROT, no optional property | `ahb_bfm_pkg::ahb_default_features()` |
| Q3 | Width pair | DW=32 + DW=64, both legal in IHI 0033C (the APB A1 amendment does not apply); AW=32 | ADR-001 decision 3; `examples/ahb_hdl_top.sv` |
| Q4 | Milestones | M1 AHB-Lite + HPROT[6:4] + HNONSEC; M2 exclusive transfers, write strobes, user signals; M3 parity | `AHB_PROTOCOL_CONTRACT.md` §2, §10 |
| Q5 | Reset and policies | RST-1..7 and POL-01..06 as written | `AHB_PROTOCOL_CONTRACT.md` §4–5 |
| Q6 | Item granularity | One burst per item; INCR items up to 16 beats; no cross-item pipelining (one cycle between the last data phase and the next NONSEQ) | `AHB_PROTOCOL_CONTRACT.md` POL-04/POL-05 |
| — | After an ERROR | The Manager cancels the remaining beats of the burst (POL-02); continuing is also legal but not implemented | `ahb_driver_bfm_if::do_burst()` |
| — | Monitor delivery | `get_burst()` / `get_reset_event()` wait on named events after checking the queue | `AHB_PROTOCOL_CONTRACT.md` §7 |
| — | File extensions | Package-included class files keep `.sv` (as in the APB plan); `.svh` for define headers only | `CODING_GUIDELINES.md` FILE-03 |
