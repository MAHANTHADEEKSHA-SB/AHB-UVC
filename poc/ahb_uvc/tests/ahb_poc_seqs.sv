// -----------------------------------------------------------------------------
// ahb_poc_seqs — test sequences for the POC fixture
//
// ahb_poc_directed_seq: the same directed bursts as the HDL smoke test,
//   expressed in UVM: SINGLE with 0 and 2 wait states (HADDR[5:4]), INCR4
//   with and without waited SEQ beats, WRAP4, INCR with BUSY phases, a byte
//   write merged into a word, a back-to-back write->read, a SINGLE ERROR and
//   an INCR4 that runs into ERROR and is cancelled. Data is checked by
//   ahb_poc_scoreboard.
// ahb_long_write_seq: one INCR16 write, long enough to be cut by a reset
//   (ahb_reset_test).
// ahb_unfit_write_seq: a write whose data does not fit the bus, to prove the
//   drive adapter rejects it instead of truncating (RISK-003).
// Included by ahb_poc_test_pkg.
// -----------------------------------------------------------------------------

class ahb_poc_directed_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_poc_directed_seq)

  typedef logic [AHB_MAX_DW-1:0] data_a_t[];

  localparam logic [63:0] P1 = 64'hA5A5_5A5A_DEAD_BEEF;
  localparam logic [63:0] P2 = 64'h0123_4567_89AB_CDEF;
  localparam logic [63:0] P3 = 64'hFEDC_BA98_7654_3210;
  localparam logic [63:0] P4 = 64'h1357_9BDF_2468_ACE0;

  function new(string name = "ahb_poc_directed_seq");
    super.new(name);
  endfunction

  // n data words from pattern p (plus the beat index in every byte), masked to
  // the instance width so the same sequence runs on DW=32 and DW=64.
  protected function data_a_t beats(logic [63:0] p, int unsigned n,
                                    logic [AHB_MAX_DW-1:0] mask);
    data_a_t d = new[n];
    foreach (d[i]) d[i] = AHB_MAX_DW'(p + 64'h0101_0101_0101_0101 * 64'(i)) & mask;
    return d;
  endfunction

  // Addresses are aligned for both instances (8 bytes) and below the fixture's
  // 512-byte memory unless the comment says ERROR.
  virtual task body();
    ahb_transaction        t;
    int unsigned           dw   = p_sequencer.cfg.data_width();
    logic [AHB_MAX_DW-1:0] mask = '0;

    for (int unsigned i = 0; i < dw; i++) mask[i] = 1'b1;

    do_burst_write('h000, AHB_BURST_SINGLE, beats(P1, 1, mask), t);
    do_read       ('h000, t);
    do_burst_write('h020, AHB_BURST_SINGLE, beats(P2, 1, mask), t);   // 2 wait states
    do_read       ('h020, t);
    do_burst_write('h040, AHB_BURST_INCR4,  beats(P3, 4, mask), t);
    do_burst_read ('h040, AHB_BURST_INCR4,  4, t);
    do_burst_write('h0A0, AHB_BURST_INCR4,  beats(P4, 4, mask), t);   // waited SEQ beats
    do_burst_read ('h0A0, AHB_BURST_INCR4,  4, t);
    do_burst_write('h088, AHB_BURST_WRAP4,  beats(P1, 4, mask), t);   // wraps
    do_burst_read ('h088, AHB_BURST_WRAP4,  4, t);
    do_burst_write('h0C0, AHB_BURST_INCR,   beats(P2, 3, mask), t, 0, 1, 1);  // BUSY
    do_burst_read ('h0C0, AHB_BURST_INCR,   3, t);
    do_burst_write('h110, AHB_BURST_SINGLE, beats(P3, 1, mask), t);
    do_write      ('h111, mask, t, 1);                                // byte lane 1
    do_read       ('h110, t);                                         // merged word
    do_burst_write('h008, AHB_BURST_SINGLE, beats(P4, 1, mask), t);
    do_read       ('h008, t, 0, 0);                                   // back-to-back
    do_read       ('h200, t);                                         // ERROR
    do_burst_write('h1F8, AHB_BURST_INCR4,  beats(P2, 4, mask), t, 4);  // OK OK ERROR
    do_burst_read ('h1F8, AHB_BURST_INCR,   2, t, 4);                 // the stored beats
  endtask

endclass : ahb_poc_directed_seq


// Reset-test helper: one INCR16 write of whole bus words; the completed item is
// kept in result so the test can check its status.
class ahb_long_write_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_long_write_seq)

  ahb_transaction result;

  function new(string name = "ahb_long_write_seq");
    super.new(name);
  endfunction

  // Sixteen beats from 'h040 with 0..3 wait states each (HADDR[5:4]).
  virtual task body();
    logic [AHB_MAX_DW-1:0] d[] = new[16];
    int unsigned           dw  = p_sequencer.cfg.data_width();
    foreach (d[i])
      for (int unsigned b = 0; b < dw; b++) d[i][b] = (b % 3 == i % 3);
    do_burst_write('h040, AHB_BURST_INCR16, d, result);
  endtask

endclass : ahb_long_write_seq


// Negative-test helper: one SINGLE write whose data is wider than the bus.
class ahb_unfit_write_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_unfit_write_seq)

  ahb_transaction result;

  function new(string name = "ahb_unfit_write_seq");
    super.new(name);
  endfunction

  // Randomize a legal write, then set a data bit just above the bus width: only
  // the data is out of range. The completed item is kept in result.
  virtual task body();
    ahb_transaction t  = new_item("unfit");
    int unsigned    dw = p_sequencer.cfg.data_width();
    if (dw >= AHB_MAX_DW)
      `uvm_fatal("AHB_SEQ", "bus is as wide as the transaction maxima; nothing can be unfit")
    start_item(t);
    if (!t.randomize() with { dir == AHB_WRITE; burst == AHB_BURST_SINGLE; addr == 'h10;
                              idle_cycles == 1; })
      `uvm_fatal("AHB_SEQ", "cannot randomize the unfit write")
    t.wdata[0][dw] = 1'b1;
    finish_item(t);
    result = t;
  endtask

endclass : ahb_unfit_write_seq
