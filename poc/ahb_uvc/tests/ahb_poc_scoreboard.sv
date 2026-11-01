// -----------------------------------------------------------------------------
// ahb_poc_scoreboard — reference model of examples/ahb_example_slave
//
// Test infrastructure, not part of the reusable UVC core (contract: no
// DUT-specific scoreboards in the core). It models the fixture's documented
// behaviour for one instance, beat by beat:
//   * byte memory of mem_bytes bytes; a write stores the active lanes of its
//     HSIZE/HADDR; a read returns the whole bus word; unwritten bytes read 0
//   * wait cycles per beat = HADDR[5:4]; addresses >= mem_bytes get the
//     two-cycle ERROR (one wait cycle) and change nothing
//   * a reset event (RST-4) clears the memory, as the fixture does
// It also checks the UVC's cancel-after-ERROR policy end to end (POL-02: an
// ERROR beat is the last beat of its burst) and counts back-to-back bursts.
// Included by ahb_poc_test_pkg.
// -----------------------------------------------------------------------------

// Second analysis input for the reset events (suffix _rst -> write_rst()).
`uvm_analysis_imp_decl(_rst)

class ahb_poc_scoreboard extends uvm_subscriber #(ahb_transaction);
  `uvm_component_utils(ahb_poc_scoreboard)

  uvm_analysis_imp_rst #(ahb_reset_event, ahb_poc_scoreboard) reset_export;

  int unsigned mem_bytes = 512;   // must match ahb_example_slave MEM_BYTES
  bit          enabled   = 1'b1;  // a fault-injection test turns checking off

  int unsigned num_checked;       // bursts checked
  int unsigned num_beats;         // beats checked
  int unsigned num_error_beats;   // ERROR beats seen (all expected by the model)
  int unsigned num_mismatches;
  int unsigned num_b2b;
  int unsigned num_resets;

  protected byte unsigned     mem[int unsigned];
  protected longint unsigned  prev_end;
  protected bit               has_prev;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // The reset input exists from build_phase on, ready for connect_phase.
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    reset_export = new("reset_export", this);
  endfunction

  // RST-4: the fixture clears its memory while reset is asserted; so does the model.
  virtual function void write_rst(ahb_reset_event ev);
    if (!ev.asserted) return;
    mem.delete();
    num_resets++;
    has_prev = 1'b0;
  endfunction

  // Check one observed burst against the fixture model: per beat the response and
  // wait cycles follow from the address; reads must match the model; writes update
  // it on their active lanes. Back-to-back bursts are counted even when disabled.
  virtual function void write(ahb_transaction t);
    int unsigned nbytes = t.bus_data_width / 8;

    if (has_prev && t.start_cycle <= prev_end + 1) num_b2b++;
    prev_end = t.end_cycle;
    has_prev = 1'b1;
    if (!enabled) return;

    num_checked++;
    for (int unsigned i = 0; i < t.beats_done; i++) begin
      int unsigned           a         = int'(t.beat_addr[i]);
      int unsigned           base      = a - (a % nbytes);
      bit                    exp_err   = (a >= mem_bytes);
      int unsigned           exp_waits = exp_err ? 1 : ((a >> 4) & 3);
      logic [AHB_MAX_SW-1:0] lanes     = t.lanes_at(t.beat_addr[i]);
      logic [AHB_MAX_DW-1:0] expected  = '0;

      num_beats++;
      if (t.resp[i] !== exp_err)
        mismatch(t, $sformatf("beat %0d @%0h: HRESP %b, expected %b", i, a, t.resp[i], exp_err));
      if (t.wait_states[i] != exp_waits)
        mismatch(t, $sformatf("beat %0d @%0h: %0d wait cycles, expected %0d", i, a,
                              t.wait_states[i], exp_waits));
      if (exp_err) begin
        num_error_beats++;
        if (i + 1 != t.beats_done)  // POL-02: the ERROR beat ends the burst
          mismatch(t, $sformatf("beat %0d ERROR was not the last beat", i));
        continue;
      end
      if (t.dir == AHB_WRITE) begin
        for (int unsigned l = 0; l < nbytes; l++)
          if (lanes[l]) mem[base + l] = t.wdata[i][8*l +: 8];
      end else begin
        for (int unsigned l = 0; l < nbytes; l++)
          expected[8*l +: 8] = mem.exists(base + l) ? mem[base + l] : 8'h00;
        if (t.rdata[i] !== expected)
          mismatch(t, $sformatf("beat %0d @%0h: rdata %0h, expected %0h", i, a, t.rdata[i],
                                expected));
      end
    end
  endfunction

  // Count and report one mismatch (AHB_SB).
  protected function void mismatch(ahb_transaction t, string what);
    num_mismatches++;
    `uvm_error("AHB_SB", {get_full_name(), ": ", what, " | ", t.convert2string()})
  endfunction

  // Summary line per instance.
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("AHB_SB", $sformatf("%s: %0d bursts / %0d beats checked, %0d ERROR beats, %s",
                                  get_full_name(), num_checked, num_beats, num_error_beats,
                                  $sformatf("%0d mismatches, %0d back-to-back, %0d resets",
                                            num_mismatches, num_b2b, num_resets)), UVM_LOW)
  endfunction

endclass : ahb_poc_scoreboard
