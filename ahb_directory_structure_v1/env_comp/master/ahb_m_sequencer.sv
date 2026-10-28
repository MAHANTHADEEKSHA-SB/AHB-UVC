//*****************************************************//
//    COMPONENT : AHB_MASTER_SEQUENCER                 //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_m_sequencer.sv                   //
//*****************************************************//
//--------------------------------------------------------------------
class ahb_m_sequencer extends uvm_sequencer #(ahb_m_seq_item);
   // factory registration
   `uvm_component_utils(ahb_m_sequencer)
   // constructor method
   function new(string name = "ahb_m_sequencer",uvm_component parent);
      super.new(name,parent);
   endfunction : new

endclass : ahb_m_sequencer
