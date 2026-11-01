// -----------------------------------------------------------------------------
// ahb_base_seq — base sequence with single-burst helpers
//
// new_item() gives every item the bus context of the agent the sequence runs
// on, so randomized values always fit that instance (lossless rule). The
// helpers randomize after start_item(), place the directed data, and return
// the completed item, whose response fields were filled in place by
// ahb_driver. Sizes are given in bytes; 0 means the full bus width.
// Protocol-generic: no DUT register map or memory model lives here.
// Included by ahb_uvc_pkg.
// -----------------------------------------------------------------------------

class ahb_base_seq extends uvm_sequence #(ahb_transaction);
  `uvm_object_utils(ahb_base_seq)
  `uvm_declare_p_sequencer(ahb_sequencer)

  function new(string name = "ahb_base_seq");
    super.new(name);
  endfunction

  // New item carrying the bus context of the agent this sequence runs on (DATA-03).
  // Requires the sequence to run on an ahb_sequencer (p_sequencer).
  protected function ahb_transaction new_item(string name = "item");
    ahb_agent_cfg   cfg = p_sequencer.cfg;
    ahb_transaction t   = ahb_transaction::type_id::create(name);
    t.set_bus_context(cfg.addr_width(), cfg.data_width(), cfg.features.ext_mem_types,
                      cfg.features.secure_transfers);
    return t;
  endfunction

  // HSIZE for a transfer of `bytes` bytes; 0 selects the full bus width.
  protected function ahb_size_e size_for(int unsigned bytes);
    int unsigned b = (bytes == 0) ? p_sequencer.cfg.data_width() / 8 : bytes;
    for (int unsigned k = 0; k < 8; k++)
      if ((32'd1 << k) == b) return ahb_size_e'(k);
    `uvm_fatal("AHB_SEQ", $sformatf("%0d bytes is not an AHB transfer size", b))
    return AHB_SIZE_8;
  endfunction

  // Write burst: one data word per beat (lanes as on HWDATA). data.size() is the
  // beat count; it must match a fixed-length HBURST. busy_between BUSY phases
  // precede every beat after the first (AHB-R04).
  task do_burst_write(input  logic [AHB_MAX_AW-1:0] addr,
                      input  ahb_burst_e            burst,
                      input  logic [AHB_MAX_DW-1:0] data[],
                      output ahb_transaction        t,
                      input  int unsigned           bytes        = 0,
                      input  int unsigned           idle         = 1,
                      input  int unsigned           busy_between = 0);
    ahb_size_e   sz = size_for(bytes);
    int unsigned n  = data.size();
    t          = new_item("burst_write");
    t.max_busy = busy_between;
    start_item(t);
    if (!t.randomize() with { dir == AHB_WRITE; addr == local::addr; burst == local::burst;
                              size == local::sz; len == local::n; idle_cycles == local::idle; })
      `uvm_fatal("AHB_SEQ", $sformatf("cannot randomize %s write @%0h", burst.name(), addr))
    foreach (data[i]) t.wdata[i] = data[i];
    for (int unsigned i = 1; i < n; i++) t.busy[i] = busy_between;
    finish_item(t);
  endtask

  // Read burst of n beats; on return the item holds rdata, resp, wait_states,
  // beats_done and status. busy_between as for do_burst_write().
  task do_burst_read(input  logic [AHB_MAX_AW-1:0] addr,
                     input  ahb_burst_e            burst,
                     input  int unsigned           n,
                     output ahb_transaction        t,
                     input  int unsigned           bytes        = 0,
                     input  int unsigned           idle         = 1,
                     input  int unsigned           busy_between = 0);
    ahb_size_e sz = size_for(bytes);
    t          = new_item("burst_read");
    t.max_busy = busy_between;
    start_item(t);
    if (!t.randomize() with { dir == AHB_READ; addr == local::addr; burst == local::burst;
                              size == local::sz; len == local::n; idle_cycles == local::idle; })
      `uvm_fatal("AHB_SEQ", $sformatf("cannot randomize %s read @%0h", burst.name(), addr))
    for (int unsigned i = 1; i < n; i++) t.busy[i] = busy_between;
    finish_item(t);
  endtask

  // SINGLE write of one word
  task do_write(input  logic [AHB_MAX_AW-1:0] addr,
                input  logic [AHB_MAX_DW-1:0] data,
                output ahb_transaction        t,
                input  int unsigned           bytes = 0,
                input  int unsigned           idle  = 1);
    logic [AHB_MAX_DW-1:0] one[] = new[1];
    one[0] = data;
    do_burst_write(addr, AHB_BURST_SINGLE, one, t, bytes, idle);
  endtask

  // SINGLE read
  task do_read(input  logic [AHB_MAX_AW-1:0] addr,
               output ahb_transaction        t,
               input  int unsigned           bytes = 0,
               input  int unsigned           idle  = 1);
    do_burst_read(addr, AHB_BURST_SINGLE, 1, t, bytes, idle);
  endtask

endclass : ahb_base_seq
