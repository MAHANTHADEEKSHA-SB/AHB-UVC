//*****************************************************//
//    COMPONENT : AHB_TOP_TB                           //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_top.sv                           //
//*****************************************************//
// Top testbench module

// To include uvm macros source library file
`include "uvm_macros.svh"

// To import uvm package
import uvm_pkg :: *;

`include "ahb_defines.sv"
//
//`include "ahb_interface.sv"
//
`include "ahb_m_seq_item.sv"
//
`include "ahb_slv_seq_item.sv"
//
`include "ahb_m_base_seq.sv"
`include "ahb_m_write_seq.sv"
//
`include "ahb_slv_base_seq.sv"
//
`include "ahb_m_sequencer.sv"
`include "ahb_slv_sequencer.sv"
//
`include "ahb_m_driver.sv"
`include "ahb_slv_driver.sv"
//
`include "ahb_slv_monitor.sv"
`include "ahb_m_monitor.sv"
//
`include "ahb_m_agent.sv"
`include "ahb_slv_agent.sv"
//
`include "ahb_scoreboard.sv"
//
`include "ahb_env.sv"
//
`include "ahb_base_test.sv"
`include "ahb_write_test.sv"

// Top dut
module tb_top;
   bit hclk;
   string test_name;
  
  logic                       hresetn;
  logic                       hready;
  logic [1 : 0]               htrans;
  logic [2 : 0]               hburst;
  logic [2 : 0]               hsize;
  logic                       hwrite;
  logic [`ADDR_WIDTH - 1 : 0] haddr;
  logic [`DATA_WIDTH - 1 : 0] hwdata;
  logic [`DATA_WIDTH - 1 : 0] hrdata;
  logic [1 : 0]  hresp;
  
  
  
  ahb_interface pif(.hclk(hclk));
  
  assign hresetn = pif.hresetn;
  assign haddr = pif.haddr;
  assign hwdata = pif.hwdata;
  assign hrdata = pif.hrdata;
  assign hwrite = pif.hwrite;
  assign hready = pif.hready;
  assign hresp = pif.hresp;
  assign hsize = pif.hsize;
  assign hburst = pif.hburst;
  assign htrans = pif.htrans;
                       
   initial begin
     $dumpfile("dump.vcd");
     $dumpvars(0, tb_top);
      fork
         // Clock generation thread
         begin
            hclk = 1;
            forever #5 hclk = ~hclk;
         end

         // Reset signal generation thread
         // Active low reset signal
         begin
            pif.hresetn = 1;        
            #2 pif.hresetn = 1'b0;
            repeat(3) @(posedge hclk);
            pif.hresetn = 1'b1;
            repeat(10)@(posedge hclk);
            #100 $finish();
         end
      join

   end 
   
   initial begin
      // Setting the virtual interface in config db
      // This interface hanlde can be retireved from any component down the hierarchy
      uvm_config_db #(virtual ahb_interface) :: set (uvm_root :: get(), "*", "vif", pif);
     run_test ("ahb_write_test");
     

   end

  

endmodule : tb_top

//**************************************EOF******************************************************//
