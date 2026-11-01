# AI contributor guide — single AHB UVC POC

**Scope:** Exactly one AHB Manager UVC developed under `poc/ahb_uvc/`; its 32-bit and 64-bit configurations (ADR-001 decision 3) are different **instances of the same component**. The repository's root-level legacy AHB sources and `ahb_directory_structure/` are not targets of this POC. Do not generate other protocols/UVCs, a generic verification framework or bridge scoreboards.

## Mandatory read before changes

0. `docs/dv-architecture/SESSION_SUMMARY.md` — orientation and session log (a summary; it overrides nothing)
1. `docs/dv-architecture/DECISION_LOG.md` — every owner decision (overrides everything below)
2. `docs/dv-architecture/CODING_GUIDELINES.md` — **mandatory** coding standard and pre-commit checklist
3. `docs/dv-architecture/ARCHITECTURE_CONTRACT.md`
4. `docs/dv-architecture/ADR-001-HVL-PROXY-PLACEMENT.md` and `ADR-002-SEPARATE-DRIVE-OBSERVE-APIS.md`
5. `docs/dv-architecture/DIRECTORY_ARCHITECTURE.md`
6. `docs/dv-architecture/AHB_PROTOCOL_CONTRACT.md`
7. `docs/dv-architecture/WORK_STATUS.md` (start with "Resume here")
8. `docs/dv-architecture/REVIEW_FEEDBACK.md`
9. `docs/dv-architecture/CLAUDE_GENERATION_PROMPT.md` when implementing.

## Required workflow

- Inspect actual branch, exact SHA, `git status --short`, source manifest and available tools before changing anything.
- Write every change to `CODING_GUIDELINES.md` and tick its pre-commit checklist (§13) before committing. Record new owner decisions in `DECISION_LOG.md` immediately.
- Run no tool and add no tool option without explicit owner approval (`WORK_STATUS.md` *Toolchain approval request*); never add tool-specific code. Approvals given in the `apb_uvc` repository do not carry over (D-003).
- Record AHB revision, explicit signal subset, AW/DW widths, reset policy, API transaction encoding, clocking, and BFM-to-pin wiring before declaring compile readiness.
- Work on **one smallest testable AHB milestone**; keep new code within `poc/ahb_uvc/`. Do not touch the original root-level AHB UVC code or `ahb_directory_structure/`.
- Preserve approved architectural decisions unless a documented, approved ADR amendment is provided. If a rule seems invalid, demonstrate a counterexample and propose change, don't silently sidestep it.
- Record all files changed, tool versions, exact compile/sim commands, logs, and failures in `WORK_STATUS.md`. Use **NOT RUN** instead of guessing.
- Record independent ChatGPT/Gemini issues with exact reviewed SHA, file/line, severity and retest evidence in `REVIEW_FEEDBACK.md`.
- Before context/token exhaustion, checkpoint the last known working stage, current task and next exact step in `WORK_STATUS.md`, and add a row to the `SESSION_SUMMARY.md` session log (D-010). Other AIs must be able to resume from Git + Markdown alone.
- Commit only to an authorized branch, never force-push, overwrite shared history or merge without authorization.

## Validation philosophy

Architecture choices informed by public DVCon literature are **not** simulator proofs. SV syntax, package order, AHB pipeline timing, passive operation, 32/64 isolation and fault detection require executed checks. Do not fabricate successful results, claim emulation compatibility, or bring confidential employer/client code into this repo.

**Handoff precedence:** actual checked-out code + executed logs establish observed behavior; accepted contract/ADRs establish intended design. Reconcile contradictions explicitly.
