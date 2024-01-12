//*****************************************************//
//    COMPONENT : AHB_SCOREBOARD                       //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_scoreboard.sv                    //
//*****************************************************//
//------------------------------------------------------------------------------
// imp decl macro for two different imp ports
`uvm_analysis_imp_decl(_slv)
`uvm_analysis_imp_decl(_mas)
//------------------------------------------------------------------------------
class ahb_scoreboard extends uvm_scoreboard;
   // master analysis imp
   uvm_analysis_imp_mas #(ahb_m_seq_item,ahb_scoreboard) master_imp;
   
   // slave analysis imp
   uvm_analysis_imp_slv #(ahb_slv_seq_item, ahb_scoreboard) slave_imp;
 
   // factory registration
   `uvm_component_utils(ahb_scoreboard)
   
   // constructor
   function new(string name = "ahb_scoreboard",uvm_component parent);
      super.new(name,parent);
   endfunction : new
   
   // build_phase
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      master_imp = new("master_imp",this);
      slave_imp  = new("slave_imp",this);
   endfunction : build_phase
    
   // master imp write method
   virtual function void write_mas(ahb_m_seq_item item);
      item.print();
   endfunction : write_mas

   // slave imp write method
   virtual function void write_slv(ahb_slv_seq_item item);
      
   endfunction : write_slv
   
   // run_phase
   virtual task run_phase(uvm_phase phase);
     
   endtask : run_phase
endclass : ahb_scoreboard
//------------------------------------------------------------------------------
