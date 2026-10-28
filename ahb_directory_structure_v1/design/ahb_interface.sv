//*****************************************************//
//    COMPONENT : AHB_INTERFACE                        //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_interface.sv                     //
//*****************************************************//
//--------------------------------------------------------------------
interface ahb_interface(input logic hclk);

//--------------------------------------------------------------------
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
//----------------------------------------------------------------------
 
//---------------------------------------------------------------------------
  clocking m_drv_cb@(posedge hclk);
     default input #1 output #0;

     output htrans;
     output hburst;
     output hsize;
     output hwrite;
     output haddr;
     output hwdata;
     input  hready;
     input  hresp;
     input  hrdata;

  endclocking : m_drv_cb
//----------------------------------------------------------------------
  clocking m_mon_cb@(posedge hclk);
     default input #1 output #0;

     input hresetn;
     input htrans;
     input hburst;
     input hsize;
     input hwrite;
     input haddr;
     input hwdata;
     input hready;
     input hresp;
     input hrdata;

  endclocking : m_mon_cb
//-----------------------------------------------------------------------
  clocking slv_drv_cb@(posedge hclk);
     default input #1 output #0;

     input htrans;
     input hburst;
     input hsize;
     input hwrite;
     input haddr;
     input hwdata;
     output hready;
     output hresp;
     output hrdata;

  endclocking : slv_drv_cb
//-----------------------------------------------------------------------
  clocking slv_mon_cb@(posedge hclk);
     default input #1 output #0;

     input htrans;
     input hburst;
     input hsize;
     input hwrite;
     input haddr;
     input hwdata;
     input hready;
     input hresp;
     input hrdata;

  endclocking : slv_mon_cb
//-----------------------------------------------------------------------
  modport m_drv_mp(clocking m_drv_cb, input hresetn);
  modport m_mon_mp(clocking m_mon_cb, input hresetn);
//-----------------------------------------------------------------------
  modport slv_drv_mp(clocking slv_drv_cb, input hresetn);
  modport slv_mon_mp(clocking slv_mon_cb, input hresetn);
//-----------------------------------------------------------------------
 
//--------------------------------------------------------------------------
endinterface : ahb_interface
