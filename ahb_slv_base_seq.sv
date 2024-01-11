// base sequence class for slave sequences
class ahb_slv_base_seq extends uvm_sequence #(ahb_slv_seq_item);
  // factory registration
  `uvm_object_utils(ahb_slv_base_seq)
  // constructor
  function new(string name = "ahb_slv_base_seq");
    super.new(name);
  endfunction : new
  
endclass : ahb_slv_base_seq