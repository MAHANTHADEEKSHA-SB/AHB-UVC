// -----------------------------------------------------------------------------
// ahb_adapter_pkg — width-specialized HVL adapters of the AHB UVC
//
// The only package that names the HDL BFM interface types (through virtual
// interface handles). Integration code specializes these classes per bus
// instance and hands them to ahb_agent_cfg as base-class handles.
//
// Compile after the HDL interfaces (filelists/ahb_hdl.f), uvm_pkg,
// ahb_bfm_pkg and ahb_api_pkg. ahb_uvc_pkg does not import this package.
// Include directory: hvl/adapter.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

package ahb_adapter_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ahb_bfm_pkg::*;
  import ahb_api_pkg::*;

  `include "ahb_drive_proxy.sv"
  `include "ahb_monitor_proxy.sv"

endpackage : ahb_adapter_pkg
