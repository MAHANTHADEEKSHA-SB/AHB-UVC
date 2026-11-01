// -----------------------------------------------------------------------------
// ahb_if — AHB Manager-interface signals (AHB-Lite + AHB5 pin superset)
//
// Declares the Manager-side signals of ARM IHI 0033C (Global and Manager
// signal tables, plus the HRDATA/HREADY/HRESP/HEXOKAY/user inputs a Manager
// receives from the interconnect multiplexor), so one interface definition
// serves AHB-Lite and AHB5 instances. Which signals are live is per-instance
// BFM configuration (AHB_PROTOCOL_CONTRACT section 1); absent outputs are
// driven to 0 and absent inputs are ignored.
//
// Subordinate-side decode signals (HSELx, HREADYOUT) belong to the
// interconnect, not to a Manager UVC; the example top provides them.
// Interface parity check signals (IHI 0033C) are milestone M3 and are not
// declared until their pin list is verified against the specification
// (AHB_PROTOCOL_CONTRACT section 2.2).
//
// This interface owns pins and modports only. Protocol timing lives in
// ahb_driver_bfm_if and ahb_monitor_bfm_if (ADR-002 decision 3). Signals are
// resolved nets so a disabled driver BFM can release the bus to 'z.
// Compile after ahb_bfm_pkg.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

interface ahb_if #(
  parameter int ADDR_WIDTH      = 32,  // IHI 0033C: 10..64 recommended; AHB-Lite 32
  parameter int DATA_WIDTH      = 32,  // IHI 0033C: 8..1024, 32..256 recommended
  parameter int MASTER_WIDTH    = 4,   // HMASTER physical width [ASSUMPTION]
  parameter int USER_REQ_WIDTH  = 1,   // physical width; presence is cfg
  parameter int USER_DATA_WIDTH = 1,
  parameter int USER_RESP_WIDTH = 1
) (
  input wire logic HCLK,
  input wire logic HRESETn
);

  // Manager -> interconnect (address phase and write data)
  wire logic [ADDR_WIDTH-1:0]      HADDR;
  wire logic [2:0]                 HBURST;
  wire logic                       HMASTLOCK;
  wire logic [6:0]                 HPROT;      // [3:0] always, [6:4] Extended_Memory_Types
  wire logic [2:0]                 HSIZE;
  wire logic                       HNONSEC;    // Secure_Transfers
  wire logic                       HEXCL;      // Exclusive_Transfers (M2)
  wire logic [MASTER_WIDTH-1:0]    HMASTER;    // Exclusive_Transfers (M2)
  wire logic [1:0]                 HTRANS;
  wire logic [DATA_WIDTH-1:0]      HWDATA;
  wire logic [DATA_WIDTH/8-1:0]    HWSTRB;     // Write_Strobes (M2)
  wire logic                       HWRITE;
  wire logic [USER_REQ_WIDTH-1:0]  HAUSER;     // user signals (M2)
  wire logic [USER_DATA_WIDTH-1:0] HWUSER;

  // Interconnect -> Manager (data phase response)
  wire logic [DATA_WIDTH-1:0]      HRDATA;
  wire logic                       HREADY;
  wire logic                       HRESP;      // 0 OKAY, 1 ERROR (AHB-Lite/AHB5)
  wire logic                       HEXOKAY;    // Exclusive_Transfers (M2)
  wire logic [USER_DATA_WIDTH-1:0] HRUSER;     // user signals (M2)
  wire logic [USER_RESP_WIDTH-1:0] HBUSER;

  // Modports give a DUT or a hand-written testbench a direction-checked view of the
  // bus. The UVC's own BFMs do not use them: they connect through ordinary signal
  // ports wired in the HDL top (ADR-002 decision 7).
  modport manager (
    input  HCLK, HRESETn,
    output HADDR, HBURST, HMASTLOCK, HPROT, HSIZE, HNONSEC, HEXCL, HMASTER, HTRANS,
           HWDATA, HWSTRB, HWRITE, HAUSER, HWUSER,
    input  HRDATA, HREADY, HRESP, HEXOKAY, HRUSER, HBUSER
  );

  // The interconnect (decoder + multiplexor + Subordinates) as seen by a Manager
  modport interconnect (
    input  HCLK, HRESETn,
    input  HADDR, HBURST, HMASTLOCK, HPROT, HSIZE, HNONSEC, HEXCL, HMASTER, HTRANS,
           HWDATA, HWSTRB, HWRITE, HAUSER, HWUSER,
    output HRDATA, HREADY, HRESP, HEXOKAY, HRUSER, HBUSER
  );

  modport monitor (
    input  HCLK, HRESETn,
           HADDR, HBURST, HMASTLOCK, HPROT, HSIZE, HNONSEC, HEXCL, HMASTER, HTRANS,
           HWDATA, HWSTRB, HWRITE, HAUSER, HWUSER,
           HRDATA, HREADY, HRESP, HEXOKAY, HRUSER, HBUSER
  );

  // Elaboration-time legality checks (AHB_PROTOCOL_CONTRACT CFG-03/CFG-04)
  if (ADDR_WIDTH < 1 || ADDR_WIDTH > 64) begin : g_bad_addr_width
    $error("ahb_if: ADDR_WIDTH=%0d outside 1..64 (IHI 0033C recommends 10..64)", ADDR_WIDTH);
  end
  if (!(DATA_WIDTH inside {8, 16, 32, 64, 128, 256, 512, 1024})) begin : g_bad_data_width
    $error("ahb_if: DATA_WIDTH=%0d not in IHI 0033C {8,16,...,1024}", DATA_WIDTH);
  end
  if (MASTER_WIDTH < 1 || USER_REQ_WIDTH < 1 || USER_DATA_WIDTH < 1 || USER_RESP_WIDTH < 1)
  begin : g_bad_phys_width
    $error("ahb_if: physical HMASTER/user widths must be >= 1; use cfg 0 for absent signals");
  end

endinterface : ahb_if
