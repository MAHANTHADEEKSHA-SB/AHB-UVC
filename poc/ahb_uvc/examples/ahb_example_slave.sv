// -----------------------------------------------------------------------------
// ahb_example_slave — small AHB Subordinate used only by the POC examples/tests
//
// This is a test fixture, not a reference for the AHB specification
// (DIRECTORY_ARCHITECTURE "AHB POC behavior"). Behaviour chosen to make
// directed tests easy:
//   * MEM_BYTES of word-organised memory, cleared by HRESETn; a write stores
//     only the byte lanes of its HSIZE/HADDR (AHB-R20, little-endian lanes)
//   * wait states per data phase = HADDR[5:4] (0..3) of that beat, so a test
//     selects them by address
//   * two-cycle ERROR response for addresses >= MEM_BYTES (AHB-R14); with
//     MEM_BYTES = 512 an incrementing burst can run from OKAY into ERROR
//     inside one 1KB page
//   * IDLE and BUSY get a zero-wait OKAY (AHB-R03/R04); HREADYOUT is HIGH
//     during reset and when no data phase is in progress
//   * HRDATA is driven only in the completing cycle of a read, 0 otherwise
// HBURST and HPROT are accepted and ignored. HSEL selects the fixture; the
// example top ties it HIGH and feeds HREADYOUT back as HREADY.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module ahb_example_slave #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int MEM_BYTES  = 512
) (
  input  logic                  HCLK,
  input  logic                  HRESETn,
  input  logic                  HSEL,
  input  logic [ADDR_WIDTH-1:0] HADDR,
  input  logic [1:0]            HTRANS,
  input  logic                  HWRITE,
  input  logic [2:0]            HSIZE,
  input  logic [2:0]            HBURST,     // accepted, not used
  input  logic [6:0]            HPROT,      // accepted, no protection model
  input  logic [DATA_WIDTH-1:0] HWDATA,
  input  logic                  HREADY,     // from the interconnect multiplexor
  output logic                  HREADYOUT,
  output logic                  HRESP,
  output logic [DATA_WIDTH-1:0] HRDATA
);

  localparam int NBYTES    = DATA_WIDTH / 8;
  localparam int LANE_BITS = $clog2(NBYTES);
  localparam int MEM_WORDS = MEM_BYTES / NBYTES;
  localparam logic [ADDR_WIDTH-1:0] MEM_LIMIT = MEM_BYTES;

  // Word-addressed memory; the transfer's byte lanes select what a write changes
  logic [DATA_WIDTH-1:0] mem [MEM_WORDS];

  // Data phase of the transfer accepted at the previous HREADY HIGH edge
  logic                  dp_valid;
  logic                  dp_write;
  logic [ADDR_WIDTH-1:0] dp_addr;
  logic [2:0]            dp_size;
  logic [1:0]            wait_cnt;

  wire                  in_range = (dp_addr < MEM_LIMIT);
  wire [1:0]            wait_req = in_range ? dp_addr[5:4] : 2'd1;  // ERROR: one LOW cycle
  wire [ADDR_WIDTH-1:0] word     = dp_addr >> LANE_BITS;

  // Response of the data phase in progress: LOW until wait_req cycles have passed;
  // HRESP HIGH in both ERROR cycles; read data only in the completing cycle.
  assign HREADYOUT = !dp_valid || (wait_cnt == wait_req);
  assign HRESP     = dp_valid && !in_range;
  assign HRDATA    = (dp_valid && !dp_write && in_range && HREADYOUT) ? mem[word] : '0;

  // 1 when byte lane `lane` carries data for the transfer in its data phase:
  // lanes [addr mod NBYTES, + 2**HSIZE) (AHB-R20).
  function automatic bit lane_active(int unsigned lane);
    int unsigned first = int'(dp_addr % NBYTES);
    int unsigned count = 32'd1 << dp_size;
    return (lane >= first) && (lane < first + count);
  endfunction

  // Address/data pipeline. At an HREADY HIGH edge the data phase in progress
  // completes (a write stores its lanes) and the address phase on the bus is
  // accepted; NONSEQ/SEQ to this fixture starts a data phase. Reset clears the
  // memory (a fixture choice, not an IHI 0033C rule).
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      dp_valid <= 1'b0;
      dp_write <= 1'b0;
      dp_addr  <= '0;
      dp_size  <= 3'b000;
      wait_cnt <= 2'd0;
      for (int w = 0; w < MEM_WORDS; w++) mem[w] <= '0;
    end else if (HREADY) begin
      if (dp_valid && dp_write && in_range)
        for (int unsigned i = 0; i < NBYTES; i++)
          if (lane_active(i)) mem[word][8*i +: 8] <= HWDATA[8*i +: 8];
      dp_valid <= HSEL && (HTRANS == 2'b10 || HTRANS == 2'b11);  // NONSEQ or SEQ
      dp_write <= HWRITE;
      dp_addr  <= HADDR;
      dp_size  <= HSIZE;
      wait_cnt <= 2'd0;
    end else if (dp_valid) begin
      wait_cnt <= wait_cnt + 2'd1;
    end
  end

  if (ADDR_WIDTH < 10) begin : g_bad_addr_width
    $error("ahb_example_slave: ADDR_WIDTH must be >= 10 (1KB page tests)");
  end
  if (MEM_BYTES % NBYTES != 0 || MEM_BYTES >= 1024) begin : g_bad_mem_bytes
    $error("ahb_example_slave: MEM_BYTES must be a multiple of DATA_WIDTH/8 and < 1024");
  end

endmodule : ahb_example_slave
