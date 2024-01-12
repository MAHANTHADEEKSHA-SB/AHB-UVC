// slave sequence item
class ahb_slv_seq_item extends uvm_sequence_item;
   // factory registration 
   `uvm_object_utils(ahb_slv_seq_item)
   
   // constructor method
   function new(string name = "ahb_slv_seq_item");
      super.new(name);
   endfunction : new

endclass : ahb_slv_seq_item
