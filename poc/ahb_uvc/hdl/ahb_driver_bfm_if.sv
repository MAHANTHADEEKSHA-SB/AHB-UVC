// -----------------------------------------------------------------------------
// ahb_driver_bfm_if — AHB Manager drive BFM
//
// Owns timed AHB Manager drive (ADR-002 decision 2). Connects to the shared
// ahb_if instance through ordinary signal ports wired in the HDL top
// (ADR-002 decision 7); it has no interface-typed ports, so a virtual handle
// to this interface avoids the IEEE restriction noted in DVCon 2024.
//
// One do_burst() call runs one burst with the AHB address/data pipeline: the
// address phase of beat n+1 overlaps the data phase of beat n (AHB-R02).
// Contract references: docs/dv-architecture/AHB_PROTOCOL_CONTRACT.md
//   AHB-R02..R05  pipeline, transfer types, burst sequencing
//   AHB-R11/R12   address/control and write data held through wait states
//   AHB-R14/R15   two-cycle ERROR; remaining beats cancelled (POL-02)
//   RST-1..RST-3  reset behaviour
//   section 8     drive release: outputs are 'z until set_enable(1)
//
// Milestone M1 implements AHB-Lite and the AHB5 HPROT[6:4] and HNONSEC
// properties. HEXCL, HMASTER, HWSTRB and user outputs exist but are driven
// to 0 until milestone M2 (POL-03); configure() rejects those features.
// Items are not pipelined into each other: the NONSEQ of the next burst
// follows the last data phase of the previous one (POL-05).
// Compile after ahb_bfm_pkg.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

interface ahb_driver_bfm_if
  import ahb_bfm_pkg::*;
#(
  parameter int ADDR_WIDTH      = 32,
  parameter int DATA_WIDTH      = 32,
  parameter int MASTER_WIDTH    = 4,
  parameter int USER_REQ_WIDTH  = 1,
  parameter int USER_DATA_WIDTH = 1,
  parameter int USER_RESP_WIDTH = 1
) (
  input  wire logic                       HCLK,
  input  wire logic                       HRESETn,
  // Manager outputs
  output wire logic [ADDR_WIDTH-1:0]      HADDR,
  output wire logic [2:0]                 HBURST,
  output wire logic                       HMASTLOCK,
  output wire logic [6:0]                 HPROT,
  output wire logic [2:0]                 HSIZE,
  output wire logic                       HNONSEC,
  output wire logic                       HEXCL,
  output wire logic [MASTER_WIDTH-1:0]    HMASTER,
  output wire logic [1:0]                 HTRANS,
  output wire logic [DATA_WIDTH-1:0]      HWDATA,
  output wire logic [DATA_WIDTH/8-1:0]    HWSTRB,
  output wire logic                       HWRITE,
  output wire logic [USER_REQ_WIDTH-1:0]  HAUSER,
  output wire logic [USER_DATA_WIDTH-1:0] HWUSER,
  // Inputs from the interconnect multiplexor
  input  wire logic [DATA_WIDTH-1:0]      HRDATA,
  input  wire logic                       HREADY,
  input  wire logic                       HRESP,
  input  wire logic                       HEXOKAY,
  input  wire logic [USER_DATA_WIDTH-1:0] HRUSER,
  input  wire logic [USER_RESP_WIDTH-1:0] HBUSER
);

  // Drive state, written by the tasks below with nonblocking assignments so a
  // Subordinate sampling on the same HCLK edge sees the previous value (HDL-05).
  logic [ADDR_WIDTH-1:0] haddr_q     = '0;
  logic [2:0]            hburst_q    = 3'b000;
  logic                  hmastlock_q = 1'b0;
  logic [6:0]            hprot_q     = 7'b0000000;
  logic [2:0]            hsize_q     = 3'b000;
  logic                  hnonsec_q   = 1'b0;
  logic [1:0]            htrans_q    = AHB_TRANS_IDLE;
  logic [DATA_WIDTH-1:0] hwdata_q    = '0;
  logic                  hwrite_q    = 1'b0;

  bit            drive_en  = 1'b0;  // 0: every output released to 'z (passive-safe)
  bit            in_flight = 1'b0;  // a do_burst() call owns the bus
  ahb_features_t features  = ahb_default_features();
  ahb_fault_e    fault     = AHB_FAULT_NONE;

  // Release-capable output stage (AHB_PROTOCOL_CONTRACT section 8)
  assign HADDR     = drive_en ? haddr_q     : 'z;
  assign HBURST    = drive_en ? hburst_q    : 'z;
  assign HMASTLOCK = drive_en ? hmastlock_q : 1'bz;
  assign HPROT     = drive_en ? hprot_q     : 'z;
  assign HSIZE     = drive_en ? hsize_q     : 'z;
  assign HNONSEC   = drive_en ? hnonsec_q   : 1'bz;
  assign HTRANS    = drive_en ? htrans_q    : 'z;
  assign HWDATA    = drive_en ? hwdata_q    : 'z;
  assign HWRITE    = drive_en ? hwrite_q    : 1'bz;
  // Milestone M2 outputs: absent, driven to 0 while enabled (POL-03)
  assign HEXCL     = drive_en ? 1'b0 : 1'bz;
  assign HMASTER   = drive_en ? '0   : 'z;
  assign HWSTRB    = drive_en ? '0   : 'z;
  assign HAUSER    = drive_en ? '0   : 'z;
  assign HWUSER    = drive_en ? '0   : 'z;

  // Inputs are sampled 1step before each HCLK rising edge: the values the
  // interconnect presented during that cycle (HDL-05). Manager outputs are not
  // driven through this block; the tasks below update them with NBAs.
  clocking cb @(posedge HCLK);
    default input #1step;
    input HRESETn, HREADY, HRESP, HRDATA;
  endclocking

  // ---------------------------------------------------------------------------
  // Control API (called through a virtual interface by the HVL drive adapter)
  // ---------------------------------------------------------------------------

  // Accept a per-instance feature set; returns 0 and changes nothing when the
  // set is illegal for its revision (CFG-01) or not implemented yet (CFG-02).
  function automatic bit configure(ahb_features_t f);
    string problem;
    if (in_flight) begin
      $error("%m: configure() while a burst is in flight");
      return 1'b0;
    end
    problem = ahb_revision_problem(f);
    if (problem == "") problem = ahb_milestone_problem(f);
    if (problem != "") begin
      $error("%m: feature set rejected: %s", problem);
      return 1'b0;
    end
    features = f;
    return 1'b1;
  endfunction

  // 1: drive the bus; 0: release every output to 'z
  function automatic void set_enable(bit en);
    if (in_flight && !en) $error("%m: driver released while a burst is in flight");
    drive_en = en;
  endfunction

  // Negative tests only: select a deliberate protocol fault (ahb_fault_e). It stays
  // active for every following burst until set back to AHB_FAULT_NONE.
  function automatic void set_fault(ahb_fault_e f);
    fault = f;
  endfunction

  // RST-5: return after HRESETn is sampled HIGH, plus idle_cycles more edges
  task automatic wait_for_reset_release(input int unsigned idle_cycles = 1);
    do
      @(cb);
    while (cb.HRESETn !== 1'b1);
    repeat (idle_cycles) @(cb);
  endtask

  // One complete burst of len beats (AHB-R02..R05). idle_cycles IDLE address
  // phases precede the NONSEQ; busy_cycles[i] BUSY phases precede beat i >= 1.
  // Returns at the HCLK edge where the last data phase completed, after
  // scheduling IDLE; a following call in the same time step with
  // idle_cycles == 0 overrides it with its NONSEQ (POL-05). Per beat: the
  // address driven, read data and HRESP (4-state, verbatim) and the HREADY LOW
  // cycles of its data phase (the first ERROR cycle counts as one).
  task automatic do_burst(
    input  bit                    write,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [2:0]            burst,
    input  logic [2:0]            size,
    input  int unsigned           len,
    input  logic [6:0]            prot,
    input  logic                  nonsec,
    input  logic                  lock,
    input  logic [DATA_WIDTH-1:0] wdata       [AHB_MAX_BEATS],
    input  int unsigned           busy_cycles [AHB_MAX_BEATS],
    input  int unsigned           idle_cycles,
    input  int unsigned           max_wait_cycles,  // per stall; 0 = no watchdog
    output logic [ADDR_WIDTH-1:0] beat_addr   [AHB_MAX_BEATS],
    output logic [DATA_WIDTH-1:0] rdata       [AHB_MAX_BEATS],
    output logic                  resp        [AHB_MAX_BEATS],
    output int unsigned           waits       [AHB_MAX_BEATS],
    output int unsigned           beats_done,
    output ahb_bfm_status_e       status
  );
    ahb_bfm_status_e       st;
    int unsigned           a_idx;      // beat whose address phase is (next) on the bus
    int unsigned           d_idx;      // beat in its data phase
    bit                    a_beat;     // NONSEQ/SEQ of beat a_idx is on the bus
    bit                    d_valid;    // data phase of beat d_idx in progress
    int unsigned           busy_left;  // BUSY phases still to be accepted before a_idx
    int unsigned           stall;      // consecutive HREADY LOW cycles
    bit                    stop;       // no further beats: cancelled or faulted
    bit                    faulted;    // AHB_FAULT_ADDR_UNSTABLE applied once
    logic [ADDR_WIDTH-1:0] next_a;
    ahb_trans_e            next_trans;

    foreach (beat_addr[i]) begin
      beat_addr[i] = '0;
      rdata[i]     = '0;
      resp[i]      = 1'b0;
      waits[i]     = 0;
    end
    beats_done = 0;
    status     = AHB_ST_OK;

    // A request that cannot start leaves the bus untouched; status says why.
    if (!drive_en) begin
      status = AHB_ST_NOT_ENABLED;
      return;
    end
    if (in_flight || !burst_shape_ok(burst, size, len)) begin
      status = AHB_ST_BAD_REQUEST;
      return;
    end
    if (HRESETn !== 1'b1) begin
      status = AHB_ST_RESET_ABORTED;
      return;
    end

    // The BFM owns the bus until the end of the task: configure() is refused and
    // set_enable(0) is reported as an error while in flight.
    in_flight = 1'b1;
    st        = AHB_ST_OK;
    fork begin : guard  // isolates "disable fork" from the caller's processes
      fork
        begin : transfer
          // IDLE address phases requested by the item; 0 = NONSEQ right away.
          repeat (idle_cycles) @(cb);
          beat_addr[0] = addr;
          drive_addr(AHB_TRANS_NONSEQ, addr, write, burst, size, prot, nonsec, lock);
          a_idx     = 0;
          a_beat    = 1'b1;
          d_valid   = 1'b0;
          busy_left = 0;
          stall     = 0;
          stop      = 1'b0;
          faulted   = 1'b0;
          forever begin
            @(cb);
            if (cb.HREADY !== 1'b1) begin
              // Wait state (X/Z counts as LOW): the data phase is extended and the
              // address phase on the bus is held unchanged (AHB-R11/R12).
              stall++;
              if (d_valid) waits[d_idx]++;
              if (max_wait_cycles != 0 && stall >= max_wait_cycles) begin
                st = AHB_ST_TIMEOUT;  // POL-01; the Subordinate is abandoned
                break;
              end
              // First ERROR cycle (AHB-R14): replace the pending address phase with
              // IDLE so the remaining beats are cancelled (AHB-R15, POL-02).
              if (d_valid && cb.HRESP === 1'b1 && !stop) begin
                drive_idle_addr();
                a_beat    = 1'b0;
                busy_left = 0;
                stop      = 1'b1;
              end
              // Fault mode 1: move the waited NONSEQ/SEQ to another address once.
              if (fault == AHB_FAULT_ADDR_UNSTABLE && a_beat && !faulted) begin
                haddr_q <= beat_addr[a_idx] ^ ADDR_WIDTH'(ahb_size_bytes(size));
                faulted  = 1'b1;
              end
              continue;
            end

            // HREADY HIGH: the data phase in progress completes and the address
            // phase on the bus is accepted at this edge (AHB-R02).
            stall = 0;
            if (d_valid) begin
              resp[d_idx] = cb.HRESP;                // 4-state, verbatim
              if (!write) rdata[d_idx] = cb.HRDATA;  // AHB-R13
              beats_done++;
              if (cb.HRESP === 1'b1) st = AHB_ST_ERROR;
              d_valid = 1'b0;
            end
            if (a_beat) begin
              // Beat a_idx enters its data phase: present its write data (AHB-R12).
              d_valid   = 1'b1;
              d_idx     = a_idx;
              hwdata_q <= write ? wdata[a_idx] : '0;
              a_idx++;
              a_beat    = 1'b0;
              // Fault mode 3: end a fixed-length burst after two beats, no ERROR.
              if (fault == AHB_FAULT_EARLY_TERMINATION && a_idx == 2 &&
                  ahb_burst_beats(burst) > 2) begin
                st   = AHB_ST_FAULT_INJECTED;
                stop = 1'b1;
              end
              if (!stop && a_idx < len) begin
                next_a = ADDR_WIDTH'(ahb_next_addr(AHB_FN_AW'(beat_addr[a_idx-1]), size, burst));
                // Fault mode 2: the second beat goes to a wrong (still aligned) address.
                if (fault == AHB_FAULT_BAD_SEQ_ADDR && a_idx == 1)
                  next_a = next_a ^ ADDR_WIDTH'(ahb_size_bytes(size));
                beat_addr[a_idx] = next_a;
                busy_left        = busy_cycles[a_idx];
                // BUSY carries the next beat's address and control (AHB-R04).
                if (busy_left != 0) next_trans = AHB_TRANS_BUSY;
                else                next_trans = AHB_TRANS_SEQ;
                drive_addr(next_trans, next_a, write, burst, size, prot, nonsec, lock);
                a_beat = (busy_left == 0);
              end else begin
                drive_idle_addr();
              end
            end else begin
              hwdata_q <= '0;  // no data phase starts: write data not valid (POL-03)
              if (busy_left != 0) begin
                // One BUSY phase accepted (zero-wait OKAY, AHB-R04); then the SEQ.
                busy_left--;
                if (busy_left == 0) begin
                  drive_addr(AHB_TRANS_SEQ, beat_addr[a_idx], write, burst, size, prot,
                             nonsec, lock);
                  a_beat = 1'b1;
                end
              end
            end
            if (!a_beat && busy_left == 0 && !d_valid) break;  // last data phase done
          end
        end
        begin : reset_watch      // RST-2/RST-3: abandon the burst at the reset edge
          wait (HRESETn !== 1'b1);
          st = AHB_ST_RESET_ABORTED;
        end
      join_any
      disable fork;
    end join

    // Back to IDLE (AHB-R03); see the task header for back-to-back bursts.
    drive_idle_all();
    status    = st;
    in_flight = 1'b0;
  endtask

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  // 1 when the burst shape is legal and fits this bus: len beats of a known
  // HBURST (AHB-R09, POL-04) and an HSIZE no wider than the bus (AHB-R06).
  function automatic bit burst_shape_ok(logic [2:0] burst, logic [2:0] size, int unsigned len);
    int unsigned fixed_beats;
    if ($isunknown(burst) || $isunknown(size)) return 1'b0;
    if (len == 0 || len > AHB_MAX_BEATS) return 1'b0;
    fixed_beats = ahb_burst_beats(burst);
    if (burst != AHB_BURST_INCR && len != fixed_beats) return 1'b0;
    return ahb_size_bytes(size) <= unsigned'(DATA_WIDTH / 8);
  endfunction

  // Schedule one address phase with NBAs. Absent HPROT[6:4] and HNONSEC are
  // driven 0 (POL-03); the same control is kept for every beat (AHB-R05).
  task automatic drive_addr(
    input ahb_trans_e            trans,
    input logic [ADDR_WIDTH-1:0] a,
    input bit                    write,
    input logic [2:0]            burst,
    input logic [2:0]            size,
    input logic [6:0]            prot,
    input logic                  nonsec,
    input logic                  lock
  );
    htrans_q    <= trans;
    haddr_q     <= a;
    hwrite_q    <= write;
    hburst_q    <= burst;
    hsize_q     <= size;
    hprot_q     <= features.ext_mem_types ? prot : {3'b000, prot[3:0]};
    hnonsec_q   <= features.secure_transfers ? nonsec : 1'b0;
    hmastlock_q <= lock;
  endtask

  // IDLE address phase with address and control driven to 0 (AHB-R03, POL-03)
  task automatic drive_idle_addr();
    htrans_q    <= AHB_TRANS_IDLE;
    haddr_q     <= '0;
    hwrite_q    <= 1'b0;
    hburst_q    <= 3'b000;
    hsize_q     <= 3'b000;
    hprot_q     <= 7'b0000000;
    hnonsec_q   <= 1'b0;
    hmastlock_q <= 1'b0;
  endtask

  // IDLE address phase and no write data (RST-1, AHB-R19)
  task automatic drive_idle_all();
    drive_idle_addr();
    hwdata_q <= '0;
  endtask

  // RST-1/RST-2: return to IDLE as soon as reset asserts (or goes X/Z)
  always @(HRESETn)
    if (HRESETn !== 1'b1) drive_idle_all();

  // Elaboration-time checks (widths must match the shared ahb_if)
  if (DATA_WIDTH % 8 != 0) begin : g_bad_data_width
    $error("ahb_driver_bfm_if: DATA_WIDTH=%0d is not a whole number of bytes", DATA_WIDTH);
  end
  if (ADDR_WIDTH < 1 || ADDR_WIDTH > AHB_FN_AW) begin : g_bad_addr_width
    $error("ahb_driver_bfm_if: ADDR_WIDTH=%0d outside 1..%0d", ADDR_WIDTH, AHB_FN_AW);
  end

endinterface : ahb_driver_bfm_if
