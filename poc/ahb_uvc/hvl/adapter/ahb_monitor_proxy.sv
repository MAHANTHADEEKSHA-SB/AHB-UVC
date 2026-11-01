// -----------------------------------------------------------------------------
// ahb_monitor_proxy — concrete observe adapter for one bus specialization
//
// Holds a typed virtual handle to ahb_monitor_bfm_if with exactly the
// parameters of the bound instance (ADR-001 decision 2). receive() takes the
// next completed burst from the BFM (plain values, no UVM objects in HDL —
// ADR-002 section 6) and builds a new ahb_transaction from it, zero-extending
// every field to the transaction maxima with X/Z preserved.
// wait_reset_event() does the same for reset edges (RST-4).
//
// Built explicitly by the integration code (no factory, ADR-001 decision 5).
// Included by ahb_adapter_pkg.
// -----------------------------------------------------------------------------

class ahb_monitor_proxy #(
  int ADDR_WIDTH      = 32,
  int DATA_WIDTH      = 32,
  int MASTER_WIDTH    = 4,
  int USER_REQ_WIDTH  = 1,
  int USER_DATA_WIDTH = 1,
  int USER_RESP_WIDTH = 1,
  int QUEUE_DEPTH     = 16
) extends ahb_monitor_proxy_base;

  typedef virtual ahb_monitor_bfm_if #(
    .ADDR_WIDTH     (ADDR_WIDTH),
    .DATA_WIDTH     (DATA_WIDTH),
    .MASTER_WIDTH   (MASTER_WIDTH),
    .USER_REQ_WIDTH (USER_REQ_WIDTH),
    .USER_DATA_WIDTH(USER_DATA_WIDTH),
    .USER_RESP_WIDTH(USER_RESP_WIDTH),
    .QUEUE_DEPTH    (QUEUE_DEPTH)
  ) vif_t;

  protected vif_t          vif;
  protected ahb_features_t features;

  // Bind to exactly one monitor-BFM instance (explicit construction, ADR-001 decision
  // 5). A null handle or a bus wider than the transaction maxima is fatal (decision 4).
  function new(string name, vif_t vif);
    super.new(name);
    if (vif == null)
      `uvm_fatal("AHB_PROXY", $sformatf("%s: null monitor BFM handle", name))
    if (ADDR_WIDTH > AHB_MAX_AW || DATA_WIDTH > AHB_MAX_DW)
      `uvm_fatal("AHB_PROXY", $sformatf(
        "%s: bus AW=%0d DW=%0d exceeds maxima AW=%0d DW=%0d; set +define+AHB_MAX_*_WIDTH",
        name, ADDR_WIDTH, DATA_WIDTH, AHB_MAX_AW, AHB_MAX_DW))
    this.vif      = vif;
    this.features = ahb_default_features();
  endfunction

  // Physical parameters of the bound bus; ahb_agent_cfg compares them (CFG-03/04/06).
  virtual function int unsigned get_addr_width();
    return ADDR_WIDTH;
  endfunction

  virtual function int unsigned get_data_width();
    return DATA_WIDTH;
  endfunction

  // Forward the feature set to the BFM; keep a copy for the bus context of items.
  virtual function bit configure(ahb_features_t features);
    if (!vif.configure(features)) return 1'b0;
    this.features = features;
    return 1'b1;
  endfunction

  // Thin forwards to the bound BFM.
  virtual function void set_publish(bit en);
    vif.set_publish(en);
  endfunction

  virtual function void set_verbose(bit en);
    vif.set_verbose(en);
  endfunction

  // Block until the BFM reports a completed burst, then build a NEW transaction
  // (subscribers may keep the handle). Fields are zero-extended to the maxima with
  // X/Z kept (DATA-02, LANG-04). len and beats_done are the beats recorded; the
  // IDLE gap before the burst is not part of the observation and stays 0.
  virtual task receive(output ahb_transaction observed);
    bit                    write;
    logic [ADDR_WIDTH-1:0] addr;
    logic [2:0]            burst;
    logic [2:0]            size;
    logic [6:0]            prot;
    logic                  nonsec;
    logic                  lock;
    int unsigned           beats;
    logic [ADDR_WIDTH-1:0] baddr [AHB_MAX_BEATS];
    logic [DATA_WIDTH-1:0] wdata [AHB_MAX_BEATS];
    logic [DATA_WIDTH-1:0] rdata [AHB_MAX_BEATS];
    logic                  resp  [AHB_MAX_BEATS];
    int unsigned           waits [AHB_MAX_BEATS];
    int unsigned           busy  [AHB_MAX_BEATS];
    longint unsigned       start_cycle;
    longint unsigned       end_cycle;
    bit                    error_seen;

    vif.get_burst(write, addr, burst, size, prot, nonsec, lock, beats, baddr, wdata, rdata,
                  resp, waits, busy, start_cycle, end_cycle);

    observed = ahb_transaction::type_id::create("observed");
    observed.set_bus_context(ADDR_WIDTH, DATA_WIDTH, features.ext_mem_types,
                             features.secure_transfers);
    observed.instance_name = get_name();
    observed.dir           = write ? AHB_WRITE : AHB_READ;
    observed.addr          = AHB_MAX_AW'(addr);
    observed.burst         = ahb_burst_e'(burst);
    observed.size          = ahb_size_e'(size);
    observed.prot          = prot;
    observed.nonsec        = nonsec;
    observed.lock          = lock;
    observed.len           = beats;
    observed.beats_done    = beats;
    observed.idle_cycles   = 0;  // not part of the observation
    observed.wdata         = new[beats];
    observed.busy          = new[beats];
    observed.beat_addr     = new[beats];
    observed.rdata         = new[beats];
    observed.resp          = new[beats];
    observed.wait_states   = new[beats];
    error_seen             = 1'b0;
    for (int unsigned i = 0; i < beats; i++) begin
      observed.beat_addr[i]   = AHB_MAX_AW'(baddr[i]);
      observed.wdata[i]       = AHB_MAX_DW'(wdata[i]);
      observed.rdata[i]       = AHB_MAX_DW'(rdata[i]);
      observed.resp[i]        = resp[i];
      observed.wait_states[i] = waits[i];
      observed.busy[i]        = busy[i];
      if (resp[i] === 1'b1) error_seen = 1'b1;
    end
    observed.status      = error_seen ? AHB_ST_ERROR : AHB_ST_OK;
    observed.start_cycle = start_cycle;
    observed.end_cycle   = end_cycle;
  endtask

  // Block until the BFM reports a reset edge (RST-4); a new object per edge.
  virtual task wait_reset_event(output ahb_reset_event ev);
    bit              asserted;
    longint unsigned at_cycle;
    vif.get_reset_event(asserted, at_cycle);
    ev               = ahb_reset_event::type_id::create("reset_event");
    ev.asserted      = asserted;
    ev.cycle         = at_cycle;
    ev.instance_name = get_name();
  endtask

  // BFM counters, read by ahb_monitor in check_phase and report_phase.
  virtual function int unsigned get_error_count(ahb_mon_error_e code);
    return vif.get_error_count(code);
  endfunction

  virtual function int unsigned get_total_errors();
    return vif.get_total_errors();
  endfunction

  virtual function void clear_errors();
    vif.clear_errors();
  endfunction

  virtual function int unsigned get_transfer_count();
    return vif.transfer_count;
  endfunction

  virtual function int unsigned get_reset_count();
    return vif.reset_count;
  endfunction

endclass : ahb_monitor_proxy
