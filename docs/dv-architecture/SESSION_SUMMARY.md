# SESSION_SUMMARY — AHB UVC work, ready to resume in a new chat

**Purpose (owner request D-010):** one page that a new chat, model or engineer can read first to pick the AHB UVC work up without the old conversation. It summarizes; it does not override anything. Precedence stays `DECISION_LOG.md` > contract/ADRs > `AHB_PROTOCOL_CONTRACT.md` > `CODING_GUIDELINES.md`, and `WORK_STATUS.md` is the detailed status.

**How to use it:** paste the *New-chat start prompt* (last section) into the new chat. Append one row to the *Session log* at the end of every session.

---

## 1. Where things are (2026-11-01)

| Item | Value |
|---|---|
| AHB repository | https://github.com/MAHANTHADEEKSHA-SB/AHB-UVC |
| Integration branch | `dev` at `6a84aa297a23cf26d61c92fe0ff96a99f632636e` = merge of [PR #7](https://github.com/MAHANTHADEEKSHA-SB/AHB-UVC/pull/7) (branch `claude/festive-goodall-33kr39`, 8 commits `63ac0d4`..`634faaf`) |
| `main` | `ed51c95` (behind `dev`; the GitHub default branch) |
| Other branches | `refactor` (`848ceb7`, older cleanup of the legacy files, not part of this work) |
| Template source | https://github.com/MAHANTHADEEKSHA-SB/apb_uvc, branch `feature/apb-005-passive-reset-apb3-tests` at `b406d6a` (= its `dev`) |
| New work starts on | a feature branch from `dev` (GIT-01), e.g. `feature/ahb-002-toolchain-elaboration`, or the branch a new session designates |
| Commit identity | Mahantha Deeksha S B, owner's email (GIT-07); AI only as `Co-Authored-By` |

## 2. What the first session did (2026-10-31 → 2026-11-01)

**Request (D-001):** "use the same templates and instructions used for APB to AHB and create a UVC; refer `feature/apb-005-passive-reset-apb3-tests` branch from the apb".

**Delivered (merged in PR #7):**
- **Governance docs** in `docs/dv-architecture/` (+ root `AGENTS.md`), adapted from APB: README, AGENTS, DECISION_LOG (D-001..D-008), CODING_GUIDELINES (mandatory, §13 checklist), ARCHITECTURE_CONTRACT v0.1, ADR-001, ADR-002, DIRECTORY_ARCHITECTURE, CLAUDE_GENERATION_PROMPT, AHB_PROTOCOL_CONTRACT (AHB-001, PROPOSED), WORK_STATUS, REVIEW_FEEDBACK (RISK-001..015).
- **AHB Manager UVC M1** in `poc/ahb_uvc/` — 36 SV/SVH files, 4 filelists, 2 scripts, README (details in §4).
- **APB-005 gaps closed for AHB from the start:** passive-agent test, reset-in-the-middle-of-a-burst test, reset events in the observe API (RST-4).

**Not done / not verified:**
- **Nothing compiled, elaborated or simulated.** No tool is approved for this repository (D-003; APB approvals do not carry over) and the container had no HDL tool installed.
- **Spec citations by section title only** (RISK-013): the IHI 0033C PDF was not available and `developer.arm.com` / `documentation-service.arm.com` were blocked by the session's network policy. To let a session read them, allow those hosts under *Network access* in the cloud environment settings (environment menu in the session title bar → Edit → Allowed domains), see https://code.claude.com/docs/en/cloud-environments#network-access.
- Repository note: GitHub reported a bypassed rule ("creations being restricted") when the session branch was first pushed.

## 3. Owner rules in force (full text: `DECISION_LOG.md`, `CODING_GUIDELINES.md`)

1. Follow `CODING_GUIDELINES.md` for every change; tick its §13 checklist before committing (D-005); required comments (D-006).
2. **No simulator/compiler/elaborator/lint run, and no tool option, without explicit owner approval** of tool, version and commands (D-003). Mark everything else **NOT RUN**.
3. **No tool-specific workarounds** — generic IEEE 1800-2017 SystemVerilog/UVM only (D-002).
4. Do not touch the legacy root `ahb_*.sv`, `ahb_m_sequencer.txt`, `ahb_directory_structure/`, the `AHB-UVC` gitlink.
5. No force-push, no merge into `dev`/`main`, no PR unless the owner asks; Conventional Commits `<type>(ahb-uvc): …`.
6. Record owner decisions in `DECISION_LOG.md` immediately; keep `WORK_STATUS.md` and this summary current before a session ends.

## 4. AHB UVC cheat-sheet

**Architecture (same as APB):** one `ahb_if` (pins only) per bus + a driver BFM and a monitor BFM, both SV interfaces with ordinary signal ports on the same `ahb_if`; HVL abstract `ahb_drive_proxy_base` / `ahb_monitor_proxy_base`; width-specialized adapters `ahb_drive_proxy #(AW,DW)` / `ahb_monitor_proxy #(AW,DW)` are the only parameterized classes; one `ahb_agent_cfg` per instance, registered once at the agent path; agent/driver/monitor/sequencer/coverage/sequences not parameterized.

**Protocol scope (PROPOSED, Q1–Q7 in `AHB_PROTOCOL_CONTRACT.md` §12):**
- AHB-Lite + AHB5 as per-instance config (`ahb_features_t`); AMBA 2 multi-manager AHB out of scope; default AHB5 without optional properties.
- M1: SINGLE/INCR/INCR4-16/WRAP4-16, BUSY between beats, wait states, two-cycle ERROR, HPROT[3:0] (+[6:4] with Extended_Memory_Types), HNONSEC (Secure_Transfers), HMASTLOCK. M2: exclusive, write strobes, user signals (pins exist, rejected by config). M3: parity (pins not declared).
- Widths: DW=32 (instance A) + DW=64 (instance B), AW=32 — both standard in IHI 0033C. Transaction maxima AW 32 / DW 64 (`ahb_defines.svh`).
- Policies: one burst per item, INCR ≤ 16 beats (POL-04); no cross-item pipelining — one IDLE address phase between items (POL-05, RISK-014); remaining beats cancelled after the first ERROR cycle (POL-02); watchdog 1024 LOW cycles (POL-01).

**Instances in `examples/ahb_hdl_top.sv`:** A (DW=32, 10 ns clock), B (DW=64, 14 ns clock), P = passive observer on bus A (monitor BFM + a driver BFM that is never enabled, proving `'z` release). Fixture `ahb_example_slave`: 512-byte memory, wait states = HADDR[5:4], two-cycle ERROR at addresses ≥ 0x200.

**Key files:** `hdl/ahb_bfm_pkg.sv` (enums, `ahb_next_addr`), `hdl/ahb_driver_bfm_if.sv` (`do_burst`), `hdl/ahb_monitor_bfm_if.sv` (`sample_cycle`, `get_burst`, `get_reset_event`), `hvl/types/ahb_transaction.sv`, `hvl/adapter/*`, `hvl/config/ahb_agent_cfg.sv`, `examples/ahb_hvl_top.sv`, `tests/ahb_poc_test_pkg.sv`.

**Test flows (all NOT RUN):**

| Flow | Tops | Options | Pass line |
|---|---|---|---|
| HDL smoke | `ahb_hdl_smoke` (`ahb_hdl_smoke.f`) | `+AHB_FAULT=1\|2\|3` for negatives | `SMOKE_RESULT: PASS` |
| UVM POC | `ahb_hdl_top ahb_hvl_top` (`ahb_poc.f` + UVM) | `+UVM_TESTNAME=ahb_poc_test` | `TEST_RESULT: PASS (0 errors)` |
| Fault injection | same | `+UVM_TESTNAME=ahb_fault_injection_test +AHB_FAULT=1\|2\|3` | `TEST_RESULT: PASS` |
| Cfg legality | same | `+UVM_TESTNAME=ahb_cfg_negative_test` | `TEST_RESULT: PASS` |
| Width boundary | same | `+UVM_TESTNAME=ahb_width_negative_test` | `TEST_RESULT: PASS` |
| Passive agent | same | `+UVM_TESTNAME=ahb_passive_test` | `TEST_RESULT: PASS` |
| Reset mid-burst | same | `+UVM_TESTNAME=ahb_reset_test` | `TEST_RESULT: PASS` |

## 5. Next steps (in order)

1. **Owner decisions:** review Q1–Q7 (`AHB_PROTOCOL_CONTRACT.md` §12) and answer the toolchain request in `WORK_STATUS.md`: **T1** slang via pyslang (install + elaborate), **T3** UVM 1.2 from the owner-named mirror `github.com/gchinna/uvm-1.2`, **T5** slang `--timescale 1ns/1ps` (expected to be needed, RISK-012). T4 = owner runs the EDA Playground bundles.
2. If T1/T3 are approved: elaborate `ahb_hdl_smoke.f`, then `ahb_poc.f` with UVM; store logs under `docs/dv-architecture/evidence/AHB-003/` / `AHB-004/`; fix source bugs generically (watch list in `WORK_STATUS.md`).
3. Run the seven flows on a simulator (owner, EDA Playground) and record the results.
4. Spec citation check against IHI 0033C (RISK-013): section numbers; wording of AHB-R04/R10/R19/R22.
5. Independent ChatGPT/Gemini reviews of one pinned commit (AHB-006).
6. Then M2 (exclusive, write strobes, user signals), cross-item pipelining (RISK-014), X-injection test (RISK-009).

## 6. New-chat start prompt (copy and paste)

```text
Continue the AHB UVC work in MAHANTHADEEKSHA-SB/AHB-UVC (template repo: MAHANTHADEEKSHA-SB/apb_uvc).
1. git fetch origin; the work is on dev at 6a84aa2 or later (PR #7 merged). Start new work on a
   feature branch from dev (or the branch this session designates). Set the commit identity first:
   git config user.name "Mahantha Deeksha S B" && git config user.email "$(git log origin/dev --author='Mahantha Deeksha S B' --format='%ae' -1)"
2. Read docs/dv-architecture/SESSION_SUMMARY.md, then follow the read order in
   docs/dv-architecture/AGENTS.md (DECISION_LOG, CODING_GUIDELINES, contract, ADRs,
   AHB_PROTOCOL_CONTRACT, WORK_STATUS "Resume here", REVIEW_FEEDBACK).
3. Rules: no simulator/compiler/elaborator/lint without my explicit approval of tool, version and
   commands; no tool-specific workarounds; legacy ahb_*.sv and ahb_directory_structure/ untouched;
   mark everything not executed as NOT RUN; follow CODING_GUIDELINES.md and its checklist.
4. Next task: <write it here, e.g. "T1 and T3 are approved: elaborate the HDL smoke, then the UVM POC">.
```

## 7. Session log (append one row per session)

| Date | Session / branch | Summary | Result commit |
|---|---|---|---|
| 2026-10-31 → 2026-11-01 | `claude/festive-goodall-33kr39` (PR #7) | APB templates adapted to AHB; AHB Manager UVC M1 sources, tests and docs written; nothing compiled (no tool approved) | merged into `dev` at `6a84aa2` |
| 2026-11-01 | `claude/festive-goodall-33kr39`, restarted from `dev` | Owner merged PR #7; status, decision log and this summary updated for a new chat (D-009, D-010) | this commit (not merged yet) |
