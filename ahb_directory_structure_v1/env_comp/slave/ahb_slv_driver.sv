//*****************************************************//
//    COMPONENT : AHB_SLAVE_DRIVER                     //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_slv_driver.sv                    //
//*****************************************************//
//---------------------------------------------------------------------------
class ahb_slv_driver extends uvm_driver #(ahb_slv_seq_item);
  
   local virtual ahb_interface vif;
  
   // factory registration
   `uvm_component_utils(ahb_slv_driver)
   
   // constructor
   function new(string name = "ahb_slv_driver",uvm_component parent);
      super.new(name,parent);
   endfunction : new
   
   // build_phase
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      
     if(!uvm_config_db#(virtual ahb_interface) :: get(this,"*","vif",vif))begin
       `uvm_fatal(get_type_name(),"Unable to get the interface from config_db")
     end
   endfunction : build_phase
   
   // run_phase
   virtual task run_phase(uvm_phase phase);
     reset_signals();
     fork 
       begin
         @(negedge vif.hresetn)
         `uvm_info(get_type_name(),"RESET DETECTED",UVM_MEDIUM)
       end
       begin
         forever begin
           @(posedge vif.hclk iff(vif.hresetn));
           seq_item_port.get_next_item(req);
              drive_transfer(req);
           seq_item_port.item_done(req);
         end
       end
     join_any
     if(req.is_active) this.end_tr(req);
         
   endtask : run_phase
  
  virtual task reset_signals();
    wait(!vif.hresetn);
    `uvm_info(get_type_name(),"RESET_ASSERTED",UVM_MEDIUM)
    @(posedge vif.hresetn);
  endtask : reset_signals
  
  virtual task drive_transfer(ahb_slv_seq_item req);
    
  endtask : drive_transfer
endclass : ahb_slv_driver
