//*****************************************************//
//    COMPONENT : AHB_BASE_TEST                        //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_base_test.sv                     //
//*****************************************************//
//----------------------------------------------------------------
class ahb_base_test extends uvm_test;
   // environment instance
   ahb_env env;   

   // factory registration
   `uvm_component_utils(ahb_base_test)
   
   // constructor method 
   function new(string name = "ahb_base_test",uvm_component parent);
      super.new(name,parent);
   endfunction : new
   
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = ahb_env :: type_id :: create("env",this);
   endfunction :build_phase
   
   // run_phase
   virtual task run_phase(uvm_phase phase);
   endtask : run_phase
endclass : ahb_base_test
