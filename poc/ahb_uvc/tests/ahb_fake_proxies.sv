// -----------------------------------------------------------------------------
// ahb_fake_proxies — test doubles of the two capability classes
//
// Report any widths without an HDL instance, so ahb_cfg_negative_test can
// exercise ahb_agent_cfg legality checks (CFG-01..04, CFG-06) for widths that
// cannot be instantiated legally. Never connected to a bus.
// Contains ahb_fake_drive_proxy and ahb_fake_monitor_proxy (FILE-02 helpers).
// Included by ahb_poc_test_pkg.
// -----------------------------------------------------------------------------

class ahb_fake_drive_proxy extends ahb_drive_proxy_base;
  int unsigned aw = 32;
  int unsigned dw = 32;

  function new(string name = "ahb_fake_drive_proxy");
    super.new(name);
  endfunction

  // The width getters return the knobs above; every other method is an inert stub.
  virtual function int unsigned get_addr_width();
    return aw;
  endfunction

  virtual function int unsigned get_data_width();
    return dw;
  endfunction

  virtual function bit configure(ahb_features_t features);
    return 1'b1;
  endfunction

  virtual function void set_enable(bit en);
  endfunction

  virtual function void set_fault(ahb_fault_e fault);
  endfunction

  virtual task wait_for_reset_release(int unsigned idle_cycles);
  endtask

  virtual task send(ahb_transaction req);
    req.status = AHB_ST_NOT_ENABLED;
  endtask
endclass : ahb_fake_drive_proxy


// Observe-side double with the same width knobs; it never receives anything.
class ahb_fake_monitor_proxy extends ahb_monitor_proxy_base;
  int unsigned aw = 32;
  int unsigned dw = 32;

  function new(string name = "ahb_fake_monitor_proxy");
    super.new(name);
  endfunction

  // The width getters return the knobs above; every other method is an inert stub.
  virtual function int unsigned get_addr_width();
    return aw;
  endfunction

  virtual function int unsigned get_data_width();
    return dw;
  endfunction

  virtual function bit configure(ahb_features_t features);
    return 1'b1;
  endfunction

  virtual function void set_publish(bit en);
  endfunction

  virtual function void set_verbose(bit en);
  endfunction

  virtual task receive(output ahb_transaction observed);
    observed = null;
  endtask

  virtual task wait_reset_event(output ahb_reset_event ev);
    ev = null;
  endtask

  virtual function int unsigned get_error_count(ahb_mon_error_e code);
    return 0;
  endfunction

  virtual function int unsigned get_total_errors();
    return 0;
  endfunction

  virtual function void clear_errors();
  endfunction

  virtual function int unsigned get_transfer_count();
    return 0;
  endfunction

  virtual function int unsigned get_reset_count();
    return 0;
  endfunction
endclass : ahb_fake_monitor_proxy
