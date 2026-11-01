// -----------------------------------------------------------------------------
// ahb_api_pkg — width-independent HVL API of the AHB UVC
//
// Contains the transaction, the reset event and the two abstract capability
// classes. Nothing here depends on a physical interface type (ADR-001
// decision 1), so the UVM core (ahb_uvc_pkg) can be compiled against it alone.
//
// Compile after uvm_pkg and ahb_bfm_pkg. Include directories: hvl/types,
// hvl/api (see filelists/ahb_hvl.f).
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

// The maxima macros must be defined before the package's localparams use them.
`include "ahb_defines.svh"

package ahb_api_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ahb_bfm_pkg::*;

  // Transaction maxima for this simulation image (ahb_defines.svh)
  localparam int AHB_MAX_AW = `AHB_MAX_ADDR_WIDTH;
  localparam int AHB_MAX_DW = `AHB_MAX_DATA_WIDTH;
  localparam int AHB_MAX_SW = `AHB_MAX_DATA_WIDTH / 8;

  `include "ahb_transaction.sv"
  `include "ahb_reset_event.sv"
  `include "ahb_drive_proxy_base.sv"
  `include "ahb_monitor_proxy_base.sv"

endpackage : ahb_api_pkg
