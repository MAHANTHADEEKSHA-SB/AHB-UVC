# ADR-002 — Separate abstract drive and observe APIs

**Status:** Logical architecture selected for POC; BFM wiring still requires simulator validation. Carried over from the APB POC (`apb_uvc` ADR-002 at `b406d6a`) by owner decision D-001.
**Date:** 2026-10-29 (APB) · applied to AHB 2026-10-31
**Depends on:** ADR-001 (HVL-side concrete proxies; AHB width pair DW=32 + DW=64)

## Context
Our **single AHB UVC** must support active and passive instances, preserve a clear HDL/HVL boundary, and enable two physical data-width specializations (32 and 64 bits) without creating different UVC codebases. A monolithic proxy can expose both drive and observe operations, whereas two narrowly scoped APIs can enforce separation by capability. Neither placement nor number of API classes automatically solves the monitor data transport problem.

## Decision
1. Use separate **non-parameterized abstract drive and observe API classes** for this AHB UVC. The driver receives only the drive API; the monitor receives only the observe API.
2. Keep **parameterized concrete HVL adapters** per API and AHB BFM specialization, using a correctly typed virtual-interface/BFM handle in each adapter.
3. Use **one parameterized AHB Manager signal interface** shared by **two BFMs**, one driver BFM and one monitor BFM. The pin interface holds signals and relevant modports; it does **not** own protocol-drive/sample tasks. Those tasks and timing logic (including the address/data pipeline) live in the respective BFMs.
4. Prefer BFM units implemented as SystemVerilog **interfaces**, so each HVL concrete adapter can hold a typed `virtual ahb_driver_bfm_if#(...)` or `virtual ahb_monitor_bfm_if#(...)` and call its tasks. A BFM implemented as a **module** does not automatically support this virtual-interface calling pattern; it would need a separate API/transport mechanism.
5. Use one **non-parameterized AHB per-instance configuration object** to carry respective abstract handles and protocol configuration (e.g. active/passive, revision and AHB5 interface properties, policies). Do not create an inherited common API solely to share configuration.
6. In passive mode, do not construct or bind the drive adapter; the monitor/observe adapter remains functional. In active mode, the agent creates driver/sequencer and monitor as appropriate.
7. Define monitor observation as a blocking task (`receive(output txn)`, and `wait_reset_event(output ev)` for reset edges, RST-4) over a validated queue mechanism; select transport based on simulation/emulation/tool evidence. Avoid putting an unbounded `forever` loop inside an analysis `write()` function.
8. API calls are protocol-semantic (one call = one burst) where practical; pin-level helpers can exist if timing or reactive response requires them, but must be documented and tested.
9. Both API classes have explicit unbound/unsupported-operation failure semantics. Validate width, 4-state data preservation, per-instance isolation, and event ordering.
10. This is the **chosen AHB UVC POC** decomposition, not a mandate for other protocol UVCs.

## BFM-to-pin-interface connection: important separate decision

Section III-D and Figures 13–16 of Tanvir, Crutchfield & Brosch (DVCon 2024) discuss the same logical combination: a signal interface, driver/monitor BFMs, HVL concrete proxies and non-parameterized base APIs. Their paper flags an IEEE 1800-2017 restriction: if a BFM **interface** has a port referencing another interface, creating a **virtual interface handle to that BFM interface** is not legal under the restriction cited. Therefore **do not treat `interface ahb_driver_bfm_if(ahb_if.manager pins)` + `virtual ahb_driver_bfm_if vif` as validated portable code.**

For the proof of concept we use **BFM interfaces with ordinary typed signal ports** (individual inputs/outputs, not an interface-typed port), explicitly mapped to the shared signal interface in the HDL top. This adds wiring boilerplate but avoids the specific interface-port/virtual-interface issue. Signal connection directions must be checked. Neither this nor the published harness/bind variant is claimed validated until it compiles and runs on our target tool.

## Configuration and ownership flow

1. HDL top elaborates `ahb_if#(AW,DW)`, `ahb_driver_bfm_if#(AW,DW)`, and `ahb_monitor_bfm_if#(AW,DW)`; both BFMs connect to the **same** signal interface instance.
2. The HVL integration layer constructs one specialized concrete drive proxy and one specialized concrete observe proxy per active agent instance (observe only for a passive one) and binds them to the corresponding **BFM virtual interface** types (not the raw `ahb_if`).
3. Those concrete objects are assigned through polymorphism to two **base API handles** inside one per-instance `ahb_agent_cfg` object.
4. The integration layer registers **the configuration object once** using `uvm_config_db#(ahb_agent_cfg)::set` with an exact agent instance path before build-phase retrieval. The agent calls `get` once and passes the drive handle to its driver and observe handle to its monitor. Avoid redundant database lookups in every child.
5. For passive use, an observe-capable monitor always remains valid, while the driver BFM and driver component must not drive. The POC keeps a never-enabled driver BFM on the passive bus to prove its outputs stay `'z`; truly omitting it is an HDL elaboration/build-filelist decision, **not** something `UVM_PASSIVE` accomplishes on its own.
6. **Monitor BFM code returns sampled value types and fixed-size arrays**, and the HVL layer constructs UVM class transactions. Avoid placing UVM class construction inside HDL BFMs when emulation compatibility matters.
7. The BFM sampling/driving schedule must be race-free: clocking blocks live in the BFMs (inputs `#1step`), outputs are driven with NBAs. Modports define access direction; they do not by themselves solve scheduling races.

## Alternatives and trade-offs
| Alternative | Benefits | Risks | Decision |
|---|---|---|---|
| Single drive+observe abstract proxy | Simpler class and wiring count; suitable for tiny BFMs | Too-wide API; passive code can call drive operations; difficult capability isolation | Not default |
| Separate drive and observe base APIs | Explicit responsibility and access control; flexible active/passive UVC; smaller contracts | Two adapters and two bindings; possible duplicated mechanics | **Chosen** |
| Hybrid common base plus specialized APIs | Shared metadata and optional capability type | Unnecessary inheritance, extra casts and API complexity for this POC | Defer until needed |

## Single AHB UVC distribution layout

```text
poc/ahb_uvc/
  hdl/
    ahb_bfm_pkg.sv                  # shared types and burst arithmetic
    ahb_if.sv                       # shared Manager-interface signals/modports
    ahb_driver_bfm_if.sv            # timed AHB Manager BFM
    ahb_monitor_bfm_if.sv           # passive AHB monitor BFM
  hvl/
    types/{ahb_defines.svh,ahb_transaction.sv,ahb_reset_event.sv}
    config/ahb_agent_cfg.sv
    api/ahb_drive_proxy_base.sv
    api/ahb_monitor_proxy_base.sv
    adapter/ahb_drive_proxy.sv
    adapter/ahb_monitor_proxy.sv
    agent/{ahb_driver,ahb_monitor,ahb_sequencer,ahb_agent}.sv
    pkg/{ahb_api_pkg,ahb_uvc_pkg,ahb_adapter_pkg}.sv
    sequences/
    coverage/
  filelists/
  examples/
  tests/
  README.md
```

This is **one AHB UVC** with a pair of independent BFMs and one shared pin interface *per instance*. Its 32-bit and 64-bit instantiations use the same class definitions. Existing flat-layout AHB UVC source at the repository root is not to be migrated or overwritten.

### Sketch, not production code
```systemverilog
virtual class ahb_drive_proxy_base;
  pure virtual task send(ahb_transaction req);            // one burst
endclass

virtual class ahb_monitor_proxy_base;
  pure virtual task receive(output ahb_transaction observed);
  pure virtual task wait_reset_event(output ahb_reset_event ev);
endclass

class ahb_agent_cfg extends uvm_object;
  ahb_drive_proxy_base   drive;
  ahb_monitor_proxy_base observe;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
endclass
```
`receive()` is intentionally a **task** to permit time-consuming monitor sampling; it allocates a distinct transaction object per burst and relies on the BFM clocking strategy. The real classes are in `poc/ahb_uvc/hvl/`.

## BFM-specific acceptance criteria

- Driver and monitor BFM interfaces share **the same** physical signal interface instance, not copies.
- Compile the selected BFM-to-signal connection form on the actual simulator. For the first POC use ordinary signal ports to avoid the IEEE restriction flagged in DVCon 2024.
- Check that there is exactly one intended driver of every direction-controlled bus signal, and no drive activity while configured passive.
- Confirm monitor can observe bursts even while a driver BFM is disabled (instance P).
- Verify correctly specialized virtual BFM interface types are connected to the corresponding concrete proxy, with no cross-instance leakage.
- Document whether the HDL BFM interface port technique and/or harness variant passes the intended emulation flow; do not infer emulation support from SV simulation alone.

## Required checks before acceptance
- Concurrent 32-bit and 64-bit instances using the same non-parameterized agent/driver/monitor class definitions.
- Passive instance has no constructed driver/sequencer and no usable drive handle, but observes bursts correctly (`ahb_passive_test`).
- A driver cannot invoke observe-only operations; a monitor cannot invoke drive-only operations through its API types.
- Drive and observe adapters bind to the intended physical BFM instance; intentional cross-wiring is detected (CFG-06).
- Race-free monitor collection and correct 2-state/4-state behavior for all supported widths.
- Reset and transaction observation contracts documented, including in-flight bursts (`ahb_reset_test`).
- Compile, simulation, injected-fault tests and exact tool versions recorded. No assertion of emulator support without testing.
- Code-size/build-time tradeoff compared against one combined-proxy proof of concept, at least qualitatively.

## Challenges / limits
- Separate APIs do not imply two DUT interfaces or two HDL clocks. **Our chosen decomposition explicitly uses two BFM units sharing one signal interface.**
- Capability segregation is by the **type of handle**; any code with access to the concrete BFM may still be able to drive it. This is not a security boundary.
- A shared configuration **class** must not become a global singleton: each AHB UVC instance gets its own object, proxy bindings and policy.
- A separate monitor API does not guarantee emulation-compatible callbacks. Determine exact transactor transport on the target tool.
- An AHB Subordinate response-capable agent may be introduced later as a separate milestone **within the same AHB UVC**, with an appropriate reactive drive API; it is not part of the initial Manager-driver POC.

## Source basis and originality
- DVCon 2013, Yun & Zhang, *Deploying Parameterized Interface with UVM*, Section III and slides 6–10: abstract access class/concrete adapter, different abstraction levels, and a combined drive/monitor API example.
- DVCon 2018, Verhoorn & Baird, *Common Challenges and Solutions...*, Section II: parameter-agnostic proxy and BFM forwarding.
- DVCon 2024, Tanvir, Crutchfield & Brosch, *Working within the Parameters...*, Sections III-C/III-D: interface-local and HVL-side concrete proxy alternatives.

**The separate drive/observe split, the shared per-instance configuration, the explicit-signal-port POC connection style, and the recommended file layout are our engineering decisions, not directives mandated by those papers.**
