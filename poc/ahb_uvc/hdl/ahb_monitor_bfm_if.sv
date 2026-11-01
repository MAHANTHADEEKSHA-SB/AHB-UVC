// -----------------------------------------------------------------------------
// ahb_monitor_bfm_if — passive AHB observation BFM
//
// Owns passive sampling and burst reconstruction (ADR-002 decision 3). Every
// port is an input: this BFM can never drive the bus. It connects to the same
// ahb_if instance as the driver BFM through ordinary signal ports.
//
// Transport (AHB_PROTOCOL_CONTRACT section 7, RISK-002 — proposal until
// validated on the target simulator):
//   * an always-running process samples through a clocking block
//     (input #1step), independent of HVL timing;
//   * one observation per burst. A burst ends when the next IDLE or NONSEQ
//     address phase is accepted, which is the HCLK edge where its last data
//     phase completes when the Manager does not insert a trailing BUSY;
//   * observations and reset events (RST-4) go into bounded queues of plain
//     values (no UVM objects in HDL, ADR-002 section 6); the HVL observe
//     adapter calls the blocking tasks get_burst() and get_reset_event().
//
// Protocol violations are counted per ahb_mon_error_e code and optionally
// printed; the HVL side turns the counts into UVM reports. Milestone M1
// checks AHB-Lite behaviour plus HPROT[6:4]/HNONSEC; HEXCL, HMASTER, HWSTRB
// and user signals are accepted as ports but not checked until M2.
// Compile after ahb_bfm_pkg.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

interface ahb_monitor_bfm_if
  import ahb_bfm_pkg::*;
#(
  parameter int ADDR_WIDTH      = 32,
  parameter int DATA_WIDTH      = 32,
  parameter int MASTER_WIDTH    = 4,
  parameter int USER_REQ_WIDTH  = 1,
  parameter int USER_DATA_WIDTH = 1,
  parameter int USER_RESP_WIDTH = 1,
  parameter int QUEUE_DEPTH     = 16
) (
  input wire logic                       HCLK,
  input wire logic                       HRESETn,
  // Manager outputs
  input wire logic [ADDR_WIDTH-1:0]      HADDR,
  input wire logic [2:0]                 HBURST,
  input wire logic                       HMASTLOCK,
  input wire logic [6:0]                 HPROT,
  input wire logic [2:0]                 HSIZE,
  input wire logic                       HNONSEC,
  input wire logic                       HEXCL,
  input wire logic [MASTER_WIDTH-1:0]    HMASTER,
  input wire logic [1:0]                 HTRANS,
  input wire logic [DATA_WIDTH-1:0]      HWDATA,
  input wire logic [DATA_WIDTH/8-1:0]    HWSTRB,
  input wire logic                       HWRITE,
  input wire logic [USER_REQ_WIDTH-1:0]  HAUSER,
  input wire logic [USER_DATA_WIDTH-1:0] HWUSER,
  // Interconnect outputs
  input wire logic [DATA_WIDTH-1:0]      HRDATA,
  input wire logic                       HREADY,
  input wire logic                       HRESP,
  input wire logic                       HEXOKAY,
  input wire logic [USER_DATA_WIDTH-1:0] HRUSER,
  input wire logic [USER_RESP_WIDTH-1:0] HBUSER
);

  // One observed burst, kept as plain values
  typedef struct {
    bit                    write;
    logic [ADDR_WIDTH-1:0] addr;         // address of the NONSEQ
    logic [2:0]            burst;
    logic [2:0]            size;
    logic [6:0]            prot;
    logic                  nonsec;
    logic                  lock;
    int unsigned           beats;        // beats recorded, <= AHB_MAX_BEATS
    logic [ADDR_WIDTH-1:0] beat_addr [AHB_MAX_BEATS];
    logic [DATA_WIDTH-1:0] wdata     [AHB_MAX_BEATS];
    logic [DATA_WIDTH-1:0] rdata     [AHB_MAX_BEATS];
    logic                  resp      [AHB_MAX_BEATS];
    int unsigned           waits     [AHB_MAX_BEATS];  // HREADY LOW cycles per data phase
    int unsigned           busy      [AHB_MAX_BEATS];  // BUSY phases accepted before a beat
    bit                    error_seen;
    longint unsigned       start_cycle;  // sample where the NONSEQ was accepted
    longint unsigned       end_cycle;    // sample where the last data phase completed
  } ahb_obs_t;

  // One address phase as sampled; compared whole for the wait-state rule
  typedef struct packed {
    logic [1:0]            trans;
    logic [ADDR_WIDTH-1:0] addr;
    logic                  write;
    logic [2:0]            burst;
    logic [2:0]            size;
    logic [6:0]            prot;
    logic                  nonsec;
    logic                  lock;
  } ahb_ap_t;

  // One reset edge reported to the HVL side (RST-4)
  typedef struct packed {
    bit              asserted;
    longint unsigned cycle;
  } ahb_rst_t;

  ahb_features_t         features           = ahb_default_features();
  bit                    publish_en         = 1'b0;  // queue only when a consumer exists
  bit                    verbose            = 1'b1;  // print each violation
  ahb_obs_t              obs_q[$];
  event                  obs_ev;                     // triggered on every burst publish
  ahb_rst_t              rst_q[$];
  event                  rst_ev;                     // triggered on every reset event
  int unsigned           error_count[AHB_MON_NUM_ERRORS];
  int unsigned           transfer_count     = 0;     // completed bursts observed
  int unsigned           beat_count         = 0;     // completed NONSEQ/SEQ data phases
  int unsigned           reset_count        = 0;     // resets after the first release
  int unsigned           aborted_count      = 0;     // bursts cut short by reset
  bit                    in_reset           = 1'b1;
  bit                    seen_reset_release = 1'b0;
  longint unsigned       cycle              = 0;

  // Reconstruction state
  ahb_obs_t              cur;                        // burst being assembled
  bit                    burst_open         = 1'b0;
  logic [ADDR_WIDTH-1:0] last_addr          = '0;    // address of the latest beat
  int unsigned           busy_pending       = 0;     // BUSY phases since the latest beat
  bit                    dp_active          = 1'b0;  // a data phase is in progress
  bit                    dp_idle_busy       = 1'b0;  // ... and it follows an IDLE/BUSY
  bit                    dp_write           = 1'b0;
  int unsigned           dp_beat            = 0;     // beat index of that data phase
  bit                    dp_dropped         = 1'b0;  // beat beyond AHB_MAX_BEATS
  int unsigned           dp_samples         = 0;     // samples taken in this data phase
  logic [DATA_WIDTH-1:0] dp_wdata_prev      = '0;
  ahb_ap_t               prev_ap            = '0;
  bit                    prev_waited        = 1'b0;  // previous sample had HREADY LOW
  bit                    prev_err1          = 1'b0;  // previous sample: first ERROR cycle

  // Every input is sampled 1step before the HCLK rising edge: the values that were
  // stable during the cycle, race-free against any driver (HDL-05).
  clocking cb @(posedge HCLK);
    default input #1step;
    input HRESETn, HADDR, HBURST, HMASTLOCK, HPROT, HSIZE, HNONSEC, HTRANS, HWDATA,
          HWRITE, HRDATA, HREADY, HRESP;
  endclocking

  // ---------------------------------------------------------------------------
  // Control / observation API (called by the HVL observe adapter)
  // ---------------------------------------------------------------------------

  // Accept the instance feature set unless it is illegal for its revision (CFG-01).
  // M2/M3 features are accepted: their pins exist but are not checked yet.
  function automatic bit configure(ahb_features_t f);
    string problem = ahb_revision_problem(f);
    if (problem != "") begin
      $error("%m: feature set rejected: %s", problem);
      return 1'b0;
    end
    features = f;
    return 1'b1;
  endfunction

  // Queue bursts and reset events only once a consumer exists, so an unused
  // monitor cannot overflow. The counters count either way.
  function automatic void set_publish(bit en);
    publish_en = en;
  endfunction

  // Print each violation when it happens; the counters are kept either way.
  function automatic void set_verbose(bit en);
    verbose = en;
  endfunction

  // Violation counters per ahb_mon_error_e; ahb_monitor reports them in check_phase.
  function automatic int unsigned get_error_count(ahb_mon_error_e code);
    return error_count[code];
  endfunction

  function automatic int unsigned get_total_errors();
    int unsigned total = 0;
    foreach (error_count[i]) total += error_count[i];
    return total;
  endfunction

  function automatic void clear_errors();
    foreach (error_count[i]) error_count[i] = 0;
  endfunction

  // Blocks until a completed burst is available, then removes it. The queue is
  // checked before waiting, so a publish earlier in the same time step is never
  // missed. Entries at index >= beats are zero.
  task automatic get_burst(
    output bit                    write,
    output logic [ADDR_WIDTH-1:0] addr,
    output logic [2:0]            burst,
    output logic [2:0]            size,
    output logic [6:0]            prot,
    output logic                  nonsec,
    output logic                  lock,
    output int unsigned           beats,
    output logic [ADDR_WIDTH-1:0] beat_addr [AHB_MAX_BEATS],
    output logic [DATA_WIDTH-1:0] wdata     [AHB_MAX_BEATS],
    output logic [DATA_WIDTH-1:0] rdata     [AHB_MAX_BEATS],
    output logic                  resp      [AHB_MAX_BEATS],
    output int unsigned           waits     [AHB_MAX_BEATS],
    output int unsigned           busy      [AHB_MAX_BEATS],
    output longint unsigned       start_cycle,
    output longint unsigned       end_cycle
  );
    ahb_obs_t o;
    while (obs_q.size() == 0) @(obs_ev);
    o           = obs_q.pop_front();
    write       = o.write;
    addr        = o.addr;
    burst       = o.burst;
    size        = o.size;
    prot        = o.prot;
    nonsec      = o.nonsec;
    lock        = o.lock;
    beats       = o.beats;
    beat_addr   = o.beat_addr;
    wdata       = o.wdata;
    rdata       = o.rdata;
    resp        = o.resp;
    waits       = o.waits;
    busy        = o.busy;
    start_cycle = o.start_cycle;
    end_cycle   = o.end_cycle;
  endtask

  // Blocks until the next reset edge after the first release (RST-4):
  // asserted = 1 when reset asserted, 0 when it was released again.
  task automatic get_reset_event(output bit asserted, output longint unsigned at_cycle);
    ahb_rst_t r;
    while (rst_q.size() == 0) @(rst_ev);
    r        = rst_q.pop_front();
    asserted = r.asserted;
    at_cycle = r.cycle;
  endtask

  // ---------------------------------------------------------------------------
  // Sampling process
  // ---------------------------------------------------------------------------

  // Free-running sampler: one sample_cycle() per HCLK edge, independent of the
  // HVL side (AHB_PROTOCOL_CONTRACT section 7).
  initial forever begin
    @(cb);
    cycle++;
    sample_cycle();
  end

  // Count one violation; when verbose, print it with time, instance and cycle.
  task automatic flag(ahb_mon_error_e code, string msg);
    error_count[code]++;
    if (verbose)
      $display("%0t AHB_MON_ERROR %m [%s] cycle=%0d: %s", $realtime, code.name(), cycle, msg);
  endtask

  // Count a completed burst. When publishing, queue it (bounded: an overflow is
  // itself reported) and wake a get_burst() caller.
  task automatic publish(ahb_obs_t o);
    transfer_count++;
    if (!publish_en) return;
    if (obs_q.size() >= QUEUE_DEPTH) begin
      flag(AHB_MON_ERR_QUEUE_OVERFLOW, "observation queue full; burst dropped");
      return;
    end
    obs_q.push_back(o);
    -> obs_ev;
  endtask

  // Queue one reset edge for get_reset_event() (RST-4), bounded like publish().
  task automatic publish_reset(bit asserted);
    ahb_rst_t r;
    if (!publish_en) return;
    if (rst_q.size() >= QUEUE_DEPTH) begin
      flag(AHB_MON_ERR_QUEUE_OVERFLOW, "reset event queue full; event dropped");
      return;
    end
    r.asserted = asserted;
    r.cycle    = cycle;
    rst_q.push_back(r);
    -> rst_ev;
  endtask

  // Forget any partial burst and data phase (reset, or HTRANS X/Z): nothing of
  // it is ever published (RST-4).
  task automatic resync();
    burst_open   = 1'b0;
    dp_active    = 1'b0;
    prev_waited  = 1'b0;
    prev_err1    = 1'b0;
    busy_pending = 0;
  endtask

  // Zero every field of the burst being assembled.
  task automatic clear_cur();
    cur.write       = 1'b0;
    cur.addr        = '0;
    cur.burst       = 3'b000;
    cur.size        = 3'b000;
    cur.prot        = 7'b0000000;
    cur.nonsec      = 1'b0;
    cur.lock        = 1'b0;
    cur.beats       = 0;
    cur.error_seen  = 1'b0;
    cur.start_cycle = 0;
    cur.end_cycle   = 0;
    for (int i = 0; i < AHB_MAX_BEATS; i++) begin
      cur.beat_addr[i] = '0;
      cur.wdata[i]     = '0;
      cur.rdata[i]     = '0;
      cur.resp[i]      = 1'b0;
      cur.waits[i]     = 0;
      cur.busy[i]      = 0;
    end
  endtask

  // NONSEQ accepted: a new burst starts with beat 0 (AHB-R05).
  task automatic start_burst(ahb_ap_t ap);
    clear_cur();
    cur.write        = (ap.write === 1'b1);
    cur.addr         = ap.addr;
    cur.burst        = ap.burst;
    cur.size         = ap.size;
    cur.prot         = ap.prot;
    cur.nonsec       = ap.nonsec;
    cur.lock         = ap.lock;
    cur.beats        = 1;
    cur.beat_addr[0] = ap.addr;
    cur.start_cycle  = cycle;
    burst_open       = 1'b1;
    last_addr        = ap.addr;
    busy_pending     = 0;
    dp_beat          = 0;
    dp_dropped       = 1'b0;
  endtask

  // SEQ accepted inside an open burst: control must match (AHB-R05), the address
  // must be the next incrementing/wrapping address (AHB-R05/R09), incrementing
  // bursts stay in one 1KB page (AHB-R08), fixed bursts keep their length (R09).
  task automatic add_seq_beat(ahb_ap_t ap);
    logic [ADDR_WIDTH-1:0] expected;
    int unsigned           fixed;
    if (ap.write !== cur.write || ap.burst !== cur.burst || ap.size !== cur.size ||
        ap.prot !== cur.prot || ap.nonsec !== cur.nonsec || ap.lock !== cur.lock)
      flag(AHB_MON_ERR_BURST_CONTROL_CHANGED, "control changed inside a burst");
    fixed = ahb_burst_beats(cur.burst);
    if (fixed != 0 && cur.beats >= fixed)
      flag(AHB_MON_ERR_BURST_LENGTH,
           $sformatf("SEQ after %0d beats of a %0d-beat burst", cur.beats, fixed));
    expected = ADDR_WIDTH'(ahb_next_addr(AHB_FN_AW'(last_addr), cur.size, cur.burst));
    if (ap.addr !== expected)
      flag(AHB_MON_ERR_BURST_ADDR, $sformatf("SEQ at %0h, expected %0h", ap.addr, expected));
    if (!ahb_burst_is_wrap(cur.burst) &&
        ahb_crosses_1kb(AHB_FN_AW'(last_addr), AHB_FN_AW'(ap.addr)))
      flag(AHB_MON_ERR_BURST_1KB_CROSS, $sformatf("burst crosses a 1KB boundary at %0h", ap.addr));
    last_addr = ap.addr;
    if (cur.beats >= AHB_MAX_BEATS) begin
      flag(AHB_MON_ERR_CAPACITY, "INCR burst longer than AHB_MAX_BEATS; beat not recorded");
      dp_dropped = 1'b1;
    end else begin
      cur.beat_addr[cur.beats] = ap.addr;
      cur.busy[cur.beats]      = busy_pending;
      dp_beat                  = cur.beats;
      dp_dropped               = 1'b0;
      cur.beats++;
    end
    busy_pending = 0;
  endtask

  // Per-beat legality: HSIZE fits the bus (AHB-R06), address aligned (AHB-R07).
  task automatic check_beat(ahb_ap_t ap);
    logic [AHB_FN_AW-1:0] lsbs;
    if (ahb_size_bytes(ap.size) > unsigned'(DATA_WIDTH / 8)) begin
      flag(AHB_MON_ERR_SIZE_EXCEEDS_BUS,
           $sformatf("HSIZE=%0d is wider than DATA_WIDTH=%0d", ap.size, DATA_WIDTH));
      return;
    end
    lsbs = AHB_FN_AW'(ap.addr) & AHB_FN_AW'(ahb_size_bytes(ap.size) - 1);
    if (lsbs != 0)
      flag(AHB_MON_ERR_UNALIGNED,
           $sformatf("HADDR=%0h not aligned to HSIZE=%0d", ap.addr, ap.size));
  endtask

  // The burst ends (IDLE or NONSEQ accepted). A fixed-length burst may end early
  // only after an ERROR (AHB-R10). The burst is published once.
  task automatic end_burst();
    int unsigned fixed;
    if (!burst_open) return;
    fixed = ahb_burst_beats(cur.burst);
    if (fixed > 1 && cur.beats < fixed && !cur.error_seen)
      flag(AHB_MON_ERR_BURST_LENGTH,
           $sformatf("%0d-beat burst ended after %0d beats without ERROR", fixed, cur.beats));
    burst_open = 1'b0;
    publish(cur);
  endtask

  // A data phase starts after an accepted NONSEQ/SEQ (beat) or IDLE/BUSY.
  task automatic start_data_phase(bit idle_busy, logic write);
    dp_active    = 1'b1;
    dp_idle_busy = idle_busy;
    dp_write     = !idle_busy && (write === 1'b1);
    dp_samples   = 0;
  endtask

  // Data phase in progress during this cycle: wait state or completion.
  // Write data must hold still (AHB-R12); ERROR takes exactly two cycles (AHB-R14);
  // IDLE/BUSY get a zero-wait OKAY (AHB-R03/R04). Returns 1 for a first ERROR cycle.
  task automatic sample_data_phase(input bit hready, input logic resp, output bit err1);
    err1 = 1'b0;
    if (!dp_active) return;
    if (dp_idle_busy) begin
      if (!hready || resp === 1'b1)
        flag(AHB_MON_ERR_IDLE_BUSY_RESPONSE, "IDLE/BUSY transfer not given a zero-wait OKAY");
      if (hready) dp_active = 1'b0;
      return;
    end
    if (dp_write && dp_samples != 0 && cb.HWDATA !== dp_wdata_prev)
      flag(AHB_MON_ERR_UNSTABLE_IN_WAIT, "HWDATA changed during a waited write data phase");
    dp_wdata_prev = cb.HWDATA;
    dp_samples++;
    if (!hready) begin
      if (!dp_dropped) cur.waits[dp_beat]++;
      if (prev_err1)
        flag(AHB_MON_ERR_ERROR_NOT_TWO_CYCLE, "first ERROR cycle not followed by HREADY HIGH");
      err1 = (resp === 1'b1);
      return;
    end
    if (resp === 1'b1 && !prev_err1)
      flag(AHB_MON_ERR_ERROR_NOT_TWO_CYCLE, "ERROR completed without its first cycle");
    if (resp !== 1'b1 && prev_err1)
      flag(AHB_MON_ERR_ERROR_NOT_TWO_CYCLE, "first ERROR cycle completed as OKAY");
    if (!dp_dropped) begin
      cur.resp[dp_beat]  = resp;
      cur.wdata[dp_beat] = dp_write ? cb.HWDATA : '0;
      cur.rdata[dp_beat] = dp_write ? '0 : cb.HRDATA;  // AHB-R13, 4-state verbatim
    end
    if (resp === 1'b1) cur.error_seen = 1'b1;
    cur.end_cycle = cycle;
    beat_count++;
    dp_active = 1'b0;
  endtask

  // Process one HCLK sample, in this order: reset (RST-4/6/7), HTRANS/HREADY
  // validity (AHB-R22), the waited-transfer rule (AHB-R11), the data phase in
  // progress, then — when HREADY is HIGH — the address phase accepted at this
  // edge (AHB-R02..R10). Consumes no time.
  task automatic sample_cycle();
    ahb_ap_t ap;
    bit      hready;
    bit      err1;
    logic    resp;

    // Reset (RST-4, RST-6, RST-7)
    if (cb.HRESETn !== 1'b1) begin
      if (cb.HRESETn !== 1'b0 && seen_reset_release)
        flag(AHB_MON_ERR_HRESETN_XZ, "HRESETn is X/Z");
      if (!in_reset) begin
        reset_count++;
        if (burst_open) aborted_count++;
        publish_reset(1'b1);
      end
      in_reset = 1'b1;
      resync();  // a partial burst is discarded, never published
      return;
    end
    if (in_reset) begin
      in_reset = 1'b0;
      if (seen_reset_release) publish_reset(1'b0);
      seen_reset_release = 1'b1;
    end

    ap.trans  = cb.HTRANS;
    ap.addr   = cb.HADDR;
    ap.write  = cb.HWRITE;
    ap.burst  = cb.HBURST;
    ap.size   = cb.HSIZE;
    ap.prot   = features.ext_mem_types ? cb.HPROT : {3'b000, cb.HPROT[3:0]};
    ap.nonsec = features.secure_transfers ? cb.HNONSEC : 1'b0;
    ap.lock   = cb.HMASTLOCK;

    // AHB-R22: HTRANS and HREADY are always valid outside reset (RST-6)
    if ($isunknown(cb.HTRANS)) begin
      flag(AHB_MON_ERR_HTRANS_XZ, "HTRANS is X/Z");
      resync();
      return;
    end
    if ($isunknown(cb.HREADY)) flag(AHB_MON_ERR_HREADY_XZ, "HREADY is X/Z");
    hready = (cb.HREADY === 1'b1);  // X/Z counts as LOW
    resp   = cb.HRESP;
    if (ap.trans[1] === 1'b1 &&
        $isunknown({ap.addr, ap.write, ap.burst, ap.size, ap.prot, ap.nonsec, ap.lock}))
      flag(AHB_MON_ERR_CONTROL_XZ, "address/control X/Z in a NONSEQ/SEQ address phase");

    // AHB-R11: a NONSEQ/SEQ that was not accepted is presented again unchanged;
    // after a first ERROR cycle the Manager may replace it with IDLE (AHB-R15).
    if (prev_waited && prev_ap.trans[1] === 1'b1 && ap !== prev_ap &&
        !(prev_err1 && ap.trans == AHB_TRANS_IDLE))
      flag(AHB_MON_ERR_UNSTABLE_IN_WAIT, "waited NONSEQ/SEQ address or control changed");

    sample_data_phase(hready, resp, err1);

    // Address phase accepted at this edge (AHB-R02)
    if (hready) begin
      case (ap.trans)
        AHB_TRANS_IDLE: begin
          end_burst();
          start_data_phase(1'b1, 1'b0);
        end
        AHB_TRANS_BUSY: begin
          if (!burst_open || cur.burst == AHB_BURST_SINGLE)
            flag(AHB_MON_ERR_SEQ_OUTSIDE_BURST, "BUSY outside a burst");
          else
            busy_pending++;
          start_data_phase(1'b1, 1'b0);
        end
        AHB_TRANS_NONSEQ: begin
          end_burst();
          start_burst(ap);
          check_beat(ap);
          start_data_phase(1'b0, ap.write);
        end
        default: begin  // AHB_TRANS_SEQ
          if (!burst_open) begin
            flag(AHB_MON_ERR_SEQ_OUTSIDE_BURST, "SEQ without a preceding NONSEQ");
            start_burst(ap);  // still reconstruct what the Subordinate sees
          end else begin
            add_seq_beat(ap);
          end
          check_beat(ap);
          start_data_phase(1'b0, ap.write);
        end
      endcase
    end

    prev_ap     = ap;
    prev_waited = !hready;
    prev_err1   = err1;
  endtask

endinterface : ahb_monitor_bfm_if
