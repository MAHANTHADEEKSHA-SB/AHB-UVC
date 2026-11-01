# GitHub repository AI guidance

This repository already contains an older AHB UVC: the flat-layout root-level `ahb_*.sv` files (plus `ahb_m_sequencer.txt`), the copy under `ahb_directory_structure/`, and an `AHB-UVC` gitlink without `.gitmodules`. Do **not** move, replace, or refactor those files as part of the new architecture experiment. (A cleanup of them exists on the separate `refactor` branch; it is not part of this work.)

For the **single AHB UVC proof of concept** under `poc/ahb_uvc/`, read [docs/dv-architecture/AGENTS.md](docs/dv-architecture/AGENTS.md) and its architecture contract, ADRs, directory plan, `WORK_STATUS.md`, and `REVIEW_FEEDBACK.md`. Owner decisions are in [docs/dv-architecture/DECISION_LOG.md](docs/dv-architecture/DECISION_LOG.md); every code change must follow [docs/dv-architecture/CODING_GUIDELINES.md](docs/dv-architecture/CODING_GUIDELINES.md) (mandatory). These documents were adapted from the `apb_uvc` repository (branch `feature/apb-005-passive-reset-apb3-tests`, commit `b406d6a`) on the owner's request.

The experimental AHB UVC is self-contained: **one** Manager signal interface, **two** separate BFM interfaces (driver/monitor), separate abstract/concrete HVL proxies, UVM components and filelists. DW=32 and DW=64 are **instances of the same UVC** (ADR-001 decision 3), not other protocol UVCs.

Do not run any simulator, compiler, elaborator or lint tool, or add a tool option, without explicit owner approval; no tool-specific workarounds. Do not claim compilation or simulation passed without actual commands/logs. Do not modify the source outside `poc/ahb_uvc/` unless separately approved. No force pushes or direct merges into `dev` or `main`.
