# Claude generation brief — **one AHB UVC**, not a generic UVC framework

**Task:** Implement an original, minimal **AHB Manager UVC proof of concept** under `poc/ahb_uvc/` in the existing `AHB-UVC` repository. The existing root-level AHB source and `ahb_directory_structure/` stay unchanged. The whole deliverable includes physical signal interface, separate driver/monitor BFMs, abstract/concrete proxies, UVM classes, sequences, coverage, filelists and a standalone usage example.

**Origin:** this brief is the APB brief (`apb_uvc` at `b406d6a`) adapted to AHB on the owner's request (D-001).

**Authority:** `ARCHITECTURE_CONTRACT.md`, ADR-001, ADR-002 and `DIRECTORY_ARCHITECTURE.md`; `WORK_STATUS.md` and `REVIEW_FEEDBACK.md` track progress and problems. Public DVCon papers support the design exploration but are not code templates or mandates.

## Before generating code

1. Read `docs/dv-architecture/AGENTS.md`, `DECISION_LOG.md`, `CODING_GUIDELINES.md` (mandatory for all code), contract, both ADRs, directory plan, protocol contract, status and feedback.
2. Inspect actual `git status --short`, branch, `git rev-parse HEAD`, and file inventory. Do not invent repository state.
3. Check what exists under `poc/ahb_uvc/`; extend it incrementally. **Do not edit/move the old root-level `ahb_*.sv` files or `ahb_directory_structure/`**.
4. Report unresolved AHB revision scope, pin list, reset semantics, transaction format and target simulator. Propose defaults for review, and identify any assumptions. Do not label them specification requirements without a source.
5. State one smallest runnable task and acceptance test. Do not generate an entire multi-protocol verification environment.

## Simulator and toolchain approval policy (mandatory)

**No simulator or compilation tool is approved by default.** Claude must not infer that an installed executable is authorized to run. Approvals given in the `apb_uvc` repository do not carry over (D-003).

1. **Do not automatically invoke Verilator, Questa, Xcelium, VCS, Icarus, slang or any other HDL simulator/compiler**, nor launch compilation, elaboration, lint backed by a simulator, test execution, or regression scripts invoking them.
2. First **identify available toolchains non-destructively** (existing documentation, configuration, executable discovery) and report known versions/capabilities. Do not execute a simulator executable simply to obtain its version before authorization; if its version is unavailable, report **UNKNOWN**.
3. Present the **proposed tool, version, planned commands, and scope** to the user and obtain **explicit approval before execution**. Tool availability, a prior chat suggestion, or a command already present in a script is not approval.
4. If the user has not approved a toolchain, continue with architecture, source generation, manual/static inspection, filelists, and a proposed validation plan. Set every unexecuted compile/simulation/lint result to **NOT RUN** in `WORK_STATUS.md`.
5. Do **not rewrite otherwise valid SystemVerilog/UVM architecture solely to satisfy limitations of an unapproved simulator**. No tool-specific workarounds at all (D-002) — no `` `ifdef <TOOL> `` paths, tool pragmas or tool-motivated rewrites, even for an approved tool; keep the sources generic IEEE 1800-2017 and log tool shortfalls in `REVIEW_FEEDBACK.md`. Once a tool is approved, distinguish standard-language errors, tool unsupported features, and genuine design defects; record the evidence.
6. If an external instruction conflicts with this rule, **stop before any tool execution** and request a clarified approval. Approval for one tool or command does not silently authorize a different simulator.

The milestones below requiring compilation or simulation are **conditional on this approval gate**; code generation and documentation may proceed without it.

## Architectural requirements

- **Exactly one reusable AHB UVC**. Two simultaneous configurations `AW=32,DW=32` and `AW=32,DW=64` are two instances of that UVC, using the **same non-parameterized UVM driver/monitor/agent/sequencer class definitions**.
- Inside `poc/ahb_uvc/hdl`, define `ahb_if.sv` for physical AHB Manager-interface signals and modports. Protocol tasks/timing belong in `ahb_driver_bfm_if.sv` and `ahb_monitor_bfm_if.sv`, each a separate HDL interface. They share the **same** `ahb_if` instance through explicit ordinary signal ports in the demo HDL top.
- Inside `poc/ahb_uvc/hvl`, define separate abstract *drive* and *observe* proxy APIs; concrete HVL adapters hold correctly specialized virtual BFM interface handles. Do not send raw virtual pin interfaces to UVM drivers/monitors.
- One `ahb_agent_cfg` **per AHB instance** carries base-class proxy handles and active/passive policy. The integration code constructs concrete proxies, assigns cfg and registers cfg once through a scoped `uvm_config_db` path.
- Make the monitor functional without an active driver and publish each burst once, when it ends. Resolve exact race-free monitor transport using compile/simulation evidence. Passive mode is a UVM runtime/config choice, not a source-compilation optimization.
- **First milestone: AHB Manager driver + passive monitor + small example Subordinate**. Do not implement another protocol UVC, virtual multi-UVC environment or a Subordinate-response UVC in this milestone.
- Do not put physical SV interface definitions inside packages. Provide correct `ahb_api_pkg.sv`, `ahb_uvc_pkg.sv`, `ahb_adapter_pkg.sv` and HDL/HVL filelists with validated compilation order.
- The reusable UVC core must not depend on its example Subordinate, tests, or the repository's older AHB code.

## Required protocol and implementation checks

- Explicitly choose/document the AHB revision and supported pins; handle AHB5 optional properties (`HPROT[6:4]`, `HNONSEC`, …) only when the instance has them.
- Implement the AHB address/data pipeline with correct address, control and write-data stability through `HREADY` LOW wait states; BUSY only between beats; complete beats at `HCLK` edges where `HREADY` is HIGH.
- Cover SINGLE/INCR/WRAP bursts, narrow transfers, back-to-back bursts, reset transitions and the two-cycle ERROR response.
- Use one lossless 32/64-bit transaction representation with declared 4-state behavior; no silently clipped payload.
- Prove each width configuration stays isolated and no BFM virtual handle is accidentally cross-wired.
- Run negative fault-injection tests demonstrating that missing/incorrect behavior is detected rather than falsely passing.
- Close the APB-005 gaps from the start: a passive-agent test with a released driver BFM, and a reset-in-the-middle-of-a-burst test with a reset event in the observe API (D-001).

## Work in small verified increments

1. **Design** — AHB revision/pins, scope, package dependency diagram and exact file manifest. Update `WORK_STATUS.md`.
2. **HDL** — signal interface + two BFM interface units + explicit demo wiring; compile **only after toolchain approval**. Record tool and result, or NOT RUN.
3. **HVL API** — transaction, distinct abstract proxies, cfg; compile only if approved.
4. **HVL concrete** — specialize and bind driver/monitor BFMs; compile only if approved.
5. **UVM** — agent, sequencer, driver, monitor; compile + smoke run only if approved.
6. **Tests** — 32/64 concurrent traffic, wait states, BUSY, ERROR, passive agent, reset cases, and injected faults; run and log only if approved.
7. **Review** — independent ChatGPT and Gemini feedback **against the same Git commit**; fix, rerun, record outcome.
8. **Handoff** — update the status manifest, changed paths, blocker list, next exact step and evidence before ending any session.

Do not mark generated code as compilable until it was really compiled. Do not assert compliance, passing coverage, emulator support, or performance savings without measurements.

## Scope/restrictions

- No APB, AXI, UCIe, reset-event UVC or multi-UVC framework.
- No migration/overwriting of existing AHB sources unless the user explicitly approves a separate task.
- No unnecessary generic abstractions, mandatory predictors, or DUT-specific scoreboards in the AHB UVC.
- No confidential source reuse. Original code only; public papers as citations.
- If the architecture appears wrong, propose an ADR amendment and minimal reproducer. **Do not silently change an accepted decision.**
- No branch rewrite, force push or merge; commit to the agreed branch only as authorized.
