# Architecture contract — single AHB UVC POC

**Version:** 0.1 · **Date:** 2026-10-31
**Origin:** adapted from the APB architecture contract v0.10 (`apb_uvc`, branch `feature/apb-005-passive-reset-apb3-tests`, commit `b406d6a`) on the owner's request (`DECISION_LOG.md` D-001). Architecture decisions are carried over unchanged; protocol scope and widths are AHB-specific and PROPOSED.
**Scope:** One reusable **AHB Manager UVC** developed under `poc/ahb_uvc/`, comprising HDL signal interface, independent drive/monitor BFMs, HVL abstract and concrete proxies, UVM agent, coverage, sequences, filelists and demo. Existing flat-layout AHB UVC files at the repository root and in `ahb_directory_structure/` are **not to be changed** by this milestone.

This contract describes *intended architecture*, not a claim that code has been compiled, simulated or accepted by a simulator. Accepted decisions can change only by a recorded, reviewed ADR amendment. Execution status belongs in `WORK_STATUS.md`.

## Decision states

- **ACCEPTED_FOR_POC:** approved design to test, **not** proven implementation.
- **PROPOSED:** working choice to evaluate before (or while) coding.
- **UNRESOLVED:** requires specification, compiler, simulator, or engineering decision.

## ADR-001 — HVL concrete proxies [ACCEPTED_FOR_POC, carried over from APB]

1. Use **separate abstract AHB drive and monitor proxy APIs** whose types do not depend on the AHB pin interface's `AW` or `DW`.
2. Implement concrete HVL proxy classes that specialize on physical bus width and hold correspondingly typed **virtual BFM interface** handles. Do not put concrete UVM class objects inside HDL BFM interfaces.
3. Core UVM driver, monitor, sequencer and agent are **not parameterized by AW/DW**. Demonstrate by creating two configurations of this *same UVC*: AW=32/DW=32 and AW=32/DW=64 (both legal in IHI 0033C).
4. Boundaries must reject missing handles, wrong bindings, unsupported widths and information loss. Define 4-state data transport before generation; no implicit casting/truncation.
5. Explicit adapter construction in integration code is preferred for the first POC; factory registration is not a requirement.

## ADR-002 — separate APIs; two BFMs share one signal interface [ACCEPTED LOGIC; WIRING PROPOSED, carried over from APB]

1. One `ahb_if` per bus instance owns physical signals and modports. **No protocol drive/receive tasks inside the signal interface.**
2. A separate parameterized **driver BFM interface** owns active AHB Manager drive, the address/data pipeline and handshake tasks.
3. A separate parameterized **monitor BFM interface** owns passive sampling and burst reconstruction.
4. Both BFMs connect to the **same `ahb_if` instance**, not to separate copies of pins. There must be no unintended multiple drivers.
5. Distinct non-parameterized abstract drive and observe proxy classes prevent monitor code using the drive capability through its configured API.
6. One per-instance `ahb_agent_cfg` holds both base handles (drive handle optional when passive) and active/passive policy. The integration layer binds and registers cfg with a specific `uvm_config_db#(ahb_agent_cfg)` path; the UVM agent retrieves once and passes handles to driver and monitor.
7. Initial BFM implementation: **SV interfaces with ordinary typed signal ports** mapped to shared `ahb_if` pins in `examples/ahb_hdl_top.sv`. Interface-typed interface ports plus virtual BFM handles are **not assumed portable** under the restriction described in DVCon 2024.
8. The exact monitor-to-HVL transport path and clock-edge scheduling need compile/simulation evidence. Modports alone are insufficient for race-free sampling.
9. Passive AHB agent must still observe valid bursts, with no active drive from its agent. Compiling, elaborating, instantiating and activating components are distinct stages.

## AHB-only functional scope [PROPOSED]

- First POC acts as an **AHB Manager agent** with passive bus monitor and an independent, small example Subordinate. A reusable Subordinate responder/driver is out of scope for milestone 1.
- **Revision scope (Q1, PROPOSED):** one UVC supports **AHB-Lite** (ARM IHI 0033A) and **AHB5** (ARM IHI 0033B/C) as per-instance configuration; AHB5 interface properties are per-instance flags and unused ones stay inactive. AMBA 2 multi-manager AHB (arbitration, SPLIT/RETRY, 2-bit HRESP) is out of scope. Proposed default instance: AHB5 with 4-bit HPROT and no optional property (Q2). The revision/property legality matrix, pin list, reset assumptions and transaction format are defined in [AHB_PROTOCOL_CONTRACT.md](AHB_PROTOCOL_CONTRACT.md) (PROPOSED).
- **Width pair (Q3, PROPOSED):** IHI 0033C allows `DATA_WIDTH` 8, 16, 32, 64, 128, 256, 512 or 1024 (32..256 recommended), so the demonstration pair is DW=32 + DW=64 with AW=32 — both spec-legal. The APB ADR-001 Amendment A1 (DW=64 as a non-standard extension) has no AHB counterpart.
- One burst per sequence item. The Manager issues NONSEQ then SEQ beats with the address of beat n+1 overlapping the data phase of beat n, holds address, control and write data stable through `HREADY` LOW wait states, inserts BUSY only between beats, and completes a beat only at an `HCLK` edge where `HREADY` is sampled HIGH. Observed bursts are published once, when the burst ends.
- Cover SINGLE, INCR, INCR4/8/16, WRAP4/8/16, narrow transfers, BUSY, wait states, back-to-back bursts, the two-cycle ERROR response, reset and passive observation.
- Two widths (32/64) are test instances of **one source implementation**, not two protocol UVCs. Monitor transactions must not be silently narrowed.
- Reset drive/observation behavior must be documented explicitly; do not guess unspecified rules from a separate DUT/bridge project.
- One example Subordinate and tests live under `poc/ahb_uvc/examples` and `tests`, distinct from reusable UVC core.
- UVC-local protocol checks and coverage are allowed. DUT-specific mapping/prediction/scoreboards do **not** belong in this generic AHB UVC core.
- No APB, AXI, UCIe, reset-event UVC, multi-UVC environment or bridge in this phase.

## Packaging and boundaries

`poc/ahb_uvc/` is the **reusable delivered unit**. It must carry `hdl/`, `hvl/`, `filelists/`, documentation, and sample integration. Its class packages and HDL interfaces remain **separate SystemVerilog compilation units**: an SV package cannot contain interface declarations.

| Layer in single UVC | Responsibility | Forbidden shortcut |
|---|---|---|
| `hdl/ahb_if.sv` | Physical AHB Manager-interface signals and modports | Mix in UVM class API or long drive task library |
| `hdl/ahb_driver_bfm_if.sv` | Timed AHB Manager drive (address/data pipeline) | Access wrong interface instance |
| `hdl/ahb_monitor_bfm_if.sv` | Passive AHB observation and burst reconstruction | Drive AHB pins or construct UVM class objects in HDL |
| `hvl/api/` + `types/` | Non-width-parameterized AHB protocol APIs and transaction | Expose typed physical VIF through core UVM classes |
| `hvl/adapter/` | Width-specialized virtual BFM binding and conversion | Silently lose 4-state or upper data bits |
| `hvl/agent/` + `config/` | UVM AHB agent and per-instance handle setup | Retrieve arbitrary global config or silently share instance cfg |
| `filelists/` | Separate HDL/HVL/core/demo compile units | Assume runtime `is_active` removes compile load |
| `examples/` + `tests/` | Demo Subordinate, tops, acceptance tests | Be mandatory dependencies of a delivered UVC core |

## Toolchain selection and execution gate [ACCEPTED_FOR_POC, carried over from APB]

- **No default or automatically approved simulator.** Verilator, Questa, Xcelium, VCS, Icarus, slang and other HDL toolchains are candidate tools, not instructions to execute.
- Before invoking any simulator/compiler for lint, compilation, elaboration, simulation or regression, the implementer must **present the selected tool/version, intended commands, and scope and obtain explicit user approval**. Installed tools, available licences, environment variables, old conversation suggestions and approvals given for the `apb_uvc` repository are not authorization (D-003).
- Non-executing discovery of available tools and version metadata is allowed; do not launch an unapproved simulator binary even for version discovery. Record an unknown version as **UNKNOWN**, not a guess.
- While toolchain approval is pending, source design and generation, manual/static reviews, package/filelist preparation and proposed test cases may proceed. All unexecuted lint, compile, simulation and regression stages must remain **NOT RUN** in `WORK_STATUS.md`.
- **Portable sources only (D-002):** no tool-specific code paths (`` `ifdef <TOOL> ``), tool pragmas or tool-motivated rewrites in `poc/ahb_uvc/`. Write generic IEEE 1800-2017 SystemVerilog/UVM; record tool shortfalls in `REVIEW_FEEDBACK.md` instead of coding around them.
- Do not distort a standards-compliant UVM/SystemVerilog architecture to satisfy a limitation of a tool not explicitly approved. After approval, classify failures as source bugs, language/standard violations, or tool limitations, with supporting evidence.
- Approval for one tool/command is not blanket approval for alternative tools or newly introduced execution workflows. Resolve conflicts before execution.

## Build and acceptance gates

1. Manifest and dependency graph are reviewable and consistent with `DIRECTORY_ARCHITECTURE.md`.
2. **After explicit toolchain approval**, a named simulator compiles the **same AHB UVC class definitions** for 32-bit and 64-bit AHB instances in one test; until then, record NOT RUN.
3. Driver and monitor BFMs share each instance's single signal interface; no conflicting drivers, cross-wiring or invalid virtual interface types.
4. AHB pipeline, burst, BUSY, wait-state and ERROR behavior and monitor publication pass directed tests; include intentional error/fault injection expected to fail.
5. Passive agent works as observer; its never-enabled driver BFM causes no contention.
6. Accurate coverage/validation evidence shows tools, version, command, log and Git SHA. **No unexecuted pass claims**.
7. Compare implementation cost against a direct-virtual-interface baseline after a runnable POC. No claims of guaranteed performance or emulation compatibility.

## Unresolved

- Owner review of Q1–Q6 in `AHB_PROTOCOL_CONTRACT.md` §12 (revision scope, default instance, widths, milestones, reset/policies, item granularity).
- Section numbers of IHI 0033C cited by title only (the PDF is not in the repository and the Arm documentation hosts were not reachable from the authoring session); a reviewer with the PDF should confirm them (RISK-013).
- Interface parity pin list (M3), exclusive-access monitor model and write-strobe rules (M2).
- Explicit user approval of simulator/toolchain/version and proposed execution commands; UVM version and compilation order of API/UVM/adapter package against interface definitions.
- Whether standalone filelists meet consumer integration requirements.

## Sources and limitations

Public DVCon papers inform the **proxy pattern and alternatives**, not our project names/directory mandates:
- Yun & Zhang (AMD), DVCon 2013, *Deploying Parameterized Interface with UVM*.
- Verhoorn & Baird, DVCon 2018, *Common Challenges and Solutions to Integrating a UVM Testbench in Place of a Legacy Monolithic Testing Environment*.
- Tanvir, Crutchfield & Brosch (Infineon), DVCon 2024, *Working within the Parameters that SystemVerilog has constrained us to*, especially Sections III-C/III-D.

Use original code only; no confidential employer/client IP, no guessed tool validation.
