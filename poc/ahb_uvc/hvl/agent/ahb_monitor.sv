// -----------------------------------------------------------------------------
// ahb_monitor — non-parameterized passive AHB monitor (ADR-001 decision 3)
//
// Uses only the abstract observe capability from ahb_agent_cfg. Works the
// same whether or not the agent is active, because the monitor BFM only
// reads pins (ADR-002 decision 9). Each completed burst is published once on
// `ap`; every reset edge after the first release is published on `reset_ap`
// (RST-4), so subscribers can clear their models.
//
// Protocol violations are counted in the BFM and reported in check_phase as
// uvm_error with ID "AHB_PROTOCOL", one line per violation type. A negative
// test that expects them demotes that ID on this component and checks the
// counts through cfg.observe itself.
// Included by ahb_uvc_pkg.
// -----------------------------------------------------------------------------

class ahb_monitor extends uvm_monitor;
  `uvm_component_utils(ahb_monitor)

  ahb_agent_cfg                        cfg;  // set by ahb_agent
  uvm_analysis_port #(ahb_transaction) ap;
  uvm_analysis_port #(ahb_reset_event) reset_ap;
  int unsigned                         num_observed;
  int unsigned                         num_reset_events;

  protected ahb_monitor_proxy_base observe;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Create the analysis ports and take the observe capability from the cfg.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap       = new("ap", this);
    reset_ap = new("reset_ap", this);
    if (cfg == null)
      `uvm_fatal("AHB_MON", "ahb_agent_cfg not set by the agent")
    observe = cfg.observe;
    if (observe == null)
      `uvm_fatal("AHB_MON", {cfg.get_name(), ": no observe proxy"})
  endfunction

  // Configure the BFM with the instance's feature set, then enable publishing now
  // that this consumer exists.
  virtual function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    observe.set_verbose(cfg.monitor_verbose);
    if (!observe.configure(cfg.features))
      `uvm_fatal("AHB_MON", {cfg.get_name(), ": monitor BFM rejected the feature set"})
    observe.set_publish(1'b1);
  endfunction

  // Two independent consumers of the BFM queues: one receive() per completed
  // burst, published once on ap; one wait_reset_event() per reset edge (RST-4).
  virtual task run_phase(uvm_phase phase);
    fork
      forever begin
        ahb_transaction t;
        observe.receive(t);
        num_observed++;
        `uvm_info("AHB_MON", t.convert2string(), UVM_HIGH)
        ap.write(t);
      end
      forever begin
        ahb_reset_event ev;
        observe.wait_reset_event(ev);
        num_reset_events++;
        `uvm_info("AHB_MON", ev.convert2string(), UVM_MEDIUM)
        reset_ap.write(ev);
      end
    join
  endtask

  // One AHB_PROTOCOL error per violation type counted by the BFM. Negative tests
  // demote this ID on this component and check the counts themselves (UVM-13).
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    for (int c = 0; c < AHB_MON_NUM_ERRORS; c++) begin
      ahb_mon_error_e code = ahb_mon_error_e'(c);
      int unsigned    n    = observe.get_error_count(code);
      if (n != 0)
        `uvm_error("AHB_PROTOCOL", $sformatf("%s: %0d x %s", cfg.get_name(), n, code.name()))
    end
  endfunction

  // Summary: bursts observed, resets seen, violations counted.
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("AHB_MON", $sformatf("%s: %0d bursts observed, %0d resets, %0d protocol errors",
                                   cfg.get_name(), num_observed, observe.get_reset_count(),
                                   observe.get_total_errors()), UVM_LOW)
  endfunction

endclass : ahb_monitor
