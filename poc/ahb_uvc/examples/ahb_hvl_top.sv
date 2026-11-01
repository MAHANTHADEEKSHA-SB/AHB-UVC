// -----------------------------------------------------------------------------
// ahb_hvl_top — HVL integration example: bind adapters, register cfg, run
//
// The only place that connects the width-independent UVM core to the
// physical instances in ahb_hdl_top (ADR-002 configuration flow):
//   1. construct one width-specialized drive and observe adapter per active
//      instance, each bound to that instance's own BFM (explicit, no factory)
//   2. put them as base-class handles into one ahb_agent_cfg per instance
//   3. register each cfg ONCE at the exact agent path
//   4. run_test()
// Instance P is passive: it gets an observe adapter only, so no drive
// capability exists for it (ADR-002 decision 6). The reset-control helper
// gives tests a way to pulse an instance's reset without hierarchical
// references in package code (LANG-12).
// Elaborate with both tops: ahb_hdl_top and ahb_hvl_top.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module ahb_hvl_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ahb_bfm_pkg::*;
  import ahb_api_pkg::*;
  import ahb_uvc_pkg::*;
  import ahb_adapter_pkg::*;
  import ahb_poc_test_pkg::*;

  // Test helper: pulses the reset generators of ahb_hdl_top on request. Lives here
  // because only integration code may use hierarchical references (LANG-12).
  class ahb_hvl_reset_ctrl extends ahb_poc_reset_ctrl;
    function new(string name = "ahb_hvl_reset_ctrl");
      super.new(name);
    endfunction

    // inst "a" or "b"; anything else is a test bug.
    virtual task pulse_reset(string inst, int unsigned cycles);
      case (inst)
        "a":     ahb_hdl_top.pulse_reset_a(cycles);
        "b":     ahb_hdl_top.pulse_reset_b(cycles);
        default: `uvm_fatal("AHB_RESET", {"no reset generator for instance ", inst})
      endcase
    endtask
  endclass : ahb_hvl_reset_ctrl

  // Runs once at time 0, before any UVM phase: the adapters and cfg objects must
  // exist before run_test() builds the agents, which fetch their cfg in build_phase.
  initial begin : bind_and_run
    ahb_drive_proxy   #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) drive_a;
    ahb_monitor_proxy #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) observe_a;
    ahb_monitor_proxy #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) observe_p;
    ahb_drive_proxy   #(.ADDR_WIDTH(32), .DATA_WIDTH(64)) drive_b;
    ahb_monitor_proxy #(.ADDR_WIDTH(32), .DATA_WIDTH(64)) observe_b;
    ahb_agent_cfg     cfg_a;
    ahb_agent_cfg     cfg_p;
    ahb_agent_cfg     cfg_b;
    ahb_hvl_reset_ctrl reset_ctrl;

    // Instance A: AW=32, DW=32
    drive_a       = new("drive_a",   ahb_hdl_top.drv_a);
    observe_a     = new("observe_a", ahb_hdl_top.mon_a);
    cfg_a         = ahb_agent_cfg::type_id::create("cfg_a");
    cfg_a.drive   = drive_a;
    cfg_a.observe = observe_a;
    uvm_config_db#(ahb_agent_cfg)::set(null, "uvm_test_top.env.agent_a", "cfg", cfg_a);

    // Instance P: passive observer of bus A (no drive proxy is constructed)
    observe_p       = new("observe_p", ahb_hdl_top.mon_p);
    cfg_p           = ahb_agent_cfg::type_id::create("cfg_p");
    cfg_p.is_active = UVM_PASSIVE;
    cfg_p.observe   = observe_p;
    uvm_config_db#(ahb_agent_cfg)::set(null, "uvm_test_top.env.agent_p", "cfg", cfg_p);

    // Instance B: AW=32, DW=64
    drive_b       = new("drive_b",   ahb_hdl_top.drv_b);
    observe_b     = new("observe_b", ahb_hdl_top.mon_b);
    cfg_b         = ahb_agent_cfg::type_id::create("cfg_b");
    cfg_b.drive   = drive_b;
    cfg_b.observe = observe_b;
    uvm_config_db#(ahb_agent_cfg)::set(null, "uvm_test_top.env.agent_b", "cfg", cfg_b);

    // Reset control for ahb_reset_test (test helper, not part of the UVC)
    reset_ctrl = new("reset_ctrl");
    uvm_config_db#(ahb_poc_reset_ctrl)::set(null, "uvm_test_top", "reset_ctrl", reset_ctrl);

    run_test("ahb_poc_test");
  end

endmodule : ahb_hvl_top
