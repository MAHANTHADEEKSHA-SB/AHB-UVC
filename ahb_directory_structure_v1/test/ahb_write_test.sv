class ahb_write_test extends ahb_base_test;
  ahb_m_write_seq seqa;
  
  `uvm_component_utils(ahb_write_test)
  
  function new(string name = "ahb_write_test",uvm_component parent);
    super.new(name,parent);
  endfunction : new
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seqa = ahb_m_write_seq :: type_id :: create("seqa");
  endfunction : build_phase
  
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seqa.start(env.ahb_master.m_sequencer);
    #30;
    phase.drop_objection(this);
  endtask : run_phase
  
endclass : ahb_write_test