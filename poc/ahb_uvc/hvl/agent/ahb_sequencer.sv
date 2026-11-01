// -----------------------------------------------------------------------------
// ahb_sequencer — non-parameterized AHB sequencer
//
// Carries the instance configuration so sequences can give their items the
// bus context (widths, present features) before randomization.
// Included by ahb_uvc_pkg.
// -----------------------------------------------------------------------------

class ahb_sequencer extends uvm_sequencer #(ahb_transaction);
  `uvm_component_utils(ahb_sequencer)

  ahb_agent_cfg cfg;  // set by ahb_agent before build_phase of this component

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : ahb_sequencer
