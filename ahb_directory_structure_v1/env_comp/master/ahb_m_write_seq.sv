class ahb_m_write_seq extends ahb_m_base_seq;
  `uvm_object_utils(ahb_m_write_seq)
  function new(string name = "ahb_m_write_seq");
    super.new(name);
  endfunction : new
  
  task body();
    ahb_m_seq_item trans;
    trans = ahb_m_seq_item :: type_id :: create("trans");
    start_item(trans);
    assert(trans.randomize() with {hsize == WORD;
                                   hburst == WRAP4;
                                   hwrite == AHB_WRITE;
                                   haddr == 'h34;
                                   no_of_busy == 1;
                                   });
    finish_item(trans);
    get_response(trans);
    //trans.print();
  endtask : body
endclass : ahb_m_write_seq