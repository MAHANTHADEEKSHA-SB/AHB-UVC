// -----------------------------------------------------------------------------
// ahb_driver — non-parameterized AHB Manager driver (ADR-001 decision 3)
//
// Uses only the abstract drive capability from ahb_agent_cfg; it never sees a
// virtual interface. One item is one burst. Items are updated in place with
// the response (beat addresses, rdata, resp, wait states, beats_done,
// status) before item_done(), so a sequence reads the result from the item
// it sent.
//
// Reset (RST-3/RST-5): after an item ends with AHB_ST_RESET_ABORTED the
// driver waits for reset release before taking the next item.
// Included by ahb_uvc_pkg.
// -----------------------------------------------------------------------------

class ahb_driver extends uvm_driver #(ahb_transaction);
  `uvm_component_utils(ahb_driver)

  ahb_agent_cfg cfg;  // set by ahb_agent
  int unsigned  num_sent;

  protected ahb_drive_proxy_base drive;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Take the drive capability from the cfg the agent passed in; an active agent
  // without one is a configuration error.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (cfg == null)
      `uvm_fatal("AHB_DRV", "ahb_agent_cfg not set by the agent")
    drive = cfg.drive;
    if (drive == null)
      `uvm_fatal("AHB_DRV", {cfg.get_name(), ": active agent without a drive proxy"})
  endfunction

  // Push the policies and the feature set to the adapter and BFM, then enable
  // driving: the bus leaves 'z at time 0, before the first reset release.
  virtual function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    drive.max_wait_cycles = cfg.max_wait_cycles;
    drive.allow_x_wdata   = cfg.allow_x_wdata;
    if (!drive.configure(cfg.features))
      `uvm_fatal("AHB_DRV", {cfg.get_name(), ": driver BFM rejected the feature set"})
    drive.set_enable(1'b1);
  endfunction

  // Wait for reset release (RST-5), then serve items until one is abandoned by reset
  // (RST-3), then wait for the next release. Each item is completed in place.
  virtual task run_phase(uvm_phase phase);
    forever begin
      drive.wait_for_reset_release(cfg.post_reset_idle_cycles);
      do begin
        seq_item_port.get_next_item(req);
        drive.send(req);
        num_sent++;
        report_result(req);
        seq_item_port.item_done();
      end while (req.status != AHB_ST_RESET_ABORTED);
    end
  endtask

  // Report each outcome at a severity that matches its status (UVM-09). An ERROR
  // response is a legal protocol outcome, not a UVC error; timeouts are errors, a
  // disabled BFM is fatal, rejections were already reported by the adapter.
  protected function void report_result(ahb_transaction t);
    case (t.status)
      AHB_ST_OK, AHB_ST_ERROR:
        `uvm_info("AHB_DRV", t.convert2string(), UVM_HIGH)
      AHB_ST_RESET_ABORTED:
        `uvm_info("AHB_DRV", {"abandoned by reset: ", t.convert2string()}, UVM_MEDIUM)
      AHB_ST_FAULT_INJECTED:
        `uvm_info("AHB_DRV", {"fault injected: ", t.convert2string()}, UVM_MEDIUM)
      AHB_ST_TIMEOUT:
        `uvm_error("AHB_TIMEOUT", $sformatf("HREADY LOW for %0d cycles: %s",
                                            cfg.max_wait_cycles, t.convert2string()))
      AHB_ST_NOT_ENABLED:
        `uvm_fatal("AHB_DRV", {"driver BFM not enabled: ", t.convert2string()})
      default:  // AHB_ST_BAD_REQUEST: the adapter already reported why
        `uvm_info("AHB_DRV", {"rejected: ", t.convert2string()}, UVM_MEDIUM)
    endcase
  endfunction

endclass : ahb_driver
