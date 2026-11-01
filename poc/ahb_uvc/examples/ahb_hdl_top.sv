// -----------------------------------------------------------------------------
// ahb_hdl_top — HDL integration example: two instances of the same AHB UVC
//
//   Instance A: AW=32, DW=32  (own clock/reset)                 ADR-001 decision 3
//   Instance B: AW=32, DW=64  (own clock/reset)                 ADR-001 decision 3
//   Instance P: a passive observer on bus A — a monitor BFM plus a driver BFM
//               that is never enabled, so it must stay released to 'z
//               (ADR-002 decision 6, RISK-004)
//
// Per instance, both BFM interfaces connect to the SAME ahb_if instance
// through ordinary signal ports (ADR-002 decision 7). A and B have their own
// clock and reset so any cross-instance wiring shows up as wrong timing. The
// example Subordinate does not drive the milestone M2 inputs (HEXOKAY,
// HRUSER, HBUSER); they float and are not used in M1.
// Elaborate with ahb_hvl_top (UVM flow) or under tests/ahb_hdl_smoke.sv.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module ahb_hdl_top;

  // ---------------------------------------------------------------------------
  // Clocks and resets
  // ---------------------------------------------------------------------------
  logic hclk_a    = 1'b0;
  logic hresetn_a = 1'b0;
  logic hclk_b    = 1'b0;
  logic hresetn_b = 1'b0;
  always #5 hclk_a = ~hclk_a;  // 10 ns period
  always #7 hclk_b = ~hclk_b;  // 14 ns period

  // Initial reset: 5 cycles, released on a falling edge to avoid racing the
  // rising-edge samplers (AHB-R19: deasserted synchronously to HCLK).
  initial begin
    repeat (5) @(negedge hclk_a);
    hresetn_a = 1'b1;
  end
  // Same for instance B, on its own clock.
  initial begin
    repeat (5) @(negedge hclk_b);
    hresetn_b = 1'b1;
  end

  // Mid-simulation reset for tests (RST-1..RST-4): assert now (asynchronously),
  // release on a falling edge after `cycles` rising edges.
  task automatic pulse_reset_a(input int unsigned cycles);
    hresetn_a = 1'b0;
    repeat (cycles) @(posedge hclk_a);
    @(negedge hclk_a) hresetn_a = 1'b1;
  endtask

  // Same for instance B.
  task automatic pulse_reset_b(input int unsigned cycles);
    hresetn_b = 1'b0;
    repeat (cycles) @(posedge hclk_b);
    @(negedge hclk_b) hresetn_b = 1'b1;
  endtask

  // ---------------------------------------------------------------------------
  // Instance A — AW=32, DW=32
  // ---------------------------------------------------------------------------
  ahb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) bus_a (
    .HCLK    (hclk_a),
    .HRESETn (hresetn_a)
  );

  ahb_driver_bfm_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) drv_a (
    .HCLK      (bus_a.HCLK),
    .HRESETn   (bus_a.HRESETn),
    .HADDR     (bus_a.HADDR),
    .HBURST    (bus_a.HBURST),
    .HMASTLOCK (bus_a.HMASTLOCK),
    .HPROT     (bus_a.HPROT),
    .HSIZE     (bus_a.HSIZE),
    .HNONSEC   (bus_a.HNONSEC),
    .HEXCL     (bus_a.HEXCL),
    .HMASTER   (bus_a.HMASTER),
    .HTRANS    (bus_a.HTRANS),
    .HWDATA    (bus_a.HWDATA),
    .HWSTRB    (bus_a.HWSTRB),
    .HWRITE    (bus_a.HWRITE),
    .HAUSER    (bus_a.HAUSER),
    .HWUSER    (bus_a.HWUSER),
    .HRDATA    (bus_a.HRDATA),
    .HREADY    (bus_a.HREADY),
    .HRESP     (bus_a.HRESP),
    .HEXOKAY   (bus_a.HEXOKAY),
    .HRUSER    (bus_a.HRUSER),
    .HBUSER    (bus_a.HBUSER)
  );

  ahb_monitor_bfm_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) mon_a (
    .HCLK      (bus_a.HCLK),
    .HRESETn   (bus_a.HRESETn),
    .HADDR     (bus_a.HADDR),
    .HBURST    (bus_a.HBURST),
    .HMASTLOCK (bus_a.HMASTLOCK),
    .HPROT     (bus_a.HPROT),
    .HSIZE     (bus_a.HSIZE),
    .HNONSEC   (bus_a.HNONSEC),
    .HEXCL     (bus_a.HEXCL),
    .HMASTER   (bus_a.HMASTER),
    .HTRANS    (bus_a.HTRANS),
    .HWDATA    (bus_a.HWDATA),
    .HWSTRB    (bus_a.HWSTRB),
    .HWRITE    (bus_a.HWRITE),
    .HAUSER    (bus_a.HAUSER),
    .HWUSER    (bus_a.HWUSER),
    .HRDATA    (bus_a.HRDATA),
    .HREADY    (bus_a.HREADY),
    .HRESP     (bus_a.HRESP),
    .HEXOKAY   (bus_a.HEXOKAY),
    .HRUSER    (bus_a.HRUSER),
    .HBUSER    (bus_a.HBUSER)
  );

  // Single Subordinate: the decoder selects it for every address (HSEL HIGH) and the
  // multiplexor passes its HREADYOUT/HRESP/HRDATA straight through as HREADY etc.
  ahb_example_slave #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) slv_a (
    .HCLK      (bus_a.HCLK),
    .HRESETn   (bus_a.HRESETn),
    .HSEL      (1'b1),
    .HADDR     (bus_a.HADDR),
    .HTRANS    (bus_a.HTRANS),
    .HWRITE    (bus_a.HWRITE),
    .HSIZE     (bus_a.HSIZE),
    .HBURST    (bus_a.HBURST),
    .HPROT     (bus_a.HPROT),
    .HWDATA    (bus_a.HWDATA),
    .HREADY    (bus_a.HREADY),
    .HREADYOUT (bus_a.HREADY),
    .HRESP     (bus_a.HRESP),
    .HRDATA    (bus_a.HRDATA)
  );

  // ---------------------------------------------------------------------------
  // Instance P — passive observer of bus A (same widths, same nets)
  // ---------------------------------------------------------------------------
  // Never enabled: every output must stay 'z, or bus A shows X/contention.
  ahb_driver_bfm_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) drv_p (
    .HCLK      (bus_a.HCLK),
    .HRESETn   (bus_a.HRESETn),
    .HADDR     (bus_a.HADDR),
    .HBURST    (bus_a.HBURST),
    .HMASTLOCK (bus_a.HMASTLOCK),
    .HPROT     (bus_a.HPROT),
    .HSIZE     (bus_a.HSIZE),
    .HNONSEC   (bus_a.HNONSEC),
    .HEXCL     (bus_a.HEXCL),
    .HMASTER   (bus_a.HMASTER),
    .HTRANS    (bus_a.HTRANS),
    .HWDATA    (bus_a.HWDATA),
    .HWSTRB    (bus_a.HWSTRB),
    .HWRITE    (bus_a.HWRITE),
    .HAUSER    (bus_a.HAUSER),
    .HWUSER    (bus_a.HWUSER),
    .HRDATA    (bus_a.HRDATA),
    .HREADY    (bus_a.HREADY),
    .HRESP     (bus_a.HRESP),
    .HEXOKAY   (bus_a.HEXOKAY),
    .HRUSER    (bus_a.HRUSER),
    .HBUSER    (bus_a.HBUSER)
  );

  ahb_monitor_bfm_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) mon_p (
    .HCLK      (bus_a.HCLK),
    .HRESETn   (bus_a.HRESETn),
    .HADDR     (bus_a.HADDR),
    .HBURST    (bus_a.HBURST),
    .HMASTLOCK (bus_a.HMASTLOCK),
    .HPROT     (bus_a.HPROT),
    .HSIZE     (bus_a.HSIZE),
    .HNONSEC   (bus_a.HNONSEC),
    .HEXCL     (bus_a.HEXCL),
    .HMASTER   (bus_a.HMASTER),
    .HTRANS    (bus_a.HTRANS),
    .HWDATA    (bus_a.HWDATA),
    .HWSTRB    (bus_a.HWSTRB),
    .HWRITE    (bus_a.HWRITE),
    .HAUSER    (bus_a.HAUSER),
    .HWUSER    (bus_a.HWUSER),
    .HRDATA    (bus_a.HRDATA),
    .HREADY    (bus_a.HREADY),
    .HRESP     (bus_a.HRESP),
    .HEXOKAY   (bus_a.HEXOKAY),
    .HRUSER    (bus_a.HRUSER),
    .HBUSER    (bus_a.HBUSER)
  );

  // ---------------------------------------------------------------------------
  // Instance B — AW=32, DW=64
  // ---------------------------------------------------------------------------
  ahb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(64)) bus_b (
    .HCLK    (hclk_b),
    .HRESETn (hresetn_b)
  );

  ahb_driver_bfm_if #(.ADDR_WIDTH(32), .DATA_WIDTH(64)) drv_b (
    .HCLK      (bus_b.HCLK),
    .HRESETn   (bus_b.HRESETn),
    .HADDR     (bus_b.HADDR),
    .HBURST    (bus_b.HBURST),
    .HMASTLOCK (bus_b.HMASTLOCK),
    .HPROT     (bus_b.HPROT),
    .HSIZE     (bus_b.HSIZE),
    .HNONSEC   (bus_b.HNONSEC),
    .HEXCL     (bus_b.HEXCL),
    .HMASTER   (bus_b.HMASTER),
    .HTRANS    (bus_b.HTRANS),
    .HWDATA    (bus_b.HWDATA),
    .HWSTRB    (bus_b.HWSTRB),
    .HWRITE    (bus_b.HWRITE),
    .HAUSER    (bus_b.HAUSER),
    .HWUSER    (bus_b.HWUSER),
    .HRDATA    (bus_b.HRDATA),
    .HREADY    (bus_b.HREADY),
    .HRESP     (bus_b.HRESP),
    .HEXOKAY   (bus_b.HEXOKAY),
    .HRUSER    (bus_b.HRUSER),
    .HBUSER    (bus_b.HBUSER)
  );

  ahb_monitor_bfm_if #(.ADDR_WIDTH(32), .DATA_WIDTH(64)) mon_b (
    .HCLK      (bus_b.HCLK),
    .HRESETn   (bus_b.HRESETn),
    .HADDR     (bus_b.HADDR),
    .HBURST    (bus_b.HBURST),
    .HMASTLOCK (bus_b.HMASTLOCK),
    .HPROT     (bus_b.HPROT),
    .HSIZE     (bus_b.HSIZE),
    .HNONSEC   (bus_b.HNONSEC),
    .HEXCL     (bus_b.HEXCL),
    .HMASTER   (bus_b.HMASTER),
    .HTRANS    (bus_b.HTRANS),
    .HWDATA    (bus_b.HWDATA),
    .HWSTRB    (bus_b.HWSTRB),
    .HWRITE    (bus_b.HWRITE),
    .HAUSER    (bus_b.HAUSER),
    .HWUSER    (bus_b.HWUSER),
    .HRDATA    (bus_b.HRDATA),
    .HREADY    (bus_b.HREADY),
    .HRESP     (bus_b.HRESP),
    .HEXOKAY   (bus_b.HEXOKAY),
    .HRUSER    (bus_b.HRUSER),
    .HBUSER    (bus_b.HBUSER)
  );

  // Single Subordinate: the decoder selects it for every address (HSEL HIGH) and the
  // multiplexor passes its HREADYOUT/HRESP/HRDATA straight through as HREADY etc.
  ahb_example_slave #(.ADDR_WIDTH(32), .DATA_WIDTH(64)) slv_b (
    .HCLK      (bus_b.HCLK),
    .HRESETn   (bus_b.HRESETn),
    .HSEL      (1'b1),
    .HADDR     (bus_b.HADDR),
    .HTRANS    (bus_b.HTRANS),
    .HWRITE    (bus_b.HWRITE),
    .HSIZE     (bus_b.HSIZE),
    .HBURST    (bus_b.HBURST),
    .HPROT     (bus_b.HPROT),
    .HWDATA    (bus_b.HWDATA),
    .HREADY    (bus_b.HREADY),
    .HREADYOUT (bus_b.HREADY),
    .HRESP     (bus_b.HRESP),
    .HRDATA    (bus_b.HRDATA)
  );

endmodule : ahb_hdl_top
