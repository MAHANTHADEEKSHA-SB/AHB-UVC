// -----------------------------------------------------------------------------
// ahb_uvc_pkg — non-parameterized UVM core of the AHB UVC
//
// Configuration, agent, sequencer, driver, monitor, coverage and generic
// sequences. Depends only on ahb_api_pkg (abstract capabilities), never on a
// physical interface type or on ahb_adapter_pkg (ADR-001 decision 3).
//
// Compile after uvm_pkg, ahb_bfm_pkg and ahb_api_pkg. Include directories:
// hvl/config, hvl/agent, hvl/coverage, hvl/sequences.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

package ahb_uvc_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ahb_bfm_pkg::*;
  import ahb_api_pkg::*;

  `include "ahb_agent_cfg.sv"
  `include "ahb_sequencer.sv"
  `include "ahb_driver.sv"
  `include "ahb_monitor.sv"
  `include "ahb_coverage.sv"
  `include "ahb_agent.sv"
  `include "ahb_base_seq.sv"
  `include "ahb_random_seq.sv"

endpackage : ahb_uvc_pkg
