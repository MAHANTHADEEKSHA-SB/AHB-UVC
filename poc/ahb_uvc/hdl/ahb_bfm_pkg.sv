// -----------------------------------------------------------------------------
// ahb_bfm_pkg — types and pure functions shared by the HDL BFMs and HVL adapters
//
// Types and pure functions only: no classes, no UVM, no timing. Both sides of
// the HDL/HVL boundary agree here on revision, HTRANS/HBURST/HSIZE encodings,
// status, fault and monitor-error codes, and on the burst address arithmetic
// (AHB_PROTOCOL_CONTRACT section 9). SV interfaces are not declared here;
// they cannot live in a package.
// Compile first (filelists/ahb_hdl.f).
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

package ahb_bfm_pkg;

  // Most beats one item or one observation holds. INCR16/WRAP16 are the longest
  // fixed-length bursts (IHI 0033C "Burst operation"); undefined-length INCR
  // items are limited to the same count in milestone M1 (POL-04).
  localparam int unsigned AHB_MAX_BEATS = 16;

  // Widest address the pure functions below handle (AHB5 recommends <= 64 bits)
  localparam int unsigned AHB_FN_AW = 64;

  // AHB_LITE: AMBA 3 AHB-Lite (IHI 0033A). AHB5: AMBA 5 AHB (IHI 0033B/C).
  // AMBA 2 multi-manager AHB (IHI 0011A) is out of scope (AHB_PROTOCOL_CONTRACT Q1).
  typedef enum int unsigned {
    AHB_LITE = 3,
    AHB5     = 5
  } ahb_revision_e;

  // IHI 0033C interface parity protection (milestone M3)
  typedef enum int unsigned {
    AHB_CHECK_NONE                = 0,
    AHB_CHECK_ODD_PARITY_BYTE_ALL = 1
  } ahb_check_type_e;

  // HTRANS encoding (IHI 0033C "Transfer types")
  typedef enum bit [1:0] {
    AHB_TRANS_IDLE   = 2'b00,
    AHB_TRANS_BUSY   = 2'b01,
    AHB_TRANS_NONSEQ = 2'b10,
    AHB_TRANS_SEQ    = 2'b11
  } ahb_trans_e;

  // HBURST encoding (IHI 0033C "Burst operation")
  typedef enum bit [2:0] {
    AHB_BURST_SINGLE = 3'b000,
    AHB_BURST_INCR   = 3'b001,
    AHB_BURST_WRAP4  = 3'b010,
    AHB_BURST_INCR4  = 3'b011,
    AHB_BURST_WRAP8  = 3'b100,
    AHB_BURST_INCR8  = 3'b101,
    AHB_BURST_WRAP16 = 3'b110,
    AHB_BURST_INCR16 = 3'b111
  } ahb_burst_e;

  // HSIZE encoding: transfer size in bits (IHI 0033C "Transfer size")
  typedef enum bit [2:0] {
    AHB_SIZE_8    = 3'b000,
    AHB_SIZE_16   = 3'b001,
    AHB_SIZE_32   = 3'b010,
    AHB_SIZE_64   = 3'b011,
    AHB_SIZE_128  = 3'b100,
    AHB_SIZE_256  = 3'b101,
    AHB_SIZE_512  = 3'b110,
    AHB_SIZE_1024 = 3'b111
  } ahb_size_e;

  // Per-instance feature set pushed from ahb_agent_cfg to both BFMs. The flags
  // are the AHB5 interface properties; a user width of 0 means the signal is
  // absent. Milestones: M1 ext_mem_types/secure_transfers; M2 exclusive,
  // write strobes and user signals; M3 parity (AHB_PROTOCOL_CONTRACT section 2).
  typedef struct packed {
    ahb_revision_e   revision;
    bit              ext_mem_types;        // Extended_Memory_Types: HPROT[6:4]
    bit              secure_transfers;     // Secure_Transfers: HNONSEC
    bit              exclusive_transfers;  // Exclusive_Transfers: HEXCL/HMASTER/HEXOKAY
    bit              write_strobes;        // Write_Strobes: HWSTRB
    int unsigned     user_req_width;       // HAUSER
    int unsigned     user_data_width;      // HWUSER/HRUSER
    int unsigned     user_resp_width;      // HBUSER
    ahb_check_type_e check_type;
  } ahb_features_t;

  // Result of one driver BFM burst
  typedef enum int unsigned {
    AHB_ST_OK             = 0,
    AHB_ST_ERROR          = 1,  // a beat completed with HRESP ERROR (AHB-R14)
    AHB_ST_RESET_ABORTED  = 2,  // RST-3
    AHB_ST_TIMEOUT        = 3,  // POL-01
    AHB_ST_NOT_ENABLED    = 4,  // driver BFM released (passive)
    AHB_ST_BAD_REQUEST    = 5,  // illegal or lossy request, BFM busy
    AHB_ST_FAULT_INJECTED = 6   // burst deliberately cut short by a fault mode
  } ahb_bfm_status_e;

  // Deliberate protocol faults the driver BFM can inject (negative tests)
  typedef enum int unsigned {
    AHB_FAULT_NONE              = 0,
    AHB_FAULT_ADDR_UNSTABLE     = 1,  // change HADDR of a waited SEQ transfer (AHB-R11)
    AHB_FAULT_BAD_SEQ_ADDR      = 2,  // second beat at a wrong address (AHB-R05)
    AHB_FAULT_EARLY_TERMINATION = 3   // IDLE inside a fixed-length burst (AHB-R10)
  } ahb_fault_e;

  // Protocol violations (and two UVC capacity limits) counted by the monitor BFM
  typedef enum int unsigned {
    AHB_MON_ERR_HTRANS_XZ             = 0,   // AHB-R22
    AHB_MON_ERR_CONTROL_XZ            = 1,   // AHB-R22: address/control of NONSEQ/SEQ
    AHB_MON_ERR_HREADY_XZ             = 2,   // AHB-R22
    AHB_MON_ERR_HRESETN_XZ            = 3,   // RST-7
    AHB_MON_ERR_UNSTABLE_IN_WAIT      = 4,   // AHB-R11/R12: waited transfer or HWDATA changed
    AHB_MON_ERR_SEQ_OUTSIDE_BURST     = 5,   // AHB-R04/R05: SEQ/BUSY without an open burst
    AHB_MON_ERR_BURST_CONTROL_CHANGED = 6,   // AHB-R05: control differs inside a burst
    AHB_MON_ERR_BURST_ADDR            = 7,   // AHB-R05/R09: SEQ address not the next address
    AHB_MON_ERR_BURST_LENGTH          = 8,   // AHB-R09/R10: beat count differs from HBURST
    AHB_MON_ERR_BURST_1KB_CROSS       = 9,   // AHB-R08
    AHB_MON_ERR_UNALIGNED             = 10,  // AHB-R07
    AHB_MON_ERR_SIZE_EXCEEDS_BUS      = 11,  // AHB-R06
    AHB_MON_ERR_ERROR_NOT_TWO_CYCLE   = 12,  // AHB-R14
    AHB_MON_ERR_IDLE_BUSY_RESPONSE    = 13,  // AHB-R03/R04: IDLE/BUSY not zero-wait OKAY
    AHB_MON_ERR_QUEUE_OVERFLOW        = 14,  // UVC limit: observation queue full
    AHB_MON_ERR_CAPACITY              = 15   // UVC limit: INCR burst longer than AHB_MAX_BEATS
  } ahb_mon_error_e;
  localparam int unsigned AHB_MON_NUM_ERRORS = 16;

  // The helpers below take raw 3-bit HBURST/HSIZE values (sampled pins or enum
  // values), so HDL callers need no casts. X/Z input gives a meaningless result;
  // the monitor checks X/Z before using them.

  // Beats of a fixed-length burst; 1 for SINGLE, 0 for undefined-length INCR
  function automatic int unsigned ahb_burst_beats(logic [2:0] burst);
    case (burst)
      AHB_BURST_SINGLE:                  return 1;
      AHB_BURST_WRAP4,  AHB_BURST_INCR4:  return 4;
      AHB_BURST_WRAP8,  AHB_BURST_INCR8:  return 8;
      AHB_BURST_WRAP16, AHB_BURST_INCR16: return 16;
      default:                           return 0;  // AHB_BURST_INCR
    endcase
  endfunction

  function automatic bit ahb_burst_is_wrap(logic [2:0] burst);
    return burst inside {AHB_BURST_WRAP4, AHB_BURST_WRAP8, AHB_BURST_WRAP16};
  endfunction

  // Bytes moved by one beat of HSIZE = size
  function automatic int unsigned ahb_size_bytes(logic [2:0] size);
    return 32'd1 << size;
  endfunction

  // Address of the beat after `addr` in a burst (AHB-R05/R09). Incrementing
  // bursts add the transfer size; wrapping bursts wrap at the boundary of
  // beats x size bytes. Pure arithmetic on AHB_FN_AW bits; callers cast.
  function automatic logic [AHB_FN_AW-1:0] ahb_next_addr(logic [AHB_FN_AW-1:0] addr,
                                                         logic [2:0]           size,
                                                         logic [2:0]           burst);
    logic [AHB_FN_AW-1:0] bytes;
    logic [AHB_FN_AW-1:0] span;
    bytes = AHB_FN_AW'(ahb_size_bytes(size));
    if (!ahb_burst_is_wrap(burst)) return addr + bytes;
    span = bytes * AHB_FN_AW'(ahb_burst_beats(burst));
    return (addr & ~(span - 1)) | ((addr + bytes) & (span - 1));
  endfunction

  // 1 when [first, last] spans two 1KB pages (AHB-R08)
  function automatic bit ahb_crosses_1kb(logic [AHB_FN_AW-1:0] first,
                                         logic [AHB_FN_AW-1:0] last);
    return (first >> 10) != (last >> 10);
  endfunction

  // HPROT bits an instance carries: 7 with Extended_Memory_Types, else 4 (AHB-R16)
  function automatic int unsigned ahb_prot_width(ahb_features_t f);
    return f.ext_mem_types ? 7 : 4;
  endfunction

  // "" when f is legal for its revision (IHI 0033C interface properties), else the
  // first problem. Shared by both BFMs' configure() and by ahb_agent_cfg (CFG-01).
  function automatic string ahb_revision_problem(ahb_features_t f);
    if (f.revision == AHB_LITE &&
        (f.ext_mem_types || f.secure_transfers || f.exclusive_transfers ||
         f.write_strobes || f.user_req_width != 0 || f.user_data_width != 0 ||
         f.user_resp_width != 0 || f.check_type != AHB_CHECK_NONE))
      return "AHB5 interface properties are not present on AHB-Lite (IHI 0033A)";
    return "";
  endfunction

  // "" when f only uses features implemented in milestone M1, else the first gap
  function automatic string ahb_milestone_problem(ahb_features_t f);
    if (f.exclusive_transfers || f.write_strobes || f.user_req_width != 0 ||
        f.user_data_width != 0 || f.user_resp_width != 0)
      return "exclusive transfers, write strobes and user signals are milestone M2";
    if (f.check_type != AHB_CHECK_NONE)
      return "interface parity protection is milestone M3";
    return "";
  endfunction

  // Proposed default instance: AHB5, 4-bit HPROT, no optional property
  // (AHB_PROTOCOL_CONTRACT Q2; not yet confirmed by the owner).
  function automatic ahb_features_t ahb_default_features();
    ahb_features_t f;
    f.revision            = AHB5;
    f.ext_mem_types       = 1'b0;
    f.secure_transfers    = 1'b0;
    f.exclusive_transfers = 1'b0;
    f.write_strobes       = 1'b0;
    f.user_req_width      = 0;
    f.user_data_width     = 0;
    f.user_resp_width     = 0;
    f.check_type          = AHB_CHECK_NONE;
    return f;
  endfunction

endpackage : ahb_bfm_pkg
