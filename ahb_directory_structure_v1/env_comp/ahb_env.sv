//*****************************************************//
//    COMPONENT : AHB_ENVIRONMENT                      //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_env.sv                           //
//*****************************************************//
//-----------------------------------------------------------------------------
class ahb_env extends uvm_env;
   // master agent
   ahb_m_agent ahb_master;
   
   // slave agent
   ahb_slv_agent ahb_slave;

   // scoreboard handle
   ahb_scoreboard scoreboard;
   
   // factory registration
   `uvm_component_utils(ahb_env)
   
   // constructor method
   function new(string name = "ahb_env",uvm_component parent);
      super.new(name,parent);
   endfunction : new

   // build_phase
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ahb_master = ahb_m_agent :: type_id :: create("ahb_master",this);
      ahb_slave  = ahb_slv_agent :: type_id :: create("ahb_slave",this);
      
      scoreboard = ahb_scoreboard :: type_id :: create("scoreboard",this);
   endfunction : build_phase

   // connect_phase
   virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      ahb_master.master_agent_ap.connect(scoreboard.master_imp);
      ahb_slave.slave_agent_ap.connect(scoreboard.slave_imp); 
   endfunction : connect_phase
endclass : ahb_env
