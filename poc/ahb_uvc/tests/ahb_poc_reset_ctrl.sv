// -----------------------------------------------------------------------------
// ahb_poc_reset_ctrl — abstract handle for pulsing an instance's reset
//
// A package cannot hold hierarchical references to the design, so tests reach
// the reset generators of examples/ahb_hdl_top through this capability. The
// HVL top implements it (it may use hierarchical references, LANG-12) and
// registers it under uvm_test_top, field "reset_ctrl". Test code only.
// Included by ahb_poc_test_pkg.
// -----------------------------------------------------------------------------

virtual class ahb_poc_reset_ctrl extends uvm_object;

  function new(string name = "ahb_poc_reset_ctrl");
    super.new(name);
  endfunction

  // Assert HRESETn of instance inst ("a" or "b") now, release it on a falling
  // HCLK edge after `cycles` rising edges (RST-2).
  pure virtual task pulse_reset(string inst, int unsigned cycles);

endclass : ahb_poc_reset_ctrl
