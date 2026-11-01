// -----------------------------------------------------------------------------
// ahb_drive_proxy — concrete drive adapter for one bus specialization
//
// Holds a typed virtual handle to ahb_driver_bfm_if with exactly the
// parameters of the bound instance (ADR-001 decision 2) and converts the
// width-independent ahb_transaction into a BFM do_burst() call.
//
// Boundary rules (ADR-001 decision 4, AHB_PROTOCOL_CONTRACT section 6):
//   * a null handle, or a bus wider than the transaction maxima, is fatal at
//     construction
//   * a request that cannot be driven losslessly or legally is rejected with
//     uvm_error and status AHB_ST_BAD_REQUEST; nothing is truncated and
//     nothing reaches the bus
//
// Built explicitly by the integration code (no factory, ADR-001 decision 5).
// Included by ahb_adapter_pkg.
// -----------------------------------------------------------------------------

class ahb_drive_proxy #(
  int ADDR_WIDTH      = 32,
  int DATA_WIDTH      = 32,
  int MASTER_WIDTH    = 4,
  int USER_REQ_WIDTH  = 1,
  int USER_DATA_WIDTH = 1,
  int USER_RESP_WIDTH = 1
) extends ahb_drive_proxy_base;

  typedef virtual ahb_driver_bfm_if #(
    .ADDR_WIDTH     (ADDR_WIDTH),
    .DATA_WIDTH     (DATA_WIDTH),
    .MASTER_WIDTH   (MASTER_WIDTH),
    .USER_REQ_WIDTH (USER_REQ_WIDTH),
    .USER_DATA_WIDTH(USER_DATA_WIDTH),
    .USER_RESP_WIDTH(USER_RESP_WIDTH)
  ) vif_t;

  protected vif_t          vif;
  protected ahb_features_t features;

  // Bind to exactly one driver-BFM instance (explicit construction, ADR-001 decision
  // 5). A null handle or a bus wider than the transaction maxima is fatal (decision 4).
  function new(string name, vif_t vif);
    super.new(name);
    if (vif == null)
      `uvm_fatal("AHB_PROXY", $sformatf("%s: null driver BFM handle", name))
    if (ADDR_WIDTH > AHB_MAX_AW || DATA_WIDTH > AHB_MAX_DW)
      `uvm_fatal("AHB_PROXY", $sformatf(
        "%s: bus AW=%0d DW=%0d exceeds maxima AW=%0d DW=%0d; set +define+AHB_MAX_*_WIDTH",
        name, ADDR_WIDTH, DATA_WIDTH, AHB_MAX_AW, AHB_MAX_DW))
    this.vif      = vif;
    this.features = ahb_default_features();
  endfunction

  // Physical parameters of the bound bus; ahb_agent_cfg compares them (CFG-06).
  virtual function int unsigned get_addr_width();
    return ADDR_WIDTH;
  endfunction

  virtual function int unsigned get_data_width();
    return DATA_WIDTH;
  endfunction

  // Forward the feature set to the BFM and keep a copy for request_ok(); 0 when the
  // BFM rejects it (for example a milestone M2/M3 feature).
  virtual function bit configure(ahb_features_t features);
    if (!vif.configure(features)) return 1'b0;
    this.features = features;
    return 1'b1;
  endfunction

  // Thin forwards to the bound BFM.
  virtual function void set_enable(bit en);
    vif.set_enable(en);
  endfunction

  virtual function void set_fault(ahb_fault_e fault);
    vif.set_fault(fault);
  endfunction

  virtual task wait_for_reset_release(int unsigned idle_cycles);
    vif.wait_for_reset_release(idle_cycles);
  endtask

  // Run one burst for req: stamp the bus context, reject anything that cannot be
  // driven losslessly or legally (AHB_ST_BAD_REQUEST, nothing on the bus), convert
  // to the bus width, and write the per-beat response back into req.
  virtual task send(ahb_transaction req);
    logic [DATA_WIDTH-1:0] wdata [AHB_MAX_BEATS];
    int unsigned           busy  [AHB_MAX_BEATS];
    logic [ADDR_WIDTH-1:0] baddr [AHB_MAX_BEATS];
    logic [DATA_WIDTH-1:0] rdata [AHB_MAX_BEATS];
    logic                  resp  [AHB_MAX_BEATS];
    int unsigned           waits [AHB_MAX_BEATS];
    int unsigned           done;
    ahb_bfm_status_e       st;

    req.instance_name = get_name();
    req.set_bus_context(ADDR_WIDTH, DATA_WIDTH, features.ext_mem_types,
                        features.secure_transfers);
    req.beats_done = 0;
    req.beat_addr.delete();
    req.rdata.delete();
    req.resp.delete();
    req.wait_states.delete();
    if (!request_ok(req)) begin
      req.status = AHB_ST_BAD_REQUEST;
      return;
    end

    // Narrow each beat to the bus width; request_ok() proved the upper bits are 0.
    for (int unsigned i = 0; i < AHB_MAX_BEATS; i++) begin
      wdata[i] = '0;
      busy[i]  = 0;
      if (i < req.len) begin
        if (req.dir == AHB_WRITE) wdata[i] = DATA_WIDTH'(req.wdata[i]);
        busy[i] = req.busy[i];
      end
    end

    vif.do_burst(req.dir == AHB_WRITE, ADDR_WIDTH'(req.addr), req.burst, req.size, req.len,
                 req.prot, req.nonsec, req.lock, wdata, busy, req.idle_cycles,
                 max_wait_cycles, baddr, rdata, resp, waits, done, st);

    req.beat_addr   = new[req.len];
    req.rdata       = new[req.len];
    req.resp        = new[req.len];
    req.wait_states = new[req.len];
    for (int unsigned i = 0; i < req.len; i++) begin
      req.beat_addr[i]   = AHB_MAX_AW'(baddr[i]);
      req.rdata[i]       = AHB_MAX_DW'(rdata[i]);  // zero-extended, 4-state preserved
      req.resp[i]        = resp[i];
      req.wait_states[i] = waits[i];
    end
    req.beats_done = done;
    req.status     = st;
  endtask

  // Every reason a request cannot be driven as written; reports each one.
  protected function bit request_ok(ahb_transaction req);
    bit                   ok = 1'b1;
    logic [AHB_FN_AW-1:0] first;
    logic [AHB_FN_AW-1:0] last;

    if ($isunknown(req.addr) || $isunknown(req.prot) || $isunknown(req.nonsec) ||
        $isunknown(req.lock)) begin
      `uvm_error("AHB_REQ", {get_name(), ": X/Z in addr/prot/nonsec/lock: ",
                             req.convert2string()})
      return 1'b0;  // the checks below need known values
    end
    if (req.len == 0 || req.len > AHB_MAX_BEATS) begin                  // POL-04
      `uvm_error("AHB_REQ", $sformatf("%s: len %0d outside 1..%0d", get_name(), req.len,
                                      AHB_MAX_BEATS))
      return 1'b0;
    end
    if (req.wdata.size() != req.len || req.busy.size() != req.len) begin
      `uvm_error("AHB_REQ", $sformatf("%s: wdata/busy sizes %0d/%0d differ from len %0d",
                                      get_name(), req.wdata.size(), req.busy.size(), req.len))
      return 1'b0;
    end
    if (req.burst != AHB_BURST_INCR && req.len != ahb_burst_beats(req.burst)) begin  // R09
      `uvm_error("AHB_REQ", $sformatf("%s: %s needs %0d beats, len is %0d", get_name(),
                                      req.burst.name(), ahb_burst_beats(req.burst), req.len))
      ok = 1'b0;
    end
    if (req.busy[0] != 0) begin                                         // AHB-R04
      `uvm_error("AHB_REQ", $sformatf("%s: BUSY before the first beat", get_name()))
      ok = 1'b0;
    end
    foreach (req.wdata[i]) begin
      if (req.dir == AHB_WRITE && !allow_x_wdata && $isunknown(req.wdata[i])) begin
        `uvm_error("AHB_REQ", $sformatf("%s: X/Z in write data beat %0d", get_name(), i))
        ok = 1'b0;
      end
      // Lossless rule (DATA-02): every bit at or above the bus width must be a known 0
      if (!upper_bits_zero_data(req.wdata[i])) begin
        `uvm_error("AHB_REQ", $sformatf("%s: wdata[%0d] %0h does not fit DW=%0d",
                                        get_name(), i, req.wdata[i], DATA_WIDTH))
        ok = 1'b0;
      end
    end
    if (!upper_bits_zero_addr(req.addr)) begin
      `uvm_error("AHB_REQ", $sformatf("%s: addr %0h does not fit AW=%0d",
                                      get_name(), req.addr, ADDR_WIDTH))
      ok = 1'b0;
    end
    if (req.beat_bytes() > DATA_WIDTH / 8) begin                        // AHB-R06
      `uvm_error("AHB_REQ", $sformatf("%s: HSIZE %s is wider than DW=%0d",
                                      get_name(), req.size.name(), DATA_WIDTH))
      return 1'b0;  // the alignment and page checks assume a legal size
    end
    if ((req.addr % req.beat_bytes()) != 0) begin                       // AHB-R07
      `uvm_error("AHB_REQ", $sformatf("%s: addr %0h not aligned to %0d bytes",
                                      get_name(), req.addr, req.beat_bytes()))
      ok = 1'b0;
    end
    first = AHB_FN_AW'(req.addr);
    last  = first + AHB_FN_AW'(req.len * req.beat_bytes()) - 1;
    if (ahb_burst_is_wrap(req.burst) ? (req.len * req.beat_bytes() > 1024)
                                     : ahb_crosses_1kb(first, last)) begin  // AHB-R08
      `uvm_error("AHB_REQ", $sformatf("%s: burst at %0h crosses a 1KB boundary",
                                      get_name(), req.addr))
      ok = 1'b0;
    end
    if (!features.ext_mem_types && req.prot[6:4] != 3'b000) begin       // POL-03
      `uvm_error("AHB_REQ", $sformatf("%s: prot %0b but HPROT[6:4] is absent",
                                      get_name(), req.prot))
      ok = 1'b0;
    end
    if (!features.secure_transfers && req.nonsec != 1'b0) begin         // POL-03
      `uvm_error("AHB_REQ", $sformatf("%s: nonsec set but HNONSEC is absent", get_name()))
      ok = 1'b0;
    end
    return ok;
  endfunction

  // 1 when every bit at index >= the bus width is a known 0. Written as a loop
  // rather than `value >> WIDTH`, which would shift by the full operand width
  // whenever the bus is as wide as the transaction (LANG-05).
  protected function bit upper_bits_zero_addr(logic [AHB_MAX_AW-1:0] value);
    for (int unsigned i = ADDR_WIDTH; i < AHB_MAX_AW; i++)
      if (value[i] !== 1'b0) return 1'b0;
    return 1'b1;
  endfunction

  protected function bit upper_bits_zero_data(logic [AHB_MAX_DW-1:0] value);
    for (int unsigned i = DATA_WIDTH; i < AHB_MAX_DW; i++)
      if (value[i] !== 1'b0) return 1'b0;
    return 1'b1;
  endfunction

endclass : ahb_drive_proxy
