//*****************************************************//
//    COMPONENT : AHB_MASTER_AGENT                     //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_m_agent.sv                       //
//*****************************************************//
class ahb_m_agent extends uvm_agent;
   // agent analysis port
   uvm_analysis_port #(ahb_m_seq_item) master_agent_ap;
   
   // master sequencer handle
   ahb_m_sequencer m_sequencer;
   // master driver handle
   ahb_m_driver    m_driver;
   // master monitor handle
   ahb_m_monitor   m_monitor;

   // factory registration
   `uvm_component_utils(ahb_m_agent)
   
   // constructor
   function new(string name = "ahb_m_agent",uvm_component parent);
      super.new(name,parent);
   endfunction : new
   
   // build_phase
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      master_agent_ap = new("master_agent_ap",this);
      
      m_monitor   = ahb_m_monitor :: type_id :: create("ahb_m_monitor",this);
      m_driver    = ahb_m_driver :: type_id :: create("ahb_m_driver",this);
      m_sequencer = ahb_m_sequencer :: type_id ::create("ahb_m_sequencer",this);

   endfunction : build_phase
   
   // connect_phase
   virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);

      m_monitor.master_mon_ap.connect(master_agent_ap);
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
      m_driver.rsp_port.connect(m_sequencer.rsp_export);
      
   endfunction : connect_phase
endclass : ahb_m_agent
