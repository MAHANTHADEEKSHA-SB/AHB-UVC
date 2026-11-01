// -----------------------------------------------------------------------------
// ahb_drive_proxy_base — abstract AHB drive capability (ADR-001, ADR-002)
//
// Not parameterized by bus width. The UVM driver holds only this handle; a
// width-specialized adapter (ahb_adapter_pkg::ahb_drive_proxy) implements it
// over a typed virtual driver-BFM handle. A monitor never receives this type.
// Included by ahb_api_pkg.
// -----------------------------------------------------------------------------

virtual class ahb_drive_proxy_base extends uvm_object;

  // Policies copied from ahb_agent_cfg by the driver (AHB_PROTOCOL_CONTRACT)
  int unsigned max_wait_cycles = 1024;  // POL-01: TIMEOUT after this many LOW cycles; 0 = off
  bit          allow_x_wdata   = 1'b0;  // section 6: X/Z write data only for fault injection

  function new(string name = "ahb_drive_proxy_base");
    super.new(name);
  endfunction

  // Physical parameters of the bound bus (CFG-06 cross-checks)
  pure virtual function int unsigned get_addr_width();
  pure virtual function int unsigned get_data_width();

  // Push the instance feature set to the BFM; 0 = rejected
  pure virtual function bit configure(ahb_features_t features);

  // 1: drive the bus; 0: release every Manager output to 'z
  pure virtual function void set_enable(bit en);

  // Deliberate protocol faults for negative tests
  pure virtual function void set_fault(ahb_fault_e fault);

  // RST-5: return once reset is released, plus idle_cycles HCLK edges
  pure virtual task wait_for_reset_release(int unsigned idle_cycles);

  // Run one burst. Fills req.beat_addr, rdata, resp, wait_states, beats_done and
  // status (AHB_ST_BAD_REQUEST when the request cannot be driven losslessly).
  pure virtual task send(ahb_transaction req);

endclass : ahb_drive_proxy_base
