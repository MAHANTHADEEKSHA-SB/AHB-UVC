# AHB UVC — target directory architecture (single-UVC POC)

**Status:** Target layout adopted from the approved APB plan (`apb_uvc` at `b406d6a`, owner decision D-001); exact compilation and BFM wiring require validation.
**Scope:** Exactly **one reusable AHB Manager UVC**. The 32-bit and 64-bit configurations (ADR-001) are two instances of the same UVC, not two UVC products. No APB, AXI, reset UVC, generic bus framework, or subsystem bridge scoreboard is in this milestone.

## Repository integration

The GitHub repository already contains an older AHB UVC at its root (flat layout) and under `ahb_directory_structure/`. Do **not** move, delete, or rewrite that implementation as part of the POC. Put new code under `poc/ahb_uvc/`; evaluate migration in a separate approved change.

```text
AHB-UVC/                              # existing GitHub repository
├── AGENTS.md                         # directs AI contributors to governance docs
├── docs/
│   └── dv-architecture/
│       ├── README.md
│       ├── AGENTS.md
│       ├── DECISION_LOG.md
│       ├── CODING_GUIDELINES.md
│       ├── ARCHITECTURE_CONTRACT.md
│       ├── DIRECTORY_ARCHITECTURE.md
│       ├── ADR-001-HVL-PROXY-PLACEMENT.md
│       ├── ADR-002-SEPARATE-DRIVE-OBSERVE-APIS.md
│       ├── AHB_PROTOCOL_CONTRACT.md
│       ├── CLAUDE_GENERATION_PROMPT.md
│       ├── WORK_STATUS.md
│       ├── SESSION_SUMMARY.md
│       └── REVIEW_FEEDBACK.md
├── ahb_*.sv, ahb_m_sequencer.txt     # original UVC; unchanged by POC
├── ahb_directory_structure/          # original UVC copy; unchanged by POC
└── poc/
    └── ahb_uvc/                      # SELF-CONTAINED, TRANSFERABLE UVC ROOT
        ├── hdl/
        │   ├── ahb_bfm_pkg.sv        # types + burst arithmetic shared with the HVL side
        │   ├── ahb_if.sv             # Manager-interface signals, modports
        │   ├── ahb_driver_bfm_if.sv  # timed AHB Manager drive tasks (pipeline)
        │   └── ahb_monitor_bfm_if.sv # passive AHB sampling, burst reconstruction
        ├── hvl/
        │   ├── types/
        │   │   ├── ahb_defines.svh
        │   │   ├── ahb_transaction.sv
        │   │   └── ahb_reset_event.sv
        │   ├── api/
        │   │   ├── ahb_drive_proxy_base.sv
        │   │   └── ahb_monitor_proxy_base.sv
        │   ├── adapter/
        │   │   ├── ahb_drive_proxy.sv
        │   │   └── ahb_monitor_proxy.sv
        │   ├── config/
        │   │   └── ahb_agent_cfg.sv
        │   ├── agent/
        │   │   ├── ahb_driver.sv
        │   │   ├── ahb_monitor.sv
        │   │   ├── ahb_sequencer.sv
        │   │   └── ahb_agent.sv
        │   ├── sequences/
        │   ├── coverage/
        │   └── pkg/
        │       ├── ahb_api_pkg.sv
        │       ├── ahb_uvc_pkg.sv
        │       └── ahb_adapter_pkg.sv
        ├── filelists/
        │   ├── ahb_hdl.f
        │   ├── ahb_hvl.f
        │   ├── ahb_hdl_smoke.f
        │   └── ahb_poc.f
        ├── examples/
        │   ├── ahb_example_slave.sv
        │   ├── ahb_hdl_top.sv
        │   └── ahb_hvl_top.sv
        ├── tests/                    # HDL smoke + UVM POC test package
        ├── scripts/                  # slang wrapper, EDA Playground bundler
        └── README.md                 # consumer integration + build instructions
```

**Directory policy:** Create paths as files are implemented, not empty placeholder folders (an `assertions/` directory is planned for M3 only when it gets content). The UVC must be deliverable by copying `poc/ahb_uvc/` (with UVM/simulator prerequisites documented). The demonstration Subordinate/top and POC tests are examples shipped alongside the reusable core, **not required by a consumer**.

## Ownership and compile boundary

| Ownership | Compiled / integrated as | What it contains |
|---|---|---|
| `hdl/ahb_bfm_pkg.sv` | HDL package (no UVM) | Enums, feature struct, status/fault/monitor-error codes, burst address arithmetic |
| `hdl/ahb_if.sv` | HDL interface unit | AHB Manager-interface signals and modports; no UVM classes and no drive tasks |
| `hdl/*_bfm_if.sv` | HDL interface units | Separate Manager-drive and passive-monitor timing tasks; each connected to **one shared** `ahb_if` instance |
| `hvl/types` + `hvl/api` | API SV package | Non-parameterized AHB transaction, reset event and separate abstract proxy APIs |
| `hvl/agent` + `hvl/config` + `hvl/coverage` + `hvl/sequences` | UVM SV package | Non-parameterized UVM driver, monitor, sequencer, agent, cfg, coverage, sequences |
| `hvl/adapter` | Width-specialized adapter package | HVL concrete proxies holding correctly specialized virtual BFM interface handles |
| `filelists` | Build scripts | Explicit compilation dependency order; consumer can use HDL/HVL groups |
| `examples` + `tests` | Demo-only | Standalone smoke Subordinate, two width configurations plus a passive observer, directed and negative tests |

SystemVerilog **interface definitions cannot live inside a class/package**. The *deliverable* is one AHB UVC repository subtree, not a single `ahb_uvc_pkg.sv`. Check package imports and compilation dependencies with the selected simulator; avoid circular package imports.

## Integration model: one UVC, two instances (plus a passive observer)

```text
             AHB UVC definition (single reusable codebase)
              ├── Instance A: DW=32, AW=32
              │   ahb_if32 ─┬─ ahb_driver_bfm_if  #(32)
              │             ├─ ahb_monitor_bfm_if #(32)
              │             │     ⇅ typed HVL adapters ⇅ base APIs
              │             │        ahb_agent_cfg A → UVM agent A (active)
              │             ├─ ahb_driver_bfm_if  #(32)  never enabled ('z)
              │             └─ ahb_monitor_bfm_if #(32)  → cfg P → UVM agent P (passive)
              └── Instance B: DW=64, AW=32
                  ahb_if64 ─┬─ ahb_driver_bfm_if  #(64)
                            └─ ahb_monitor_bfm_if #(64)
                                  ⇅ typed HVL adapters ⇅ base APIs
                                     ahb_agent_cfg B → UVM agent B (active)
```

One `ahb_agent_cfg` per agent instance carries the two **base-class handles**. The integration layer constructs correctly specialized concrete proxies and registers the cfg using scoped `uvm_config_db`. The UVM driver must not import the physical AHB interface type. Both BFM interfaces must refer to the **same pin interface instance** within each AHB UVC instance. No cross-instance wiring.

## Signal interface versus BFMs

- `ahb_if` owns AHB Manager-interface pins and port-direction declarations; BFMs own timed operations, clocking blocks and sampling. **Modports do not by themselves solve sampling races.**
- BFMs are parameterized **SV interfaces with ordinary signal ports** mapped to `ahb_if` signals in `ahb_hdl_top`. Do not blindly use an interface-typed port in a BFM interface and then a virtual handle to that interface; ADR-002 documents the portability concern.
- Driver BFM is the active **AHB Manager** for this POC. Monitor BFM observes bursts, including when the UVM agent is passive. An active AHB Subordinate-response BFM is **out of scope**, not forbidden for a future approved extension.
- Decoder and multiplexor signals (`HSELx`, `HREADYOUT`) belong to the interconnect; the example top ties `HSEL` HIGH and feeds the single Subordinate's `HREADYOUT` back as `HREADY`.
- Do not promise that `UVM_PASSIVE` removes HDL BFM elaboration or compilation; it only changes component behavior.

## AHB POC behavior specified before code generation

- Supported revisions and optional properties are explicit (`AHB_PROTOCOL_CONTRACT.md` §1–2); don't fabricate AHB fields or assume every AHB variant includes them.
- The Manager implements the address/data pipeline, holds address, control and write data through wait states, and completes a beat only at an `HCLK` edge where `HREADY` is HIGH.
- Include SINGLE/INCR/WRAP bursts, BUSY, wait states, back-to-back bursts, the two-cycle ERROR response, reset and passive observation.
- For `DW`=32 and 64, specify a lossless transaction representation, byte-lane placement of narrow transfers, and 4-state handling. Do not silently truncate wide data.
- The example Subordinate is a POC fixture and must not be treated as the AHB specification itself.

## Scope exclusions for milestone 1

No APB/AXI/UCIe UVC; no debug bridge; no second protocol agent; no general-purpose environment framework, global common directory, mandatory standalone predictor, or DUT-specific scoreboard in the UVC core. Keep checking in protocol checks/coverage and standalone example tests. Do not prematurely split every optional property into independent packages without measured need.

## Validation and handoff

- First produce a dependency diagram, file manifest, and AHB-specific acceptance criteria (`AHB_PROTOCOL_CONTRACT.md` §9–11).
- Then compile HDL interface/BFMs, API, adapters, UVM agent, example tops and tests — **only after toolchain approval**.
- Record exact commands/results in `WORK_STATUS.md`; review findings in `REVIEW_FEEDBACK.md`.
- A 32/64 dual-instance test demonstrates parameter independence; one-UVC deliverability is demonstrated by using only files in `poc/ahb_uvc/` plus documented external prerequisites.
- No simulator/emulator support is claimed before actual execution.
