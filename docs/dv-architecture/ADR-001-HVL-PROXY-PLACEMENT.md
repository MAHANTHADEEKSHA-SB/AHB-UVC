# ADR-001 — HVL-side concrete proxy placement

**Status:** Accepted for first proof of concept (revisit after measured results); carried over from the APB POC (`apb_uvc` ADR-001 at `b406d6a`) by owner decision D-001
**Decision date:** 2026-10-29 (APB) · applied to AHB 2026-10-31
**Scope:** One standalone AHB Manager UVC POC at `poc/ahb_uvc/`; two bus-width instances of the same UVC. This is not a universal rule for other protocols.

## Width pair for AHB

- The APB ADR needed Amendment A1 because APB allows `DATA_WIDTH` 8/16/32 only. **AHB does not:** ARM IHI 0033C defines `DATA_WIDTH` as 8, 16, 32, 64, 128, 256, 512 or 1024 (values below 32 or above 256 not recommended).
- The AHB width-independence demonstration therefore uses **AW=32/DW=32 and AW=32/DW=64**, both standard. No non-standard extension switch exists in the AHB UVC.
- Wider buses need larger transaction maxima (`+define+AHB_MAX_DATA_WIDTH=<n>`); the adapters fail at construction when a bus is wider than the maxima (decision 4).

## Context
For the AHB UVC POC, SystemVerilog's parameterized virtual interfaces have specialization-specific types. When drivers, monitors, agents, environments and tests explicitly depend on those types, interface parameters can ripple through the UVM hierarchy. We want a 32-bit and a 64-bit instance coexisting in the same simulation with one shared definition of each core UVM component.

## Decision
1. Define non-parameterized, protocol-semantic **drive** and **observe** base APIs on the HVL side. Separate these contracts by capability; a passive monitor should not receive driving privileges by default.
2. Implement **parameterized concrete adapters** in a separate HVL adapter package. Each concrete adapter binds a correctly specialized `virtual interface`/BFM handle and translates the common API into BFM operations.
3. Keep parameterized HDL interfaces and BFM tasks/functions in the HDL layer. The HDL layer contains no UVM class objects; any monitor-to-HVL callback/transport arrangement must be reviewed for emulation/tool compatibility, not presumed portable.
4. Non-parameterized UVM drivers/monitors hold base API handles. The integration/top layer creates and configures specialized adapters and fails clearly on missing handles or incompatible width configurations.
5. Start with **explicit construction and typed binding** in top integration, not abstract-class factory registration/overrides. Factory-based selection can be added if a real need arises and UVM/tool support is validated.
6. Record and test transport representation, legal width ranges, 2-state/4-state semantics, and truncation/extension policy. Do not silently truncate.
7. Build 32-bit and 64-bit instances concurrently. Verify independent routing, correctness, error cases, and no parameter ripple in core UVM classes.

## Alternatives considered
| Alternative | Benefit | Tradeoff / disposition |
|---|---|---|
| Width-parameterized driver/monitor/agent/env | Simple typed direct VIF; viable for fixed small environments | Parameter propagation; not chosen for reusable POC |
| Non-parameterized maximum-footprint interface | Simple common interface type | Unused signals, potential tie-offs and debug overhead; not chosen |
| Proxy class scoped inside parameterized HDL interface | Local access to HDL parameters without separate typed adapter | Class inside HDL BFM hinders emulation-compatible partitioning; simulation-only option |
| HVL-side parameterized concrete proxy (chosen) | Separation of HDL/HVL and common non-parameterized UVM APIs | Requires explicit instance construction/binding, width adaptation and monitor return path |
| `interface class` alternative | Can express an API contract | Simulator support and HDL binding design must be assessed; may be useful later |

## Architectural boundary
```text
HVL (one AHB UVC, two width specializations):
  UVM sequence -> driver -> drive_api_base -> drive_adapter #(DW) --typed virtual BFM--+
  UVM monitor <- observe_api_base <- observe_adapter #(DW) <--monitor transport-------+-- HDL BFM #(DW) <-> interconnect pins

  HVL integration top: constructs adapters, binds each exact BFM specialization,
                       routes correct base handles to agent configuration.
HDL:
  Parameterized driver and monitor BFMs / signal-facing interfaces.
```

## AHB UVC deliverable and source/package ownership

The **one transferable UVC** includes all of the following; do not split AHB BFMs or pins into global TB directories:

```text
poc/ahb_uvc/
  hdl/ahb_bfm_pkg.sv                    # shared types + burst address arithmetic
  hdl/ahb_if.sv                         # physical AHB Manager-interface signals/modports
  hdl/ahb_driver_bfm_if.sv              # timed Manager-drive BFM interface
  hdl/ahb_monitor_bfm_if.sv             # passive monitor BFM interface
  hvl/types/{ahb_defines.svh,ahb_transaction.sv,ahb_reset_event.sv}
  hvl/api/ahb_drive_proxy_base.sv
  hvl/api/ahb_monitor_proxy_base.sv
  hvl/adapter/ahb_drive_proxy.sv
  hvl/adapter/ahb_monitor_proxy.sv
  hvl/config/ahb_agent_cfg.sv
  hvl/agent/{ahb_driver,ahb_monitor,ahb_sequencer,ahb_agent}.sv
  hvl/pkg/{ahb_api_pkg,ahb_uvc_pkg,ahb_adapter_pkg}.sv
  hvl/sequences/
  hvl/coverage/
  filelists/{ahb_hdl,ahb_hvl,ahb_hdl_smoke,ahb_poc}.f
  examples/{ahb_example_slave,ahb_hdl_top,ahb_hvl_top}.sv
  tests/
  README.md
```

The examples and tests demonstrate integration; they are not mandatory for consumers of the AHB UVC core. The GitHub repo already has a flat-layout AHB UVC: **leave those original files untouched**; this POC lives under `poc/ahb_uvc/`. The interface and BFM interface declarations compile as HDL units and are **not placed inside class packages**. Demonstrate DW=32 and DW=64 as **two instances of the same source definitions**. Monitor transport, package order and signal port connections require executable validation.

## Contract requirements
- Base APIs express transaction (burst) semantics, not arbitrary raw pin pokes unless justified.
- A driver cannot use a raw `virtual interface` directly under this ADR.
- Scoreboards/reference models consume only transaction/event objects, not physical DUT handles.
- Preserve X/Z values where checking requires them; do not blanket-convert to `bit`.
- The monitor must sample race-free according to a documented clocking protocol.
- No silent width clipping, unintended sign extension, or bus instance cross-connection.
- API handle setup and errors must be deterministic and diagnosable.

## Risks and counterarguments
- One more layer increases code and debugging hops. Benchmark against a small direct-VIF implementation.
- The return path from HDL monitor BFM to HVL is **not** solved by simply introducing an observe adapter; choose concrete callback/polling/FIFO approach with the target tools.
- Proxies do **not** automatically yield synthesis/emulation compatibility. Ensure each HDL task/transport construct is supported by the chosen platform.
- Fixed maximum-width transactions are simple but limited. AHB allows buses up to 1024 bits; a 1024-bit maximum in every item wastes memory, so the maxima are a per-image compile-time choice (`ahb_defines.svh`).
- Formal type compatibility still matters; a `virtual if #(32)` cannot substitute for `virtual if #(64)`.

## POC acceptance gates
1. Same core UVM driver/monitor/agent/env/test class declarations serve concurrent 32- and 64-bit instances.
2. Verified per-instance binding and isolation; swapping physical handles is caught in tests/config checks.
3. Zero silent truncation and correct round-trip payload including the upper 32 bits of the 64-bit bus and narrow-transfer lanes.
4. Monitor capture works with real simulator; no scheduling races in tests.
5. Lint, compilation, simulation and injected-fault test results are recorded with exact tool versions/logs.
6. Optional-feature filelists demonstrate a reduced compile set without unresolved dependencies.
7. Review exceptions and measured overhead before adopting it for every future UVC.

## References from uploaded DVCon sources
- Wayne Yun and Shihua Zhang, *Deploying Parameterized Interface with UVM*, DVCon 2013: Section III, class abstraction, concrete class associated with parameterized interface, and implementation styles (poster slides 6–10).
- Frank Verhoorn and Michael Baird, *Common Challenges and Solutions to Integrating a UVM Testbench in Place of a Legacy Monolithic Testing Environment*, DVCon 2018: Section II, parameter-agnostic interface proxies and common-width BFM forwarding.
- Salman Tanvir, David Crutchfield and Markus Brosch, *Working within the Parameters that SystemVerilog has constrained us to*, DVCon 2024: Section III-C interface-local polymorphic proxy; Section III-D emulation-compatible HVL concrete proxy and factory-free top-level construction.

*These sources support the alternatives and trade-offs. The exact folder structure, separated drive/observe APIs, and POC gates are our engineering choices, not requirements mandated by the papers.*
