//*****************************************************//
//    CLASS     : AHB_MASTER_TRANSACTION_ITEM          //
//    AUTHOR    : Mahantha Deeksha S B (WS1259)        //
//    FILE      : ahb_m_seq_item.sv                    //
//*****************************************************//
class ahb_m_seq_item extends uvm_sequence_item;
  rand bit [`ADDR_WIDTH - 1 : 0] haddr;
  rand bit [`DATA_WIDTH - 1 : 0] hwdata [];
  bit      [`DATA_WIDTH - 1 : 0] hrdata [];
  bit      [`ADDR_WIDTH - 1 : 0] baddr_q [$];
  
  rand hwrite_e hwrite;
  rand htrans_e htrans [];
  rand hburst_e hburst;
  rand hresp_e  hresp;
  rand hsize_e  hsize;
  rand int unsigned no_of_busy;
  
  // makes sure address width is less than equal to hsize
  constraint c_hsize { (8*(2**hsize)) <= `ADDR_WIDTH;}
  // no of busy between transfers
  constraint c_busy_no { no_of_busy inside {[0 : 3]};}
  // the address alignment with respect to hsize
  constraint c_allign {solve hsize before haddr;
                       (hsize == HALFWORD)    -> haddr[0]     == 1'b0;
                       (hsize == WORD)        -> haddr[1 : 0] == 2'b00;
                       (hsize == DOUBLEWORD)  -> haddr[2 : 0] == 3'b000;
                       (hsize == WORD_LINE_4) -> haddr[3 : 0] == 4'b0000;
                       (hsize == WORD_LINE_8) -> haddr[4 : 0] == 5'b00000;
                       (hsize == WORD_512)    -> haddr[5 : 0] == 6'b000000;
                       (hsize == WORD_1024)   -> haddr[6 : 0] == 7'b0000000;
                       }

  constraint c_hburst {solve hburst before htrans;
                       solve hburst before hwdata;
                       (hburst == SINGLE) -> {hwdata.size() == 1; 
                                              no_of_busy == 0;
                                              htrans.size() == 1;
                                              htrans[0] inside {IDLE, NONSEQ};
                                              haddr[10:0] <= (1024 - 1*(2**hsize));}
                       
                       (hburst == INCR)   -> {(hwdata.size() + no_of_busy) < (1024/(2**hsize)); 
                                              (htrans.size() + no_of_busy) < (1024/(2**hsize));
                                               haddr[10:0] <= (1024 - ((htrans.size)*(2**hsize)));}
                       
                       ((hburst == WRAP4) || (hburst == INCR4))   -> {hwdata.size() == (4 + no_of_busy); 
                                                                      htrans.size() == (4 + no_of_busy);
                                                                      haddr[10:0] <= (1024 - 4*(2**hsize));}
                       
                       ((hburst == WRAP8) || (hburst == INCR8))   -> {hwdata.size() == (8 + no_of_busy); 
                                                                      htrans.size() == (8 + no_of_busy);
                                                                      haddr[10:0] <= (1024 - 8*(2**hsize));}
                       
                       ((hburst == WRAP16) || (hburst == INCR16)) -> {hwdata.size() == (16 + no_of_busy); 
                                                                      htrans.size() == (16 + no_of_busy);
                                                                      haddr[10:0] <= (1024 - 16*(2**hsize));}
                       }
  
  constraint c_htrans {if((hwdata.size == 1) && (hburst == INCR))
                          {htrans.size() == 1 + no_of_busy;
                           htrans[0] == NONSEQ;}
                       else if(hburst != SINGLE)
                         foreach(htrans[i]){
                           if(i == 0)
                             {htrans[i] == NONSEQ};
                           else if(i <= no_of_busy)
                             {htrans[i] == BUSY};
                           else 
                             {htrans[i] == SEQ};
                             }
                      }
                           
 constraint c_busy_data{foreach(htrans[i]){
                           if(htrans[i] == BUSY)
                              {hwdata[i] == '0};
                                           }
                         }
  
   constraint c_min_beat {hwdata.size() > 0; htrans.size() > 0 ;}
  
  uvm_event_pool events;
   // factory registration 
   `uvm_object_utils_begin(ahb_m_seq_item)
        `uvm_field_int(haddr,UVM_DEFAULT)
        `uvm_field_enum(hwrite_e,hwrite,UVM_DEFAULT)
        `uvm_field_enum(hburst_e,hburst,UVM_DEFAULT)
        `uvm_field_array_enum(htrans_e,htrans,UVM_DEFAULT)
        `uvm_field_enum(hsize_e,hsize,UVM_DEFAULT)
        `uvm_field_queue_int(baddr_q,UVM_DEFAULT)
        `uvm_field_array_int(hwdata,UVM_DEFAULT)
        `uvm_field_array_int(hrdata,UVM_DEFAULT)
        `uvm_field_int(no_of_busy,UVM_DEFAULT)
        `uvm_field_enum(hresp_e,hresp,UVM_DEFAULT)
   `uvm_object_utils_end
      
   //`uvm_object_utils_end

   // constructor method
   function new(string name = "ahb_m_seq_item");
      super.new(name);
      events = get_event_pool();
   endfunction : new
//--------------------------------------------------------------------------
  // Wait for an event - called by sequence
  task wait_trigger(string evnt);
    uvm_event e = events.get(evnt);
    e.wait_trigger();
  endtask: wait_trigger
//--------------------------------------------------------------------------
  // Trigger an event - called by driver
  function void trigger(string evnt);
    uvm_event e = events.get(evnt);
    e.trigger();
  endfunction: trigger
//--------------------------------------------------------------------------
  function void do_copy(uvm_object rhs);
    ahb_m_seq_item rhs_;

    super.do_copy(rhs);
    if(!$cast(rhs_, rhs)) begin
      `uvm_fatal("do_copy", "cast failed, check type compatability");
      return;
    end
    haddr = rhs_.haddr;
    hwdata = rhs_.hwdata;
    hwrite = rhs_.hwrite;
    htrans = rhs_.htrans;
    hresp = rhs_.hresp;
    hrdata = rhs_.hrdata;
    hburst = rhs_.hburst;
    hsize = rhs_.hsize;
  endfunction: do_copy
//----------------------------------------------------------------------------
  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    ahb_m_seq_item rhs_;

    if(!$cast(rhs_, rhs)) begin
      `uvm_fatal("do_compare", "cast failed, check type compatability");
      return 0;
    end
    do_compare = super.do_compare(rhs, comparer) &&
               haddr == rhs_.haddr &&
               hwdata == rhs_.hwdata &&
               hwrite == rhs_.hwrite &&
               htrans == rhs_.htrans &&
               hresp == rhs_.hresp &&
               hrdata == rhs_.hrdata;
  endfunction: do_compare
//--------------------------------------------------------------
 /* function string convert2string();
    string s;

    s = super.convert2string();
    $sformat(s, "%s\n[HADDR]:\t'd%0d\n[HWRITE]:\t%s\n[HTRANS]:\t%0p\n[HBURST]: \t%s\n[HRESP]: \t%s\n[BADDR_Q]: \t%0p \n[HSIZE]: \t%s \n Data Fields:\n",s, haddr, hwrite, htrans, hburst.name(),hresp.name(),baddr_q,hsize.name());
    $sformat(s, "%s\t[HWDATA]: %0p \n \t[HRDATA]: %0p \n", s, hwdata, hrdata);
    return s;
  endfunction: convert2string
//-------------------------------------------------------------
   function void do_print(uvm_printer printer);
     printer.m_string = convert2string();
   endfunction: do_print*/
//--------------------------------------------------------------
   function void do_record(uvm_recorder recorder);
     super.do_record(recorder);

     `uvm_record_field("haddr", haddr)
     `uvm_record_field("hwrite", hwrite)
     `uvm_record_field("htrans", htrans)
     `uvm_record_field("hburst", hburst)
     `uvm_record_field("hrdata", hrdata)
     `uvm_record_field("hwdata", hwdata)
     `uvm_record_field("hresp", hresp)
   endfunction: do_record
endclass : ahb_m_seq_item
