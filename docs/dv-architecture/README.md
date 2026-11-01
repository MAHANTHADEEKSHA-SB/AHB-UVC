# Single AHB UVC — architecture and AI handoff

This folder governs **one reusable AHB UVC POC**, developed at `poc/ahb_uvc/`. The *same* AHB UVC is instantiated with 32-bit and 64-bit data buses (both legal in ARM IHI 0033C) to test parameter independence. We are **not building a multi-UVC framework** or generating APB/AXI/UCIe components here.

The templates and instructions come from the `apb_uvc` repository (branch `feature/apb-005-passive-reset-apb3-tests`, commit `b406d6a`), adapted to AHB on the owner's request (`DECISION_LOG.md` D-001).

The existing root-level `ahb_*.sv` files and `ahb_directory_structure/` are an older AHB UVC implementation. They remain unchanged unless a separate migration is approved.

## Read in order

0. [SESSION_SUMMARY.md](SESSION_SUMMARY.md): one-page orientation, session log and a start prompt for a new chat (summary only; the documents below govern).
1. [AGENTS.md](AGENTS.md): what every model/engineer must read and how to hand off.
2. [DECISION_LOG.md](DECISION_LOG.md): every owner decision, dated, with where it is applied; overrides the documents below.
3. [CODING_GUIDELINES.md](CODING_GUIDELINES.md): **mandatory** SystemVerilog/UVM coding standard, Git rules and pre-commit checklist.
4. [ARCHITECTURE_CONTRACT.md](ARCHITECTURE_CONTRACT.md): AHB-only agreed architectural rules and unresolved decisions.
5. [ADR-001](ADR-001-HVL-PROXY-PLACEMENT.md): HVL concrete proxies over parameterized BFM virtual handles.
6. [ADR-002](ADR-002-SEPARATE-DRIVE-OBSERVE-APIS.md): two separate abstract capabilities and two BFMs sharing one signal interface.
7. [DIRECTORY_ARCHITECTURE.md](DIRECTORY_ARCHITECTURE.md): self-contained AHB UVC distribution and example directory.
8. [CLAUDE_GENERATION_PROMPT.md](CLAUDE_GENERATION_PROMPT.md): single-AHB implementation brief.
9. [WORK_STATUS.md](WORK_STATUS.md): real completed/pending work, latest checkpoint and evidence.
10. [REVIEW_FEEDBACK.md](REVIEW_FEEDBACK.md): independent review findings and required retests.
11. [AHB_PROTOCOL_CONTRACT.md](AHB_PROTOCOL_CONTRACT.md): AHB-001 revision/property matrix, pin list, transfer rules, reset assumptions and transaction format traced to ARM IHI 0033C.

## Deliverable boundary

One `poc/ahb_uvc/` directory ships its own **AHB Manager interface, driver BFM, monitor BFM, HVL proxies, UVM classes, sequences, coverage, filelists and usage example**. SV interfaces compile as HDL units; the UVM class definitions compile in packages. A UVC deliverable is **not one giant SV package**.

## Current status

Architecture documentation and the M1 sources exist; this is **not a compiled or tested UVC**. No tool is approved for this repository yet; every compile, elaboration and simulation stage is NOT RUN. Actual status and next steps are in `WORK_STATUS.md`.

**Git workflow:** the first session's branch `claude/festive-goodall-33kr39` (created from `dev` = `main` at `ed51c95`, D-008) was merged into `dev` by PR #7 as `6a84aa2` (D-009). New work starts on a feature branch from `dev` (GIT-01). Do not merge or migrate the original AHB files without explicit approval.
