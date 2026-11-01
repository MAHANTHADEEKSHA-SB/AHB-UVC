// -----------------------------------------------------------------------------
// ahb_defines.svh — compile-time maxima for the width-independent transaction
//
// One simulation image uses one set of maxima (AHB_PROTOCOL_CONTRACT
// section 6). The defaults cover the POC width pair DW=32 + DW=64 (ADR-001
// decision 3) with 32-bit addresses. Wider buses (IHI 0033C allows up to
// 1024 data bits and recommends up to 64 address bits) need
// +define+AHB_MAX_DATA_WIDTH=<n> / +define+AHB_MAX_ADDR_WIDTH=<n>.
// Included by ahb_api_pkg.
// -----------------------------------------------------------------------------
`ifndef AHB_DEFINES_SVH
`define AHB_DEFINES_SVH

`ifndef AHB_MAX_ADDR_WIDTH
  `define AHB_MAX_ADDR_WIDTH 32
`endif

`ifndef AHB_MAX_DATA_WIDTH
  `define AHB_MAX_DATA_WIDTH 64
`endif

`endif // AHB_DEFINES_SVH
