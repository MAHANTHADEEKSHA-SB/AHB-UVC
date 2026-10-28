//*****************************************************//
//    COMPONENT : AHB_SLAVE_AGENT                      //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_slv_agent.sv                     //
//*****************************************************//
//-------------------------------------------------------------------
class ahb_slv_agent extends uvm_agent;
   // agent analysis port
   uvm_analysis_port #(ahb_slv_seq_item) slave_agent_ap;

   // slave sequencer handle
   ahb_slv_sequencer slv_sequencer;
   
   // slave driver handle 
   ahb_slv_driver slv_driver;
   
   // slave monitor
   ahb_slv_monitor slv_monitor;

   // factory registration
   `uvm_component_utils(ahb_slv_agent)
   
   // constructor
   function new(string name = "ahb_slv_agent",uvm_component parent);
      super.new(name,parent);
   endfunction : new

   // build_phase
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      slave_agent_ap = new("slave_agent_ap",this);
   
      slv_monitor   = ahb_slv_monitor :: type_id :: create("ahb_slv_monitor",this);   
      slv_driver    = ahb_slv_driver :: type_id :: create("ahb_slv_driver",this);
      slv_sequencer = ahb_slv_sequencer :: type_id :: create("ahb_slv_sequencer",this);
   endfunction : build_phase

   // connect_phase
   virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      slv_driver.seq_item_port.connect(slv_sequencer.seq_item_export);
      slv_driver.rsp_port.connect(slv_sequencer.rsp_export);
      slv_monitor.slv_monitor_ap.connect(slave_agent_ap);
   endfunction : connect_phase
endclass : ahb_slv_agent
