// -----------------------------------------------------------------------------
// ahb_random_seq — constrained-random AHB bursts in an address window
//
// Direction, HBURST, HSIZE, INCR length, data, BUSY insertion (up to
// max_busy per beat), HPROT[3:0] (when random_prot) and the IDLE gap are
// randomized within the item constraints, so back-to-back bursts
// (idle_cycles == 0) occur naturally. Every burst stays legal for the bound
// bus: aligned, no wider than the bus, inside one 1KB page.
// Included by ahb_uvc_pkg.
// -----------------------------------------------------------------------------

class ahb_random_seq extends ahb_base_seq;
  `uvm_object_utils(ahb_random_seq)

  rand int unsigned      num_items;
  logic [AHB_MAX_AW-1:0] addr_min    = '0;
  logic [AHB_MAX_AW-1:0] addr_max    = 'h3FF;
  int unsigned           max_busy    = 2;     // BUSY phases per beat, 0 = none
  bit                    random_prot = 1'b1;  // switch off the HPROT default

  // Default length; a test overrides it with randomize() with { num_items == N; }.
  constraint c_num_items { soft num_items inside {[1:50]}; }

  // num_items is 20 when the sequence is started without being randomized.
  function new(string name = "ahb_random_seq");
    super.new(name);
    num_items = 20;
  endfunction

  // Each item gets the bus context and the knobs, then a random start address in
  // [addr_min:addr_max]; everything else follows the item constraints.
  virtual task body();
    ahb_transaction t;
    repeat (num_items) begin
      t          = new_item("random");
      t.max_busy = max_busy;
      if (random_prot) t.c_prot_default.constraint_mode(0);
      start_item(t);
      if (!t.randomize() with { addr inside {[local::addr_min:local::addr_max]}; })
        `uvm_fatal("AHB_SEQ", $sformatf("cannot randomize in [%0h:%0h]", addr_min, addr_max))
      finish_item(t);
    end
  endtask

endclass : ahb_random_seq
