//*****************************************************//
//    COMPONENT : AHB_MASTER_DRIVER                    //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_m_driver.sv                      //
//*****************************************************//
// Description : 
// This ahb_master_driver component drives the  transaction in pipelined nature i.e the current
// data_phase will be executing with the next txn address phase
//*****************************************************//
// Properties : 
// Contains the class properties 
//--------------------------------------------------------------------------------------------
class ahb_m_driver extends uvm_driver#(ahb_m_seq_item);
   // interface handle   
   local virtual ahb_interface vif;
   // transaction queue
   local ahb_m_seq_item pipeline [$];
   // factory registration
   `uvm_component_utils(ahb_m_driver)

   // constructor method
   function new(string name = "ahb_m_driver",uvm_component parent);
      super.new(name,parent);
   endfunction : new 
   
   // build_phase
   virtual function void build_phase(uvm_phase phase);
     super.build_phase(phase);
     // getting the interface handle from the config_db
     if(!uvm_config_db #(virtual ahb_interface) :: get(this, "", "vif", vif))
       `uvm_fatal(get_full_name(), "Unable to access interface handle from config_db")
    
   endfunction : build_phase
  
   // run_phase
   virtual task do_transfers();
     // local txn handle
     ahb_m_seq_item req;
     // event to synchronize piplined nature
     event do_data_phase;
     // locat txn for data_phase
     ahb_m_seq_item current_tr;
     // looping indexes
     int i,j;
     // driving logic
     forever begin
       // wrap address
       bit[`ADDR_WIDTH - 1 : 0] wrap_boundary;
       // wrap address limit
       bit[`ADDR_WIDTH - 1 : 0] address_n;
       //@(posedge vif.hclk iff(vif.hresetn));
       // getting the transaction from the sequencer
       seq_item_port.get_next_item(req);
       // interface recording
       accept_tr(req, $time);
       // starting the interface recoding
       void'(begin_tr(req, "pipelined_driver"));
//----------------------------------------------------------------------------------------------------
       // burst address gen logic
       case(req.hburst)
         //--------------------------------------------------------------------------------
         // single hburst
         SINGLE : begin
           req.baddr_q.push_back(req.haddr);
         end
         //---------------------------------------------------------------------------------                 
         // incremental undefined length hburst
         INCR : begin
           int i;
           for(i = 0; i < req.hwdata.size();i = i + 1)begin
             if(i == 0)begin
               req.baddr_q.push_back(req.haddr);
             end
             else begin
               req.baddr_q.push_back(req.baddr_q[i - 1] + 2**req.hsize);
             end
           end
           
         end
         //---------------------------------------------------------------------------------
         // wrap4 hburst
         WRAP4 : begin
           int i;
           wrap_boundary = (int'(req.haddr/((2**req.hsize)*(4)))*((2**req.hsize)*(4)));
           address_n = wrap_boundary + ((2**req.hsize) *(4));
                            
           for(i = 0; i < 4;i = i + 1)begin
             if(i == 0)begin
               req.baddr_q.push_back(req.haddr);
             end
             else if((req.baddr_q[i - 1] + (2**req.hsize)) >= address_n) begin
               req.baddr_q.push_back(wrap_boundary);
             end
             else begin
               req.baddr_q.push_back(req.baddr_q[i - 1] + 2**req.hsize);
             end
           end
         end
         //----------------------------------------------------------------------------------
         // Incremental 4 beat burst
         INCR4 : begin
           int i;
           for(i = 0; i < 4;i = i + 1)begin
             if(i == 0)begin
               req.baddr_q.push_back(req.haddr);
             end
             else begin
               req.baddr_q.push_back(req.baddr_q[i - 1] + 2**req.hsize);
             end
           end
         end
         //-----------------------------------------------------------------------------
         // wrap 8 beat burst
         WRAP8 : begin
           int i;
           wrap_boundary = (int'(req.haddr/((2**req.hsize)*(8)))*((2**req.hsize)*(8)));
           address_n = wrap_boundary + ((2**req.hsize) *(8));
                            
           for(i = 0; i < 8;i = i + 1)begin
             if(i == 0)begin
               req.baddr_q.push_back(req.haddr);
             end
             else if((req.baddr_q[i - 1] + (2**req.hsize)) >= address_n) begin
               req.baddr_q.push_back(wrap_boundary);
             end
             else begin
               req.baddr_q.push_back(req.baddr_q[i - 1] + 2**req.hsize);
             end
           end
         end
         //-------------------------------------------------------------------------------                
         // incremental 8 beat burst
         INCR8 : begin
           int i;
           for(i = 0; i < 8;i = i + 1)begin
             if(i == 0)begin
               req.baddr_q.push_back(req.haddr);
             end
             else begin
               req.baddr_q.push_back(req.baddr_q[i - 1] + 2**req.hsize);
             end
           end
         end
         //------------------------------------------------------------------------------                
         // wrap 16 beat burst
         WRAP16 : begin
           int i;
           wrap_boundary = (int'(req.haddr/((2**req.hsize)*(16)))*((2**req.hsize)*(16)));
           address_n = wrap_boundary + ((2**req.hsize) *(16));
                            
           for(i = 0; i < 16;i = i + 1)begin
             if(i == 0)begin
               req.baddr_q.push_back(req.haddr);
             end
             else if((req.baddr_q[i - 1] + (2**req.hsize)) >= address_n) begin
               req.baddr_q.push_back(wrap_boundary);
             end
             else begin
               req.baddr_q.push_back(req.baddr_q[i - 1] + 2**req.hsize);
             end
           end
         end
         //-----------------------------------------------------------------------------------                
         // incremental 16 beat burst
         INCR16 : begin
           int i;
           for(i = 0; i < 16;i = i + 1)begin
             if(i == 0)begin
               req.baddr_q.push_back(req.haddr);
             end
             else begin
               req.baddr_q.push_back(req.baddr_q[i - 1] + 2**req.hsize);
             end
           end
         end
       endcase
       `uvm_info(get_type_name(),$sformatf("\t\naddress_n : [%0h]",address_n),UVM_MEDIUM)
       `uvm_info(get_type_name(),$sformatf("\t\nwrap_boundary : [%0h]",wrap_boundary),UVM_MEDIUM)
//----------------------------------------------------------------------------------------------
       // inserting busy address for burst address transaction queue 
       foreach(req.htrans[i])begin
         if((req.htrans[i] == BUSY) && (i < req.htrans.size()))begin
           req.baddr_q.insert(i + 1,req.baddr_q[i]);
         end
         else begin
           continue;
         end
       end
       //req.print();
//----------------------------------------------------------------------------------------------      
       // transaction driving in pipelined nature
       for(i = 0;i < req.baddr_q.size();i = i + 1)begin
         // pipelining
         fork
           // address_phase
           begin
              begin_transfer(req,i,do_data_phase);
              current_tr = req;
              j = i;
              pipeline.push_back(req);
              req.trigger("ADDRESS_PHASE_DONE"); // Signal address at this end of address phase
           end
           // data_phase
           begin
             @(posedge vif.hclk);
             wait(do_data_phase.triggered);// wait for the event triggered after data_phase execution
             data_phase(current_tr,j);     // this task will call the data_phase
           end
         join_any
       end
       @(posedge vif.hclk)        //this delay is to change the hwrite after the last address phase
       vif.hwrite <= 1'b0;
       vif.htrans <= 0;
       //wait fork;
       end_transfer(current_tr);
     end
   endtask : do_transfers
//----------------------------------------------------------------------------  
  //executes the address phase and triggers the data_phase event after 
  task begin_transfer(ahb_m_seq_item req,int i,event do_data_phase);
    address_phase(req,i);
    ->do_data_phase;
  endtask: begin_transfer
//-------------------------------------------------------------------------
  // Function to complete the sequence item - driver handshake back to the sequence 
  virtual function void end_transfer(ahb_m_seq_item req);
     ahb_m_seq_item rsp;//= pipeline.pop_front();
     $cast(rsp,req.clone());
     rsp.set_id_info(req);
     rsp.trigger("DATA_PHASE_DONE"); // Signal DATA_DONE at this end of data phase
     end_tr(rsp);
     seq_item_port.item_done(req);
     seq_item_port.put_response(rsp); // End of req item
     //req.print();
     //rsp.print();
   endfunction: end_transfer
//--------------------------------------------------------------------
  // reset task
  task wait_for_reset();
    wait(!vif.hresetn);
    vif.haddr  <= 0;
    vif.hwrite <= 0;
    vif.htrans <= 0;
    vif.hsize  <= 0;
    vif.hburst <= 0;
    vif.hwdata <= 0;
    @(posedge vif.hresetn);
  endtask
//---------------------------------------------------------------------
  // address_phase task
  task address_phase(ahb_m_seq_item req,int i);
    @(posedge vif.hclk);
    vif.haddr  <= req.baddr_q[i];
    vif.hwrite <= req.hwrite;
    vif.htrans <= req.htrans[i];
    vif.hsize  <= req.hsize;
    vif.hburst <= req.hburst;

    //wait(vif.hready == 1);
    
  endtask: address_phase
//----------------------------------------------------------------------
  // data_phase
  task data_phase(ahb_m_seq_item req, int j);
    @(posedge vif.hclk);
    req.hresp = hresp_e'(vif.hresp);
    if(req.hwrite == AHB_READ) begin
      req.hrdata[j] = vif.hrdata;
    end
    if(req.hwrite == AHB_WRITE) begin
      vif.hwdata <= req.hwdata[j];
    end
    // if target slave pulls the hready low
    while(vif.hready != 1) begin
      @(posedge vif.hclk);
    end
  endtask: data_phase
//----------------------------------------------------------------------
// run_phase
  virtual task run_phase(uvm_phase phase);  
     wait_for_reset();
     do_transfers();
  endtask : run_phase
endclass : ahb_m_driver
