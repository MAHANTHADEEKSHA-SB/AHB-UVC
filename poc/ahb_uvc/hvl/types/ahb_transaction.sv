// -----------------------------------------------------------------------------
// ahb_transaction — one AHB burst, independent of the bus width
//
// The same class serves every instance (ADR-001 decision 1). One item is one
// burst: SINGLE, INCR (1..AHB_MAX_BEATS beats, POL-04) or a fixed-length
// INCR/WRAP 4/8/16. Payload fields use the compile-time maxima AHB_MAX_AW/DW;
// bits at or above the bound bus width must be zero, and the drive adapter
// rejects any other value instead of truncating it (AHB_PROTOCOL_CONTRACT
// section 6). wdata/rdata hold whole bus words with the byte lanes as they
// appear on HWDATA/HRDATA (AHB-R20); beat_lanes() names the active lanes.
//
// All payload and response fields are 4-state `logic`: observed X/Z values
// are kept. The bus context (widths, present features) is copied from the
// agent configuration before randomization, so constraints keep generated
// values legal for the instance the item will run on.
// Included by ahb_api_pkg.
// -----------------------------------------------------------------------------

typedef enum bit {
  AHB_READ  = 1'b0,
  AHB_WRITE = 1'b1
} ahb_dir_e;

// Request fields are randomized by sequences. Response fields are filled in place
// by the driver, or set by the observe adapter on a new object per burst.
class ahb_transaction extends uvm_sequence_item;
  `uvm_object_utils(ahb_transaction)

  // ---- Request ----------------------------------------------------------------
  rand ahb_dir_e              dir;          // HWRITE
  rand logic [AHB_MAX_AW-1:0] addr;         // HADDR of the NONSEQ
  rand ahb_burst_e            burst;        // HBURST
  rand ahb_size_e             size;         // HSIZE
  rand int unsigned           len;          // beats
  rand logic [AHB_MAX_DW-1:0] wdata[];      // one bus word per beat (writes)
  rand int unsigned           busy[];       // BUSY phases before each beat; busy[0] == 0
  rand logic [6:0]            prot;         // HPROT; [6:4] needs Extended_Memory_Types
  rand logic                  nonsec;       // HNONSEC; needs Secure_Transfers
  rand logic                  lock;         // HMASTLOCK
  rand int unsigned           idle_cycles;  // IDLE address phases before the NONSEQ

  int unsigned max_busy = 0;  // knob: largest BUSY count per beat (0 = no BUSY)

  // ---- Bus context (not randomized) --------------------------------------------
  int unsigned           bus_addr_width = AHB_MAX_AW;
  int unsigned           bus_data_width = AHB_MAX_DW;
  int unsigned           bus_max_size   = 0;     // log2(bus_data_width / 8)
  bit                    bus_ext_mem    = 1'b0;  // HPROT[6:4] present
  bit                    bus_secure     = 1'b0;  // HNONSEC present
  logic [AHB_MAX_AW-1:0] addr_over_mask = '0;    // bits at or above bus_addr_width
  logic [AHB_MAX_DW-1:0] data_over_mask = '0;    // bits at or above bus_data_width

  // ---- Response / observation ---------------------------------------------------
  logic [AHB_MAX_AW-1:0] beat_addr[];    // HADDR of each beat as driven or observed
  logic [AHB_MAX_DW-1:0] rdata[];        // zero-extended from the bus width (reads)
  logic                  resp[];         // HRESP per beat, 4-state
  int unsigned           wait_states[];  // HREADY LOW cycles per data phase
  int unsigned           beats_done;     // data phases completed (driver) or recorded
  ahb_bfm_status_e       status;         // driver result; monitor: OK or ERROR
  longint unsigned       start_cycle;    // monitor only: sample of the NONSEQ
  longint unsigned       end_cycle;      // monitor only: sample of the last completion
  string                 instance_name;

  // ---- Constraints ----------------------------------------------------------------
  // Beat count per HBURST (AHB-R09); INCR items are limited to AHB_MAX_BEATS (POL-04)
  // and short by default.
  constraint c_len {
    (burst == AHB_BURST_SINGLE) -> len == 1;
    (burst inside {AHB_BURST_WRAP4, AHB_BURST_INCR4})   -> len == 4;
    (burst inside {AHB_BURST_WRAP8, AHB_BURST_INCR8})   -> len == 8;
    (burst inside {AHB_BURST_WRAP16, AHB_BURST_INCR16}) -> len == 16;
    (burst == AHB_BURST_INCR) -> len inside {[1:AHB_MAX_BEATS]};
    if (burst == AHB_BURST_INCR) soft len inside {[1:8]};
  }

  // One array entry per beat
  constraint c_arrays {
    wdata.size() == len;
    busy.size()  == len;
  }

  // Values must fit the bound bus (lossless rule, DATA-02)
  constraint c_fit_bus {
    (addr & addr_over_mask) == 0;
    foreach (wdata[i]) (wdata[i] & data_over_mask) == 0;
  }

  // HSIZE no wider than the bus (AHB-R06)
  constraint c_size {
    size <= bus_max_size;
  }

  // Address aligned to the transfer size (AHB-R07)
  constraint c_aligned {
    (addr & ((64'd1 << size) - 64'd1)) == 0;
  }

  // Incrementing bursts stay inside one 1KB page (AHB-R08); a wrapping burst
  // spans at most 1KB.
  constraint c_1kb {
    if (burst inside {AHB_BURST_WRAP4, AHB_BURST_WRAP8, AHB_BURST_WRAP16})
      (len << size) <= 1024;
    else
      ((addr & 'h3FF) + (len << size)) <= 1024;
  }

  // Reads carry no write data
  constraint c_read_data {
    foreach (wdata[i]) (dir == AHB_READ) -> wdata[i] == 0;
  }

  // BUSY only between beats (AHB-R04), at most max_busy per beat
  constraint c_busy {
    foreach (busy[i]) {
      busy[i] <= max_busy;
      (i == 0) -> busy[i] == 0;
    }
  }

  // Absent HPROT[6:4] and HNONSEC carry 0 (POL-03)
  constraint c_prot {
    !bus_ext_mem -> prot[6:4] == 3'b000;
    !bus_secure  -> nonsec == 1'b0;
  }

  // AHB-R16 recommended HPROT when protection is not generated: non-cacheable,
  // non-bufferable, privileged data access. A sequence switches this off to
  // randomize HPROT.
  constraint c_prot_default {
    soft prot   == 7'b0000011;
    soft nonsec == 1'b0;
  }

  // Unlocked, short IDLE gaps by default; 0 gives back-to-back bursts (POL-05).
  constraint c_defaults {
    soft lock == 1'b0;
    soft idle_cycles inside {[0:2]};
  }

  // status starts OK; the response fields are filled later.
  function new(string name = "ahb_transaction");
    super.new(name);
    status = AHB_ST_OK;
  endfunction

  // Copy the bound instance's widths and features (call before randomize). The
  // masks are built bit by bit, so no shift by the full operand width (LANG-05).
  function void set_bus_context(int unsigned addr_width, int unsigned data_width,
                                bit ext_mem, bit secure);
    bus_addr_width = addr_width;
    bus_data_width = data_width;
    bus_ext_mem    = ext_mem;
    bus_secure     = secure;
    addr_over_mask = '0;
    data_over_mask = '0;
    for (int unsigned i = addr_width; i < AHB_MAX_AW; i++) addr_over_mask[i] = 1'b1;
    for (int unsigned i = data_width; i < AHB_MAX_DW; i++) data_over_mask[i] = 1'b1;
    bus_max_size = 0;
    while ((32'd1 << (bus_max_size + 1)) <= data_width / 8) bus_max_size++;
  endfunction

  // Bytes moved by one beat
  function int unsigned beat_bytes();
    return ahb_size_bytes(size);
  endfunction

  // Address of beat i of this burst (AHB-R05/R09), computed from addr/size/burst
  function logic [AHB_MAX_AW-1:0] expected_beat_addr(int unsigned i);
    logic [AHB_FN_AW-1:0] a = AHB_FN_AW'(addr);
    for (int unsigned n = 0; n < i; n++) a = ahb_next_addr(a, size, burst);
    return AHB_MAX_AW'(a);
  endfunction

  // Active byte lanes of a beat at address a on the bound bus (AHB-R20): the
  // little-endian / byte-invariant lane mapping, lane = address modulo bus bytes.
  function logic [AHB_MAX_SW-1:0] lanes_at(logic [AHB_MAX_AW-1:0] a);
    logic [AHB_MAX_SW-1:0] mask  = '0;
    int unsigned           bytes = bus_data_width / 8;
    int unsigned           first = int'(a % bytes);
    for (int unsigned l = first; l < first + beat_bytes() && l < bytes; l++) mask[l] = 1'b1;
    return mask;
  endfunction

  // Deep copy of every field, including bus context and observation stamps (UVM-03).
  virtual function void do_copy(uvm_object rhs);
    ahb_transaction rhs_;
    super.do_copy(rhs);
    if (!$cast(rhs_, rhs)) begin
      `uvm_fatal("AHB_TXN", "do_copy: argument is not an ahb_transaction")
      return;
    end
    dir            = rhs_.dir;
    addr           = rhs_.addr;
    burst          = rhs_.burst;
    size           = rhs_.size;
    len            = rhs_.len;
    wdata          = rhs_.wdata;
    busy           = rhs_.busy;
    prot           = rhs_.prot;
    nonsec         = rhs_.nonsec;
    lock           = rhs_.lock;
    idle_cycles    = rhs_.idle_cycles;
    max_busy       = rhs_.max_busy;
    bus_addr_width = rhs_.bus_addr_width;
    bus_data_width = rhs_.bus_data_width;
    bus_max_size   = rhs_.bus_max_size;
    bus_ext_mem    = rhs_.bus_ext_mem;
    bus_secure     = rhs_.bus_secure;
    addr_over_mask = rhs_.addr_over_mask;
    data_over_mask = rhs_.data_over_mask;
    beat_addr      = rhs_.beat_addr;
    rdata          = rhs_.rdata;
    resp           = rhs_.resp;
    wait_states    = rhs_.wait_states;
    beats_done     = rhs_.beats_done;
    status         = rhs_.status;
    start_cycle    = rhs_.start_cycle;
    end_cycle      = rhs_.end_cycle;
    instance_name  = rhs_.instance_name;
  endfunction

  // Compares the bus-visible content of the completed beats with 4-state
  // equality: control, beat addresses, responses and the data of the direction.
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    ahb_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 1'b0;
    if (!super.do_compare(rhs, comparer)) return 1'b0;
    if (dir != rhs_.dir || addr !== rhs_.addr || burst != rhs_.burst || size != rhs_.size ||
        prot !== rhs_.prot || nonsec !== rhs_.nonsec || lock !== rhs_.lock ||
        beats_done != rhs_.beats_done)
      return 1'b0;
    for (int unsigned i = 0; i < beats_done; i++) begin
      if (i >= beat_addr.size() || i >= rhs_.beat_addr.size() ||
          i >= resp.size() || i >= rhs_.resp.size())
        return 1'b0;
      if (beat_addr[i] !== rhs_.beat_addr[i] || resp[i] !== rhs_.resp[i]) return 1'b0;
      if (dir == AHB_WRITE && (i >= wdata.size() || i >= rhs_.wdata.size() ||
                               wdata[i] !== rhs_.wdata[i]))
        return 1'b0;
      if (dir == AHB_READ && (i >= rdata.size() || i >= rhs_.rdata.size() ||
                              rdata[i] !== rhs_.rdata[i]))
        return 1'b0;
    end
    return 1'b1;
  endfunction

  // One line for logs: control, then data per completed beat (wdata for writes,
  // rdata for reads) with its response; E marks an ERROR beat.
  virtual function string convert2string();
    string s;
    s = $sformatf("%s %s %s size=%0dB addr=%0h len=%0d prot=%0b nonsec=%b lock=%b",
                  instance_name, dir == AHB_WRITE ? "WR" : "RD", burst.name(), beat_bytes(),
                  addr, len, prot, nonsec, lock);
    for (int unsigned i = 0; i < beats_done; i++) begin
      logic [AHB_MAX_DW-1:0] d = '0;
      if (dir == AHB_WRITE && i < wdata.size()) d = wdata[i];
      if (dir == AHB_READ && i < rdata.size())  d = rdata[i];
      s = {s, $sformatf(" [%0d]%0h%s", i, d, (i < resp.size() && resp[i] === 1'b1) ? "E" : "")};
    end
    return {s, $sformatf(" -> %s done=%0d", status.name(), beats_done)};
  endfunction

endclass : ahb_transaction
