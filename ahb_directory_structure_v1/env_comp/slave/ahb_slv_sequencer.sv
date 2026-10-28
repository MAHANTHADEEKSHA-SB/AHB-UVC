// slave sequencer class 
class ahb_slv_sequencer extends uvm_sequencer #(ahb_slv_seq_item);
   // factory registrtion
   `uvm_component_utils(ahb_slv_sequencer)
   
   // constructor method
   function new(string name = "ahb_slv_sequencer",uvm_component parent);
      super.new(name,parent);
   endfunction : new

endclass : ahb_slv_sequencer
