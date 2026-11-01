// -----------------------------------------------------------------------------
// ahb_passive_reset_tests — passive-agent and reset tests (APB-005 gaps, done
// for AHB from the start)
//
// ahb_passive_test: runs the ahb_poc_test traffic and checks the passive
//   observer P on bus A (ADR-002 decisions 6 and 9, RISK-004): P has no
//   driver, sequencer or drive capability; it publishes exactly the bursts
//   agent_a's monitor publishes, with the same content and cycle stamps; and
//   it reports no protocol error, which also shows that P's never-enabled
//   driver BFM stayed released ('z) — contention would read as X.
// ahb_reset_test: cuts a long INCR16 write on instance A with a reset
//   (RST-1..RST-5): the item must end AHB_ST_RESET_ABORTED, the partial burst
//   must not be published (RST-4), the monitor must report the reset edges,
//   the scoreboard model must be cleared with the fixture, traffic after the
//   reset must check clean, and instance B must not notice anything.
// Included by ahb_poc_test_pkg.
// -----------------------------------------------------------------------------

class ahb_passive_test extends ahb_poc_test;
  `uvm_component_utils(ahb_passive_test)

  uvm_tlm_analysis_fifo #(ahb_transaction) fifo_a;  // bursts seen by agent_a's monitor
  uvm_tlm_analysis_fifo #(ahb_transaction) fifo_p;  // bursts seen by the passive agent

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // The env and traffic of ahb_poc_test, plus one FIFO per observer.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    fifo_a = new("fifo_a", this);
    fifo_p = new("fifo_p", this);
  endfunction

  // P must exist: the integration (examples/ahb_hvl_top.sv) registers cfg_p.
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (env.agent_p == null)
      `uvm_fatal("AHB_PASSIVE", "no passive agent: cfg for env.agent_p not registered")
    env.agent_a.monitor.ap.connect(fifo_a.analysis_export);
    env.agent_p.monitor.ap.connect(fifo_p.analysis_export);
  endfunction

  // The traffic checks of ahb_poc_test, then the passive-agent checks.
  virtual function void check_phase(uvm_phase phase);
    ahb_transaction ta;
    ahb_transaction tp;
    int unsigned    compared = 0;
    super.check_phase(phase);
    if (env.agent_p.driver != null || env.agent_p.sequencer != null ||
        env.agent_p.cfg.drive != null)
      `uvm_error("AHB_PASSIVE", "passive agent has a driver, sequencer or drive capability")
    while (fifo_a.try_get(ta)) begin
      if (!fifo_p.try_get(tp)) begin
        `uvm_error("AHB_PASSIVE", {"passive agent missed: ", ta.convert2string()})
        break;
      end
      compared++;
      if (!ta.compare(tp) || ta.start_cycle != tp.start_cycle || ta.end_cycle != tp.end_cycle)
        `uvm_error("AHB_PASSIVE", {"observations differ: ", ta.convert2string(), " | ",
                                   tp.convert2string()})
    end
    if (fifo_p.try_get(tp))
      `uvm_error("AHB_PASSIVE", {"passive agent saw an extra burst: ", tp.convert2string()})
    if (compared == 0)
      `uvm_error("AHB_PASSIVE", "no bursts compared")
    else
      `uvm_info("AHB_PASSIVE", $sformatf("%0d bursts identical on agent_a and agent_p",
                                         compared), UVM_LOW)
  endfunction

endclass : ahb_passive_test


// Reset in the middle of a burst on instance A only.
class ahb_reset_test extends ahb_poc_base_test;
  `uvm_component_utils(ahb_reset_test)

  ahb_poc_env        env;
  ahb_poc_reset_ctrl reset_ctrl;
  ahb_transaction    aborted;     // the INCR16 item cut by the reset

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // The POC env plus the reset capability registered by the HVL top.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = ahb_poc_env::type_id::create("env", this);
    if (!uvm_config_db#(ahb_poc_reset_ctrl)::get(this, "", "reset_ctrl", reset_ctrl))
      `uvm_fatal("AHB_RESET", "no ahb_poc_reset_ctrl registered for uvm_test_top")
  endfunction

  // A: directed traffic, then an INCR16 write (about 40 cycles at 10 ns) with a
  // 3-cycle reset pulse 150 ns after it starts, then directed traffic again on the
  // cleared fixture. B runs directed traffic meanwhile and must not be affected.
  virtual task run_phase(uvm_phase phase);
    ahb_poc_directed_seq before_a = ahb_poc_directed_seq::type_id::create("before_a");
    ahb_long_write_seq   long_a   = ahb_long_write_seq::type_id::create("long_a");
    ahb_poc_directed_seq after_a  = ahb_poc_directed_seq::type_id::create("after_a");
    ahb_poc_directed_seq traffic_b = ahb_poc_directed_seq::type_id::create("traffic_b");
    phase.raise_objection(this);
    phase.get_objection().set_drain_time(this, 300ns);
    fork
      begin
        before_a.start(env.agent_a.sequencer);
        fork
          long_a.start(env.agent_a.sequencer);
          begin
            #150ns;
            reset_ctrl.pulse_reset("a", 3);
          end
        join
        aborted = long_a.result;
        after_a.start(env.agent_a.sequencer);
      end
      traffic_b.start(env.agent_b.sequencer);
    join
    phase.drop_objection(this);
  endtask

  // RST-3: item abandoned; RST-4: one reset (assert + release events), the partial
  // burst never published, the model cleared; isolation: B saw no reset.
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (aborted == null || aborted.status != AHB_ST_RESET_ABORTED)
      `uvm_error("AHB_RESET", "the INCR16 write was not abandoned by the reset")
    if (env.agent_a.cfg.observe.get_reset_count() != 1 ||
        env.agent_a.monitor.num_reset_events != 2 || env.sb_a.num_resets != 1)
      `uvm_error("AHB_RESET", $sformatf("reset seen %0d times, %0d events, %0d model clears",
                                        env.agent_a.cfg.observe.get_reset_count(),
                                        env.agent_a.monitor.num_reset_events,
                                        env.sb_a.num_resets))
    // Every item reached the bus except the aborted one, which must not be published.
    if (env.agent_a.cfg.observe.get_transfer_count() != env.agent_a.driver.num_sent - 1)
      `uvm_error("AHB_RESET", $sformatf("%0d bursts observed for %0d items sent (1 aborted)",
                                        env.agent_a.cfg.observe.get_transfer_count(),
                                        env.agent_a.driver.num_sent))
    if (env.agent_b.cfg.observe.get_reset_count() != 0)
      `uvm_error("AHB_RESET", "instance B saw a reset: reset leaked across instances")
    if (env.sb_a.num_checked == 0 || env.sb_b.num_checked == 0)
      `uvm_error("AHB_RESET", "a scoreboard checked no traffic")
  endfunction

endclass : ahb_reset_test
