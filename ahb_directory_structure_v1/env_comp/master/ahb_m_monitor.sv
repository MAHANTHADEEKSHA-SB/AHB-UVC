//*****************************************************//
//    COMPONENT : AHB_MASTER_MONITOR                   //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_m_monitor.sv                     //
//*****************************************************//
//----------------------------------------------------------------------
class ahb_m_monitor extends uvm_monitor;
    // interface handle   
   local virtual ahb_interface vif;
   // transaction queue
   local ahb_m_seq_item pipeline [$];
   // analysis port to send out the txn
   uvm_analysis_port #(ahb_m_seq_item) master_mon_ap;

   // factory registration 
   `uvm_component_utils(ahb_m_monitor)
   
   // constructor method
   function new(string name = "ahb_m_monitor",uvm_component parent);
      super.new(name,parent);
   endfunction : new
   
   // build_phase
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      master_mon_ap = new("master_mon_ap",this);
      // getting the interface handle from the config_db
     if(!uvm_config_db #(virtual ahb_interface) :: get(this, "", "vif", vif))
       `uvm_fatal(get_full_name(), "Unable to access interface handle from config_db")
   endfunction : build_phase
   
   // run_phase
   virtual task run_phase(uvm_phase phase);
      ahb_m_seq_item req;
      ahb_m_seq_item current_tr;
      event do_data_phase;
      int i,j;
      wait_for_reset();
      
      // these delays are due to pipelined nature
      //@(posedge vif.hclk);
      //@(posedge vif.hclk);
      forever begin
       // interface recording
       req = ahb_m_seq_item :: type_id :: create("req");
       accept_tr(req, $time);
       // starting the interface recoding
         fork
           begin
              address_phase(req,i);
              current_tr = req;
              j = i;
              pipeline.push_back(req);
              ->do_data_phase;
              req.trigger("ADDRESS_PHASE_DONE"); // Signal address at this end of address phase
           end
           begin
             @(posedge vif.hclk);
             wait(do_data_phase.triggered);// wait for the event triggered after data_phase execution
             data_phase(current_tr,j);     // this task will execute the data_phase
           end
         join_any
         i = i + 1;
      end
   endtask : run_phase
   //------------------------------------------------------------------------
   task address_phase(ahb_m_seq_item req,int i);
     void'(begin_tr(req, "pipelined_monitor"));
     @(posedge vif.hclk);
     req.htrans = new[1];
     req.haddr     = vif.haddr;
     req.hwrite    = hwrite_e'(vif.hwrite);
     req.htrans[0] = htrans_e'(vif.htrans);
     req.hsize     = hsize_e'(vif.hsize);
     req.hburst    = hburst_e'(vif.hburst);
     
     //wait(vif.hready == 1);
   endtask: address_phase
//----------------------------------------------------------------------
   task data_phase(ahb_m_seq_item req, int j);
     @(posedge vif.hclk);
     req.hrdata = new[1];
     req.hwdata = new[1];
     req.hresp = hresp_e'(vif.hresp);
     if(req.hwrite == AHB_READ) begin
       req.hrdata[0] = vif.hrdata;
     end
     if(req.hwrite == AHB_WRITE) begin
       req.hwdata[0] = vif.hwdata;
     end
     while(vif.hready != 1) begin
      @(posedge vif.hclk);
     end
     end_tr(req);
    //req.print();
     if((vif.hresetn == 1) && (req.htrans[0] != IDLE))begin
       master_mon_ap.write(req);
     end
  endtask: data_phase
  //--------------------------------------------------------------------
  task wait_for_reset();
    wait(!vif.hresetn);
      @(posedge vif.hresetn);
  endtask
endclass : ahb_m_monitor
