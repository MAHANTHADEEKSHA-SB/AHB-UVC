// -----------------------------------------------------------------------------
// ahb_negative_tests — configuration and boundary negative tests
//
// ahb_cfg_negative_test: ahb_agent_cfg::legality_error() must reject every
//   illegal configuration of AHB_PROTOCOL_CONTRACT CFG-01..04 and CFG-06
//   (including cross-wired adapters of different widths) and accept the
//   legal ones. Uses the fake proxies, so no bus traffic is involved.
// ahb_width_negative_test: a write whose data does not fit the DW=32 bus
//   must be rejected by the drive adapter (status AHB_ST_BAD_REQUEST) and
//   must never reach the bus — no silent truncation (RISK-003).
// Included by ahb_poc_test_pkg.
// -----------------------------------------------------------------------------

class ahb_cfg_negative_test extends ahb_poc_base_test;
  `uvm_component_utils(ahb_cfg_negative_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Each case builds a fresh cfg on fake proxies and checks legality_error(); no
  // fatal is raised, so every case runs and reports.
  virtual task run_phase(uvm_phase phase);
    ahb_agent_cfg c;
    phase.raise_objection(this);

    // Legal widths
    c = make_cfg(32, 32, 32, 32);
    expect_verdict("AHB5 DW=32", c, "");

    c = make_cfg(32, 64, 32, 64);
    expect_verdict("AHB5 DW=64", c, "");

    // CFG-06: adapters bound to different bus specializations
    c = make_cfg(32, 32, 32, 64);
    expect_verdict("cross-wired DW=32/64", c, "CFG-06");

    // CFG-03 / CFG-04: widths outside IHI 0033C
    c = make_cfg(65, 32, 65, 32);
    expect_verdict("AW=65", c, "CFG-03");

    c = make_cfg(24, 32, 24, 32);
    c.features.revision = AHB_LITE;
    expect_verdict("AHB-Lite AW=24", c, "CFG-03");

    c = make_cfg(32, 24, 32, 24);
    expect_verdict("DW=24", c, "CFG-04");

    c = make_cfg(32, 2048, 32, 2048);
    expect_verdict("DW=2048", c, "CFG-04");

    // CFG-01: AHB5 interface properties need revision AHB5
    c = make_cfg(32, 32, 32, 32);
    c.features.revision = AHB_LITE;
    expect_verdict("AHB-Lite", c, "");

    c = make_cfg(32, 32, 32, 32);
    c.features.revision         = AHB_LITE;
    c.features.secure_transfers = 1'b1;
    expect_verdict("AHB-Lite with HNONSEC", c, "CFG-01");

    c = make_cfg(32, 32, 32, 32);
    c.features.ext_mem_types    = 1'b1;
    c.features.secure_transfers = 1'b1;
    expect_verdict("AHB5 HPROT[6:4] + HNONSEC", c, "");

    // CFG-02: features of later milestones
    c = make_cfg(32, 32, 32, 32);
    c.features.exclusive_transfers = 1'b1;
    expect_verdict("AHB5 exclusive (M2)", c, "CFG-02");

    c = make_cfg(32, 32, 32, 32);
    c.features.write_strobes = 1'b1;
    expect_verdict("AHB5 write strobes (M2)", c, "CFG-02");

    c = make_cfg(32, 32, 32, 32);
    c.features.check_type = AHB_CHECK_ODD_PARITY_BYTE_ALL;
    expect_verdict("AHB5 parity (M3)", c, "CFG-02");

    // Capability handles
    c = make_cfg(32, 32, 32, 32);
    c.drive = null;
    expect_verdict("active without drive", c, "active agent");

    c = make_cfg(32, 32, 32, 32);
    c.drive     = null;
    c.is_active = UVM_PASSIVE;
    expect_verdict("passive without drive", c, "");

    c = make_cfg(32, 32, 32, 32);
    c.observe = null;
    expect_verdict("no observe proxy", c, "no observe");

    phase.drop_objection(this);
  endtask

  // Fresh cfg (default AHB5 features) whose fake proxies report the given widths.
  protected function ahb_agent_cfg make_cfg(int unsigned drive_aw, int unsigned drive_dw,
                                            int unsigned observe_aw, int unsigned observe_dw);
    ahb_agent_cfg          c = ahb_agent_cfg::type_id::create("cfg_under_test");
    ahb_fake_drive_proxy   d = new("fake_drive");
    ahb_fake_monitor_proxy m = new("fake_observe");
    d.aw = drive_aw;
    d.dw = drive_dw;
    m.aw = observe_aw;
    m.dw = observe_dw;
    c.drive   = d;
    c.observe = m;
    return c;
  endfunction

  // want == "" means legal; otherwise the verdict must start with want
  protected function void expect_verdict(string what, ahb_agent_cfg c, string want);
    string got = c.legality_error();
    bit    ok  = (want == "") ? (got == "") : (got.substr(0, want.len() - 1) == want);
    if (ok)
      `uvm_info("AHB_CFG_NEG", $sformatf("ok: %s -> \"%s\"", what, got), UVM_LOW)
    else
      `uvm_error("AHB_CFG_NEG", $sformatf("FAIL: %s -> \"%s\", expected %s", what, got,
                                          want == "" ? "legal" : {"\"", want, "...\""}))
  endfunction

endclass : ahb_cfg_negative_test


// Builds the POC env and drives one unfit write on instance A (DW=32).
class ahb_width_negative_test extends ahb_poc_base_test;
  `uvm_component_utils(ahb_width_negative_test)

  ahb_poc_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Full POC env: real adapters on the real bus.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = ahb_poc_env::type_id::create("env", this);
  endfunction

  // Pass if the adapter rejected the write (AHB_ST_BAD_REQUEST) and the monitor saw
  // nothing on the bus: no silent truncation (DATA-02, RISK-003).
  virtual task run_phase(uvm_phase phase);
    ahb_unfit_write_seq seq = ahb_unfit_write_seq::type_id::create("unfit");
    phase.raise_objection(this);
    // The adapter's rejection is the expected outcome (reported via uvm_root)
    uvm_root::get().set_report_severity_id_override(UVM_ERROR, "AHB_REQ", UVM_INFO);
    seq.start(env.agent_a.sequencer);
    #200ns;
    if (seq.result.status != AHB_ST_BAD_REQUEST)
      `uvm_error("AHB_WIDTH_NEG", {"unfit write was not rejected: ", seq.result.convert2string()})
    if (env.agent_a.cfg.observe.get_transfer_count() != 0)
      `uvm_error("AHB_WIDTH_NEG", "unfit write reached the bus")
    phase.drop_objection(this);
  endtask

endclass : ahb_width_negative_test
