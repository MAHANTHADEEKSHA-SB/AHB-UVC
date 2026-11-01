// -----------------------------------------------------------------------------
// ahb_poc_base_test / ahb_poc_test — POC acceptance test (step 6)
//
// ahb_poc_base_test: common timeout and the result line
//   "TEST_RESULT: PASS|FAIL (<n> errors) <test>" from the report server.
// ahb_poc_test: the DW=32 and DW=64 instances run concurrently with the same
//   non-parameterized agent classes (ADR-001 gate 1): directed bursts, then
//   constrained-random bursts across in-range and ERROR addresses. Passes
//   when both scoreboards checked traffic with no mismatch, each saw a
//   back-to-back burst and an ERROR beat, and no monitor (including the
//   passive observer P) reported a protocol error.
// Included by ahb_poc_test_pkg.
// -----------------------------------------------------------------------------

class ahb_poc_base_test extends uvm_test;
  `uvm_component_utils(ahb_poc_base_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Global watchdog: the test fails instead of hanging.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_root::get().set_timeout(2ms, 1);
  endfunction

  // One machine-readable result line from the report server's error and fatal
  // counts; the only $display in UVM code (UVM-09).
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server server = uvm_report_server::get_server();
    int errors = server.get_severity_count(UVM_ERROR) + server.get_severity_count(UVM_FATAL);
    super.report_phase(phase);
    $display("TEST_RESULT: %s (%0d errors) %s", errors == 0 ? "PASS" : "FAIL", errors,
             get_type_name());
  endfunction

endclass : ahb_poc_base_test


// The same agent classes drive DW=32 and DW=64 at once (ADR-001 gate 1).
class ahb_poc_test extends ahb_poc_base_test;
  `uvm_component_utils(ahb_poc_test)

  ahb_poc_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // The env builds agent_p only if the integration registered a cfg for it.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = ahb_poc_env::type_id::create("env", this);
  endfunction

  // Both active instances run concurrently; the drain time lets each monitor
  // publish the last burst before the run phase ends.
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.get_objection().set_drain_time(this, 300ns);
    fork
      run_traffic(env.agent_a);
      run_traffic(env.agent_b);
    join
    phase.drop_objection(this);
  endtask

  // Directed bursts, then 30 random bursts; addresses >= 'h200 get ERROR.
  protected task run_traffic(ahb_agent agent);
    ahb_poc_directed_seq directed = ahb_poc_directed_seq::type_id::create("directed");
    ahb_random_seq       rand_seq = ahb_random_seq::type_id::create("rand_seq");
    directed.start(agent.sequencer);
    if (!rand_seq.randomize() with { num_items == 30; })
      `uvm_fatal("AHB_POC", "cannot randomize ahb_random_seq")
    rand_seq.addr_max = 'h3FF;  // upper half of the page is beyond the fixture memory
    rand_seq.start(agent.sequencer);
  endtask

  // Every scoreboard must have checked traffic, seen a back-to-back burst and an
  // ERROR beat.
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    check_traffic(env.sb_a);
    check_traffic(env.sb_b);
  endfunction

  // Errors, not fatals: every instance is checked and reported.
  protected function void check_traffic(ahb_poc_scoreboard sb);
    if (sb.num_checked == 0)
      `uvm_error("AHB_POC", {sb.get_full_name(), ": no bursts checked"})
    if (sb.num_b2b == 0)
      `uvm_error("AHB_POC", {sb.get_full_name(), ": no back-to-back burst observed"})
    if (sb.num_error_beats == 0)
      `uvm_error("AHB_POC", {sb.get_full_name(), ": no ERROR response observed"})
  endfunction

endclass : ahb_poc_test
