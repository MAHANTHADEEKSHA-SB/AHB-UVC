// -----------------------------------------------------------------------------
// ahb_hdl_smoke — HDL-only directed smoke test (AHB-003a acceptance, no UVM)
//
// Runs the same directed bursts concurrently on instance A (DW=32) and
// instance B (DW=64) of ahb_hdl_top, each on its own clock and reset. Each
// instance is reached only through typed virtual BFM handles held by a
// width-parameterized class: the access pattern the HVL adapters use
// (RISK-001).
//
// Checks per instance: SINGLE write/read-back with 0 and 2 wait states,
// INCR4 with and without wait states, WRAP4, INCR with BUSY phases, a
// narrow byte write merged into a word, a back-to-back write->read (POL-05),
// a SINGLE ERROR and an INCR4 that runs into ERROR and is cancelled
// (AHB-R14/R15). Driver results, read data (against a model of the fixture)
// and every published burst are checked; the monitor must publish exactly
// the expected bursts and report zero protocol errors. The passive observer
// P on bus A must count the same bursts with no errors (drive release).
//
// Negative control: +AHB_FAULT=<n> (ahb_fault_e) injects a fault on instance
// A only. The test then passes only if A's monitor and P's monitor report the
// matching violation and instance B stays error-free (isolation).
//
// Result line: "SMOKE_RESULT: PASS" or "SMOKE_RESULT: FAIL".
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module ahb_hdl_smoke;
  import ahb_bfm_pkg::*;

  ahb_hdl_top u_top ();

  // One runner per instance. It reaches its instance only through typed virtual
  // BFM handles, as the HVL adapters do (RISK-001).
  class smoke_runner #(int AW = 32, int DW = 32);
    typedef virtual ahb_driver_bfm_if  #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW)) drv_vif_t;
    typedef virtual ahb_monitor_bfm_if #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW)) mon_vif_t;
    localparam int unsigned NB        = AHB_MAX_BEATS;
    localparam int unsigned BUS_BYTES = DW / 8;
    localparam int unsigned MEM_BYTES = 512;  // must match ahb_example_slave
    localparam logic [63:0] P1 = 64'hA5A5_5A5A_DEAD_BEEF;
    localparam logic [63:0] P2 = 64'h0123_4567_89AB_CDEF;
    localparam logic [63:0] P3 = 64'hFEDC_BA98_7654_3210;
    localparam logic [63:0] P4 = 64'h1357_9BDF_2468_ACE0;

    // One expected burst observation
    typedef struct {
      bit            write;
      logic [AW-1:0] addr;
      logic [2:0]    burst;
      logic [2:0]    size;
      int unsigned   beats;
      logic [AW-1:0] beat_addr [NB];
      logic [DW-1:0] data      [NB];  // wdata of writes, rdata of reads
      logic          resp      [NB];
      int unsigned   waits     [NB];
      int unsigned   busy      [NB];
      bit            b2b;             // NONSEQ right after the previous burst
    } exp_t;

    string        name;
    drv_vif_t     drv;
    mon_vif_t     mon;
    ahb_fault_e   fault;
    int unsigned  failures;
    exp_t         exp_q[$];
    byte unsigned mem[int unsigned];  // model of the fixture memory

    function new(string name, drv_vif_t drv, mon_vif_t mon, ahb_fault_e fault);
      this.name  = name;
      this.drv   = drv;
      this.mon   = mon;
      this.fault = fault;
    endfunction

    // Record one failed expectation; the run continues so every problem is reported.
    function void check(bit ok, string msg);
      if (!ok) begin
        failures++;
        $display("SMOKE_FAIL [%s] %s", name, msg);
      end
    endfunction

    // HSIZE for a transfer of `bytes` bytes; 0 selects the full bus width.
    function logic [2:0] size_code(int unsigned bytes);
      int unsigned b = (bytes == 0) ? BUS_BYTES : bytes;
      for (int unsigned k = 0; k < 8; k++)
        if ((32'd1 << k) == b) return 3'(k);
      return 3'b000;
    endfunction

    // Data word of beat i: pattern p plus i in every byte
    function logic [DW-1:0] pattern(logic [63:0] p, int unsigned i);
      return DW'(p + 64'h0101_0101_0101_0101 * 64'(i));
    endfunction

    // Fixture model: the whole bus word that holds address a (unwritten bytes are 0)
    function logic [DW-1:0] model_word(logic [AW-1:0] a);
      logic [DW-1:0] w    = '0;
      int unsigned   base = int'(a) - int'(a % BUS_BYTES);
      for (int unsigned l = 0; l < BUS_BYTES; l++)
        if (mem.exists(base + l)) w[8*l +: 8] = mem[base + l];
      return w;
    endfunction

    // Fixture model: store the active byte lanes of one write beat (AHB-R20)
    function void model_write(logic [AW-1:0] a, int unsigned bytes, logic [DW-1:0] d);
      int unsigned base  = int'(a) - int'(a % BUS_BYTES);
      int unsigned first = int'(a % BUS_BYTES);
      for (int unsigned l = first; l < first + bytes; l++) mem[base + l] = d[8*l +: 8];
    endfunction

    // One burst through the driver BFM. In positive mode, compute the expected
    // beats from the fixture's rules (wait states = HADDR[5:4]; two-cycle ERROR
    // at or above MEM_BYTES, after which the BFM cancels the rest, POL-02), check
    // the driver results and record what the monitor must publish.
    task automatic burst(bit write, logic [AW-1:0] addr, ahb_burst_e kind, int unsigned bytes,
                         int unsigned len, logic [63:0] seed, int unsigned busy_mid,
                         int unsigned idle, bit b2b);
      logic [DW-1:0]   wdata [NB];
      int unsigned     busy  [NB];
      logic [AW-1:0]   baddr [NB];
      logic [DW-1:0]   rdata [NB];
      logic            resp  [NB];
      int unsigned     waits [NB];
      int unsigned     done;
      ahb_bfm_status_e st;
      exp_t            e;
      logic [2:0]      sz;
      logic [AW-1:0]   a;
      bit              err;

      sz = size_code(bytes);
      for (int unsigned i = 0; i < NB; i++) begin
        wdata[i] = write ? pattern(seed, i) : '0;
        busy[i]  = (i == 0) ? 0 : busy_mid;
      end
      drv.do_burst(write, addr, kind, sz, len, 7'b0000011, 1'b0, 1'b0, wdata, busy, idle, 64,
                   baddr, rdata, resp, waits, done, st);
      if (fault != AHB_FAULT_NONE) return;  // only the monitor verdict matters

      e.write = write;
      e.addr  = addr;
      e.burst = kind;
      e.size  = sz;
      e.beats = 0;
      e.b2b   = b2b;
      for (int unsigned i = 0; i < NB; i++) begin
        e.beat_addr[i] = '0;
        e.data[i]      = '0;
        e.resp[i]      = 1'b0;
        e.waits[i]     = 0;
        e.busy[i]      = 0;
      end
      a   = addr;
      err = 1'b0;
      for (int unsigned i = 0; i < len && !err; i++) begin
        err            = (a >= MEM_BYTES);
        e.beat_addr[i] = a;
        e.busy[i]      = busy[i];
        e.resp[i]      = err;
        e.waits[i]     = err ? 1 : int'(a[5:4]);
        if (write) begin
          e.data[i] = wdata[i];
          if (!err) model_write(a, 32'd1 << sz, wdata[i]);
        end else begin
          e.data[i] = err ? '0 : model_word(a);
        end
        e.beats++;
        a = AW'(ahb_next_addr(AHB_FN_AW'(a), sz, kind));
      end

      check(st == (err ? AHB_ST_ERROR : AHB_ST_OK),
            $sformatf("%s @%0h: status %s", kind.name(), addr, st.name()));
      check(done == e.beats,
            $sformatf("%s @%0h: %0d beats done, expected %0d", kind.name(), addr, done, e.beats));
      for (int unsigned i = 0; i < e.beats; i++) begin
        check(baddr[i] === e.beat_addr[i],
              $sformatf("@%0h beat %0d: address %0h, expected %0h", addr, i, baddr[i],
                        e.beat_addr[i]));
        check(waits[i] == e.waits[i],
              $sformatf("@%0h beat %0d: %0d wait cycles, expected %0d", addr, i, waits[i],
                        e.waits[i]));
        check(resp[i] === e.resp[i],
              $sformatf("@%0h beat %0d: HRESP %b, expected %b", addr, i, resp[i], e.resp[i]));
        if (!write)
          check(rdata[i] === e.data[i],
                $sformatf("@%0h beat %0d: rdata %0h, expected %0h", addr, i, rdata[i],
                          e.data[i]));
      end
      exp_q.push_back(e);
    endtask

    // Configure both BFMs (AHB5 defaults), enable the driver, run the directed
    // bursts, then check the monitor (positive mode) or the injected fault.
    task automatic run();
      ahb_features_t f = ahb_default_features();
      check(drv.configure(f), "driver configure() rejected the default features");
      check(mon.configure(f), "monitor configure() rejected the default features");
      mon.set_publish(1'b1);
      drv.set_fault(fault);
      drv.set_enable(1'b1);
      drv.wait_for_reset_release(1);

      //     dir addr    kind              bytes len seed busy idle b2b
      burst(1, 'h000, AHB_BURST_SINGLE, 0,    1,  P1,  0,   1,   0);  // 0 waits
      burst(0, 'h000, AHB_BURST_SINGLE, 0,    1,  P1,  0,   1,   0);
      burst(1, 'h020, AHB_BURST_SINGLE, 0,    1,  P2,  0,   1,   0);  // 2 waits
      burst(0, 'h020, AHB_BURST_SINGLE, 0,    1,  P2,  0,   1,   0);
      burst(1, 'h040, AHB_BURST_INCR4,  0,    4,  P3,  0,   1,   0);
      burst(0, 'h040, AHB_BURST_INCR4,  0,    4,  P3,  0,   1,   0);
      burst(1, 'h0A0, AHB_BURST_INCR4,  0,    4,  P4,  0,   1,   0);  // waited SEQ beats
      burst(0, 'h0A0, AHB_BURST_INCR4,  0,    4,  P4,  0,   1,   0);
      burst(1, 'h088, AHB_BURST_WRAP4,  0,    4,  P1,  0,   1,   0);  // wraps
      burst(0, 'h088, AHB_BURST_WRAP4,  0,    4,  P1,  0,   1,   0);
      burst(1, 'h0C0, AHB_BURST_INCR,   0,    3,  P2,  1,   1,   0);  // BUSY before beats 1, 2
      burst(0, 'h0C0, AHB_BURST_INCR,   0,    3,  P2,  0,   1,   0);
      burst(1, 'h110, AHB_BURST_SINGLE, 0,    1,  P3,  0,   1,   0);
      burst(1, 'h111, AHB_BURST_SINGLE, 1,    1,  '1,  0,   1,   0);  // byte lane 1 only
      burst(0, 'h110, AHB_BURST_SINGLE, 0,    1,  P3,  0,   1,   0);  // merged word
      burst(1, 'h008, AHB_BURST_SINGLE, 0,    1,  P4,  0,   1,   0);
      burst(0, 'h008, AHB_BURST_SINGLE, 0,    1,  P4,  0,   0,   1);  // back-to-back
      burst(0, 'h200, AHB_BURST_SINGLE, 0,    1,  P1,  0,   1,   0);  // ERROR
      burst(1, 'h1F8, AHB_BURST_INCR4,  4,    4,  P2,  0,   1,   0);  // OK, OK, ERROR, cancel
      burst(0, 'h1F8, AHB_BURST_INCR,   4,    2,  P2,  0,   1,   0);  // the two stored beats

      if (fault != AHB_FAULT_NONE) check_fault_detected();
      else                         check_monitor();
    endtask

    // Monitor code that a fault mode must trigger
    function ahb_mon_error_e expected_error();
      case (fault)
        AHB_FAULT_ADDR_UNSTABLE: return AHB_MON_ERR_UNSTABLE_IN_WAIT;
        AHB_FAULT_BAD_SEQ_ADDR:  return AHB_MON_ERR_BURST_ADDR;
        default:                 return AHB_MON_ERR_BURST_LENGTH;
      endcase
    endfunction

    // Negative mode: pass only if the violation matching the injected fault was counted.
    task automatic check_fault_detected();
      ahb_mon_error_e want = expected_error();
      check(mon.get_error_count(want) > 0,
            $sformatf("injected %s NOT detected (%s count is 0)", fault.name(), want.name()));
      $display("SMOKE_INFO [%s] fault %s -> monitor %s count=%0d, total errors=%0d",
               name, fault.name(), want.name(), mon.get_error_count(want),
               mon.get_total_errors());
    endtask

    // Positive mode: each expected burst observed once, in order, with matching
    // beats, data, responses, wait and BUSY counts, and cycle stamps consistent with
    // them; nothing extra published afterwards.
    task automatic check_monitor();
      bit              write;
      logic [AW-1:0]   addr;
      logic [2:0]      kind;
      logic [2:0]      size;
      logic [6:0]      prot;
      logic            nonsec;
      logic            lock;
      int unsigned     beats;
      logic [AW-1:0]   baddr [NB];
      logic [DW-1:0]   wdata [NB];
      logic [DW-1:0]   rdata [NB];
      logic            resp  [NB];
      int unsigned     waits [NB];
      int unsigned     busy  [NB];
      longint unsigned start_c;
      longint unsigned end_c;
      longint unsigned prev_end;
      longint unsigned span;

      // Drain the expected observations first: the driver returns at the completion
      // edge, possibly before the monitor has sampled that edge.
      prev_end = 0;
      foreach (exp_q[k]) begin
        mon.get_burst(write, addr, kind, size, prot, nonsec, lock, beats, baddr, wdata, rdata,
                      resp, waits, busy, start_c, end_c);
        check(write == exp_q[k].write && addr === exp_q[k].addr && kind === exp_q[k].burst &&
              size === exp_q[k].size,
              $sformatf("obs %0d: %s @%0h burst=%0d size=%0d, expected %s @%0h burst=%0d",
                        k, write ? "WR" : "RD", addr, kind, size,
                        exp_q[k].write ? "WR" : "RD", exp_q[k].addr, exp_q[k].burst));
        check(beats == exp_q[k].beats,
              $sformatf("obs %0d: %0d beats, expected %0d", k, beats, exp_q[k].beats));
        span = 0;
        for (int unsigned i = 0; i < beats && i < NB; i++) begin
          check(baddr[i] === exp_q[k].beat_addr[i],
                $sformatf("obs %0d beat %0d: address %0h, expected %0h", k, i, baddr[i],
                          exp_q[k].beat_addr[i]));
          check((write ? wdata[i] : rdata[i]) === exp_q[k].data[i],
                $sformatf("obs %0d beat %0d: data %0h, expected %0h", k, i,
                          write ? wdata[i] : rdata[i], exp_q[k].data[i]));
          check(resp[i] === exp_q[k].resp[i] && waits[i] == exp_q[k].waits[i] &&
                busy[i] == exp_q[k].busy[i],
                $sformatf("obs %0d beat %0d: resp=%b waits=%0d busy=%0d, expected %b/%0d/%0d",
                          k, i, resp[i], waits[i], busy[i], exp_q[k].resp[i],
                          exp_q[k].waits[i], exp_q[k].busy[i]));
          span += 64'(1 + waits[i] + busy[i]);
        end
        // Each beat takes one cycle plus its wait states, plus the BUSY phases before it.
        check(end_c - start_c == span,
              $sformatf("obs %0d: NONSEQ@%0d END@%0d inconsistent with %0d cycles",
                        k, start_c, end_c, span));
        if (exp_q[k].b2b)
          check(start_c == prev_end + 64'd1,
                $sformatf("obs %0d: NONSEQ@%0d, expected right after completion @%0d",
                          k, start_c, prev_end));
        prev_end = end_c;
      end

      // Nothing extra may be published afterwards
      repeat (4) @(posedge drv.HCLK);
      check(mon.transfer_count == unsigned'(exp_q.size()),
            $sformatf("monitor saw %0d bursts, expected %0d", mon.transfer_count, exp_q.size()));
      check(mon.get_total_errors() == 0,
            $sformatf("monitor reported %0d protocol errors", mon.get_total_errors()));
      $display("SMOKE_INFO [%s] %0d bursts checked, monitor errors=%0d",
               name, exp_q.size(), mon.get_total_errors());
    endtask
  endclass : smoke_runner

  smoke_runner #(32, 32) run_a;
  smoke_runner #(32, 64) run_b;

  // Main: one runner per instance, run concurrently; then the passive observer P
  // (monitor-only, driver BFM never enabled) and the result line.
  initial begin
    ahb_fault_e     fault_a;
    int unsigned    fault_arg;
    ahb_mon_error_e want;
    bit             pass;
    bit             p_ok;

    fault_a = AHB_FAULT_NONE;
    if ($value$plusargs("AHB_FAULT=%d", fault_arg)) fault_a = ahb_fault_e'(fault_arg);

    run_a = new("A DW=32", u_top.drv_a, u_top.mon_a, fault_a);
    run_b = new("B DW=64", u_top.drv_b, u_top.mon_b, AHB_FAULT_NONE);

    fork
      run_a.run();
      run_b.run();
    join

    // P keeps its default (AHB5) features, which match A's configuration.
    if (fault_a == AHB_FAULT_NONE) begin
      p_ok = (u_top.mon_p.transfer_count == u_top.mon_a.transfer_count) &&
             (u_top.mon_p.get_total_errors() == 0);
    end else begin
      want = run_a.expected_error();
      p_ok = (u_top.mon_p.get_error_count(want) > 0);
    end
    if (!p_ok)
      $display("SMOKE_FAIL [P passive] bursts=%0d (A %0d) errors=%0d",
               u_top.mon_p.transfer_count, u_top.mon_a.transfer_count,
               u_top.mon_p.get_total_errors());

    pass = (run_a.failures == 0) && (run_b.failures == 0) && p_ok;
    $display("SMOKE_SUMMARY mode=%s A.failures=%0d B.failures=%0d B.monitor_errors=%0d",
             fault_a.name(), run_a.failures, run_b.failures, u_top.mon_b.get_total_errors());
    $display("SMOKE_RESULT: %s", pass ? "PASS" : "FAIL");
    $finish;
  end

  // Watchdog: report a hang as a failure.
  initial begin
    #500us;
    $display("SMOKE_RESULT: FAIL (watchdog timeout)");
    $finish;
  end

endmodule : ahb_hdl_smoke
