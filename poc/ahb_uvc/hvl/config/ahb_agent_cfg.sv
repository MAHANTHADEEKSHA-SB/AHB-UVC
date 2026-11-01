// -----------------------------------------------------------------------------
// ahb_agent_cfg — configuration of ONE AHB UVC instance (ADR-002 decision 6)
//
// Carries the two base-class capability handles, the active/passive policy,
// the revision/feature set and the UVC policies. The integration code fills
// one object per instance and registers it once with
//   uvm_config_db#(ahb_agent_cfg)::set(null, "<exact agent path>", "cfg", cfg)
// The agent retrieves it once and hands it to its children. Never share an
// object between instances.
//
// validate() enforces AHB_PROTOCOL_CONTRACT section 2.3 (CFG-01..04, CFG-06)
// and the milestone M1 feature limits; legality_error() returns the same
// verdict as text so negative tests can check it without a fatal.
// Included by ahb_uvc_pkg.
// -----------------------------------------------------------------------------

class ahb_agent_cfg extends uvm_object;
  `uvm_object_utils(ahb_agent_cfg)

  // Capability handles: drive may stay null on a passive instance
  ahb_drive_proxy_base    drive;
  ahb_monitor_proxy_base  observe;

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // Revision and AHB5 interface properties (proposed default: AHB5, no option)
  ahb_features_t          features;

  // Policies (AHB_PROTOCOL_CONTRACT sections 4-6)
  int unsigned            max_wait_cycles        = 1024;  // POL-01; 0 = no watchdog
  int unsigned            post_reset_idle_cycles = 1;     // RST-5
  bit                     allow_x_wdata          = 1'b0;  // section 6
  bit                     enable_coverage        = 1'b1;
  bit                     monitor_verbose        = 1'b1;  // BFM prints each violation

  // Default feature set (AHB_PROTOCOL_CONTRACT Q2, proposed).
  function new(string name = "ahb_agent_cfg");
    super.new(name);
    features = ahb_default_features();
  endfunction

  // Physical bus parameters, taken from the observe adapter
  function int unsigned addr_width();
    return (observe == null) ? 0 : observe.get_addr_width();
  endfunction

  function int unsigned data_width();
    return (observe == null) ? 0 : observe.get_data_width();
  endfunction

  // "" when the configuration is legal, otherwise the first problem found
  function string legality_error();
    int unsigned aw;
    int unsigned dw;
    string       problem;

    if (observe == null)
      return "no observe (monitor) proxy bound";
    if (is_active == UVM_ACTIVE && drive == null)
      return "active agent without a drive proxy";

    aw = observe.get_addr_width();
    dw = observe.get_data_width();

    // CFG-06: both adapters must be bound to the same bus specialization
    if (drive != null && (drive.get_addr_width() != aw || drive.get_data_width() != dw))
      return $sformatf("CFG-06: drive proxy AW=%0d DW=%0d, observe proxy AW=%0d DW=%0d",
                       drive.get_addr_width(), drive.get_data_width(), aw, dw);
    // CFG-03: address width (IHI 0033C ADDR_WIDTH; fixed at 32 in IHI 0033A)
    if (aw < 1 || aw > 64)
      return $sformatf("CFG-03: ADDR_WIDTH=%0d outside 1..64", aw);
    if (features.revision == AHB_LITE && aw != 32)
      return $sformatf("CFG-03: AHB-Lite fixes ADDR_WIDTH at 32, bus has %0d", aw);
    // CFG-04: IHI 0033C DATA_WIDTH
    if (!(dw inside {8, 16, 32, 64, 128, 256, 512, 1024}))
      return $sformatf("CFG-04: DATA_WIDTH=%0d not in {8,16,...,1024}", dw);
    // CFG-01: AHB5 interface properties need revision AHB5
    problem = ahb_revision_problem(features);
    if (problem != "") return {"CFG-01: ", problem};
    // CFG-02: features of later milestones
    problem = ahb_milestone_problem(features);
    if (problem != "") return {"CFG-02: ", problem};
    return "";
  endfunction

  // Fatal on any legality_error() (UVM-08). Warnings only for a passive agent that
  // still has a drive proxy and for widths outside the IHI 0033C recommendations.
  function void validate();
    string problem = legality_error();
    if (problem != "")
      `uvm_fatal("AHB_CFG", {get_name(), ": ", problem})
    if (is_active == UVM_PASSIVE && drive != null)
      `uvm_warning("AHB_CFG",
                   {get_name(), ": passive agent has a drive proxy; it will not be used"})
    if (features.revision == AHB5 && addr_width() < 10)
      `uvm_warning("AHB_CFG", $sformatf("%s: ADDR_WIDTH=%0d below the recommended 10..64",
                                        get_name(), addr_width()))
    if (data_width() < 32 || data_width() > 256)
      `uvm_warning("AHB_CFG", $sformatf("%s: DATA_WIDTH=%0d outside the recommended 32..256",
                                        get_name(), data_width()))
  endfunction

  // One-line summary, printed by ahb_agent at build time.
  virtual function string convert2string();
    return $sformatf("%s: %s %s AW=%0d DW=%0d hprot_bits=%0d nonsec=%0b max_wait=%0d",
                     get_name(), is_active.name(), features.revision.name(), addr_width(),
                     data_width(), ahb_prot_width(features), features.secure_transfers,
                     max_wait_cycles);
  endfunction

endclass : ahb_agent_cfg
