//*****************************************************//
//    COMPONENT : AHB_SLAVE_MONITOR                    //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_slv_monitor.sv                   //
//*****************************************************//
//------------------------------------------------------------------------
class ahb_slv_monitor extends uvm_monitor;
   // analysis port to send out the information
   uvm_analysis_port #(ahb_slv_seq_item) slv_monitor_ap;
   
   // factory registration
   `uvm_component_utils(ahb_slv_monitor)
   
   // constructor
   function new(string name = "ahb_slv_monitor", uvm_component parent);
      super.new(name,parent);
   endfunction : new
   
   // build_phase
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      slv_monitor_ap = new("slv_monitor_ap",this);
   endfunction : build_phase
   
   // run_phase
   virtual task run_phase(uvm_phase phase);
      
   endtask : run_phase
 
endclass : ahb_slv_monitor
