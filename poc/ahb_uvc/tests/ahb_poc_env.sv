// -----------------------------------------------------------------------------
// ahb_poc_env — POC environment: instances of the same AHB UVC agent
//
// agent_a (DW=32) and agent_b (DW=64) always, each feeding its own fixture
// scoreboard with bursts and reset events. agent_p (passive observer of bus
// A) only when the integration registered a cfg for it; it has no
// scoreboard of its own — ahb_passive_test compares it with agent_a. This
// env is test code, not a reusable framework.
// Included by ahb_poc_test_pkg.
// -----------------------------------------------------------------------------

class ahb_poc_env extends uvm_env;
  `uvm_component_utils(ahb_poc_env)

  ahb_agent          agent_a;
  ahb_agent          agent_b;
  ahb_agent          agent_p;  // null unless the integration bound instance P
  ahb_poc_scoreboard sb_a;
  ahb_poc_scoreboard sb_b;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // agent_a, agent_b and their scoreboards always; agent_p only when the
  // integration code registered a cfg for it.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent_a = ahb_agent::type_id::create("agent_a", this);
    agent_b = ahb_agent::type_id::create("agent_b", this);
    sb_a    = ahb_poc_scoreboard::type_id::create("sb_a", this);
    sb_b    = ahb_poc_scoreboard::type_id::create("sb_b", this);
    if (uvm_config_db#(ahb_agent_cfg)::exists(this, "agent_p", "cfg"))
      agent_p = ahb_agent::type_id::create("agent_p", this);
  endfunction

  // Each active agent's monitor feeds its own scoreboard: bursts and reset events.
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent_a.monitor.ap.connect(sb_a.analysis_export);
    agent_a.monitor.reset_ap.connect(sb_a.reset_export);
    agent_b.monitor.ap.connect(sb_b.analysis_export);
    agent_b.monitor.reset_ap.connect(sb_b.reset_export);
  endfunction

endclass : ahb_poc_env
