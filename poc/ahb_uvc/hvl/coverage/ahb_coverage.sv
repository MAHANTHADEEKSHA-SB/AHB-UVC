// -----------------------------------------------------------------------------
// ahb_coverage — functional coverage of observed AHB bursts
//
// Protocol-level coverage only (no DUT memory map): direction, HBURST,
// transfer size relative to the bus width, INCR length, wait states, ERROR
// responses, BUSY insertion, back-to-back bursts, HPROT[3:0] and HMASTLOCK,
// with the crosses the CLAUDE_GENERATION_PROMPT checks call for. Connected
// to the monitor's analysis port by ahb_agent when cfg.enable_coverage is set.
// Reset transitions are not covered yet (WORK_STATUS gap list).
// Included by ahb_uvc_pkg.
// -----------------------------------------------------------------------------

class ahb_coverage extends uvm_subscriber #(ahb_transaction);
  `uvm_component_utils(ahb_coverage)

  // Transfer size relative to the bus: one byte lane, a narrower transfer, or
  // every lane. Width-independent, so every bin is reachable on every instance.
  typedef enum { SIZE_BYTE, SIZE_NARROW, SIZE_FULL } size_kind_e;

  ahb_agent_cfg cfg;  // set by ahb_agent

  protected longint unsigned prev_end;
  protected bit              has_prev;

  // Sampled once per observed burst. b2b: the NONSEQ was accepted no later than one
  // cycle after the previous burst's last data phase (POL-05 gives exactly one).
  covergroup cg with function sample(ahb_dir_e dir, ahb_burst_e burst, size_kind_e size_kind,
                                     int unsigned len, int unsigned max_waits, bit is_error,
                                     bit has_busy, bit b2b, logic [3:0] prot, logic lock);
    option.per_instance = 1;

    cp_dir      : coverpoint dir;
    cp_burst    : coverpoint burst;
    cp_size     : coverpoint size_kind;
    cp_incr_len : coverpoint len iff (burst == AHB_BURST_INCR) {
      bins single = {1};
      bins few    = {[2:4]};
      bins many   = {[5:AHB_MAX_BEATS]};
    }
    cp_waits    : coverpoint max_waits {
      bins zero    = {0};
      bins one     = {1};
      bins two     = {2};
      bins several = {[3:$]};
    }
    cp_error    : coverpoint is_error;
    cp_busy     : coverpoint has_busy;
    cp_b2b      : coverpoint b2b;
    cp_prot     : coverpoint prot;
    cp_lock     : coverpoint lock;

    x_dir_burst  : cross cp_dir, cp_burst;
    x_burst_size : cross cp_burst, cp_size;
    x_dir_error  : cross cp_dir, cp_error;
  endgroup : cg

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  // Name the covergroup instance after this component: coverage is per agent.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cg.set_inst_name(get_full_name());
  endfunction

  // Sample one observed burst; back-to-back comes from the monitor's cycle stamps.
  virtual function void write(ahb_transaction t);
    int unsigned max_waits = 0;
    bit          has_busy  = 1'b0;
    bit          b2b       = has_prev && (t.start_cycle <= prev_end + 1);
    foreach (t.wait_states[i])
      if (t.wait_states[i] > max_waits) max_waits = t.wait_states[i];
    foreach (t.busy[i])
      if (t.busy[i] != 0) has_busy = 1'b1;
    cg.sample(t.dir, t.burst, classify_size(t), t.len, max_waits, t.status == AHB_ST_ERROR,
              has_busy, b2b, t.prot[3:0], t.lock);
    prev_end = t.end_cycle;
    has_prev = 1'b1;
  endfunction

  // Classify HSIZE against the width of the bus the burst was observed on.
  protected function size_kind_e classify_size(ahb_transaction t);
    if (t.beat_bytes() * 8 >= t.bus_data_width) return SIZE_FULL;
    if (t.size == AHB_SIZE_8)                     return SIZE_BYTE;
    return SIZE_NARROW;
  endfunction

  // Per-instance coverage summary.
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("AHB_COV", $sformatf("%s: coverage %0.1f%%", get_full_name(), cg.get_inst_coverage()),
              UVM_LOW)
  endfunction

endclass : ahb_coverage
