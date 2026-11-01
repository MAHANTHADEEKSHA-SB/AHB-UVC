// -----------------------------------------------------------------------------
// ahb_poc_test_pkg — POC environment, fixture scoreboard and tests
//
// Test code only. Uses the UVM core through ahb_uvc_pkg and the abstract
// capabilities through ahb_api_pkg; it never names an HDL interface type
// (the binding is done in examples/ahb_hvl_top.sv).
//
// Tests (select with +UVM_TESTNAME=<name>):
//   ahb_poc_test              DW=32 + DW=64 concurrent directed + random bursts
//   ahb_fault_injection_test  +AHB_FAULT=1|2|3 on instance A; must be detected
//   ahb_cfg_negative_test     CFG-01..04/06 legality verdicts (no bus traffic)
//   ahb_width_negative_test   unfit write on DW=32 must be rejected, not truncated
//   ahb_passive_test          passive observer P matches agent_a, no drive
//   ahb_reset_test            reset in the middle of a burst on instance A
//
// Include directory: tests.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

package ahb_poc_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ahb_bfm_pkg::*;
  import ahb_api_pkg::*;
  import ahb_uvc_pkg::*;

  `include "ahb_poc_scoreboard.sv"
  `include "ahb_poc_env.sv"
  `include "ahb_poc_seqs.sv"
  `include "ahb_fake_proxies.sv"
  `include "ahb_poc_reset_ctrl.sv"
  `include "ahb_poc_test.sv"
  `include "ahb_fault_injection_test.sv"
  `include "ahb_negative_tests.sv"
  `include "ahb_passive_reset_tests.sv"

endpackage : ahb_poc_test_pkg
