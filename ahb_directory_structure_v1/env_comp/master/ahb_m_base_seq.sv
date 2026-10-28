// base sequence for master sequences
class ahb_m_base_seq extends uvm_sequence #(ahb_m_seq_item);
  // factory registration
  `uvm_object_utils(ahb_m_base_seq)
  // constructor
  function new(string name = "ahb_m_base_seq");
    super.new(name);
  endfunction : new
endclass : ahb_m_base_seq