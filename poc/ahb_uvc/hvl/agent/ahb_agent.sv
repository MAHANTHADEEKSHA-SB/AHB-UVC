// -----------------------------------------------------------------------------
// ahb_agent — non-parameterized AHB UVC agent (ADR-001 decision 3)
//
// Retrieves its ahb_agent_cfg ONCE from uvm_config_db (field "cfg", exact
// agent path) and passes it to its children (ADR-002 configuration flow,
// step 4). The monitor and optional coverage are always built; the sequencer
// and driver only when cfg.is_active == UVM_ACTIVE. Passive mode is a
// runtime choice and does not change what is compiled (ADR-002 decision 9).
// Included by ahb_uvc_pkg.
// -----------------------------------------------------------------------------

class ahb_agent extends uvm_agent;
  `uvm_component_utils(ahb_agent)

  ahb_agent_cfg                        cfg;
  ahb_sequencer                        sequencer;
  ahb_driver                           driver;
  ahb_monitor                          monitor;
  ahb_coverage                         coverage;
  uvm_analysis_port #(ahb_transaction) ap;        // the monitor's ports, re-exported
  uvm_analysis_port #(ahb_reset_event) reset_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Get this instance's cfg once (ADR-002 flow, step 4) and validate it. Build the
  // monitor (and coverage) always; the sequencer and driver only when active. The
  // children get the cfg handle directly and never query uvm_config_db (UVM-06).
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ahb_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AHB_AGENT", {"no ahb_agent_cfg registered for ", get_full_name()})
    cfg.validate();
    `uvm_info("AHB_AGENT", cfg.convert2string(), UVM_LOW)

    monitor     = ahb_monitor::type_id::create("monitor", this);
    monitor.cfg = cfg;
    if (cfg.enable_coverage) begin
      coverage     = ahb_coverage::type_id::create("coverage", this);
      coverage.cfg = cfg;
    end
    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer     = ahb_sequencer::type_id::create("sequencer", this);
      sequencer.cfg = cfg;
      driver        = ahb_driver::type_id::create("driver", this);
      driver.cfg    = cfg;
    end
  endfunction

  // Re-export the monitor's ports, feed coverage, connect driver and sequencer.
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ap       = monitor.ap;
    reset_ap = monitor.reset_ap;
    if (coverage != null) monitor.ap.connect(coverage.analysis_export);
    if (driver != null)   driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass : ahb_agent
