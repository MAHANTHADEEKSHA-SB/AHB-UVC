// -----------------------------------------------------------------------------
// ahb_fault_injection_test — negative test: injected faults must be detected
//
// Runs the ahb_poc_test traffic with a driver-BFM fault on instance A only
// (+AHB_FAULT=<n>, ahb_fault_e; default 1 = HADDR changed in a wait state).
// The monitor errors of A and of the passive observer P on the same bus
// (ID "AHB_PROTOCOL") are expected, so they are demoted to info and A's
// scoreboard is disabled. The test passes only if
//   * A's monitor (and P's, when present) counted the violation that matches
//     the fault, and
//   * instance B stayed clean (isolation): its scoreboard and monitor report
//     nothing and it still saw back-to-back traffic and an ERROR beat.
// Included by ahb_poc_test_pkg.
// -----------------------------------------------------------------------------

class ahb_fault_injection_test extends ahb_poc_test;
  `uvm_component_utils(ahb_fault_injection_test)

  ahb_fault_e fault = AHB_FAULT_ADDR_UNSTABLE;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // start_of_simulation runs bottom-up, so A's driver has already configured and
  // enabled its BFM; the fault applies from the first burst. A's (and P's) expected
  // AHB_PROTOCOL errors are demoted and A's scoreboard disabled; B keeps every check.
  virtual function void start_of_simulation_phase(uvm_phase phase);
    int unsigned arg;
    super.start_of_simulation_phase(phase);
    if ($value$plusargs("AHB_FAULT=%d", arg)) fault = ahb_fault_e'(arg);
    if (fault == AHB_FAULT_NONE)
      `uvm_fatal("AHB_FAULT", "+AHB_FAULT=0 selects no fault")
    env.agent_a.cfg.drive.set_fault(fault);
    env.agent_a.monitor.set_report_severity_id_override(UVM_ERROR, "AHB_PROTOCOL", UVM_INFO);
    if (env.agent_p != null)
      env.agent_p.monitor.set_report_severity_id_override(UVM_ERROR, "AHB_PROTOCOL", UVM_INFO);
    env.sb_a.enabled = 1'b0;
    `uvm_info("AHB_FAULT", $sformatf("injecting %s on %s",
                                     fault.name(), env.agent_a.get_full_name()), UVM_LOW)
  endfunction

  // Replaces ahb_poc_test::check_phase: instance A is expected to misbehave
  virtual function void check_phase(uvm_phase phase);
    ahb_mon_error_e want;
    case (fault)
      AHB_FAULT_ADDR_UNSTABLE: want = AHB_MON_ERR_UNSTABLE_IN_WAIT;
      AHB_FAULT_BAD_SEQ_ADDR:  want = AHB_MON_ERR_BURST_ADDR;
      default:                 want = AHB_MON_ERR_BURST_LENGTH;
    endcase
    if (env.agent_a.cfg.observe.get_error_count(want) == 0)
      `uvm_error("AHB_FAULT", $sformatf("injected %s was NOT detected (%s count is 0)",
                                        fault.name(), want.name()))
    else
      `uvm_info("AHB_FAULT", $sformatf("detected: %0d x %s",
                                       env.agent_a.cfg.observe.get_error_count(want),
                                       want.name()), UVM_LOW)
    if (env.agent_p != null && env.agent_p.cfg.observe.get_error_count(want) == 0)
      `uvm_error("AHB_FAULT", "passive observer P did not detect the fault on its bus")
    if (env.agent_b.cfg.observe.get_total_errors() != 0)
      `uvm_error("AHB_FAULT", "instance B reported protocol errors: fault leaked across instances")
    check_traffic(env.sb_b);
  endfunction

endclass : ahb_fault_injection_test
