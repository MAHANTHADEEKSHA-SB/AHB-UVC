// HDL-only smoke: reusable core + example Subordinate/top + smoke test.
// Use with -F: paths are relative to this file's directory.
-F ahb_hdl.f
../examples/ahb_example_slave.sv
../examples/ahb_hdl_top.sv
../tests/ahb_hdl_smoke.sv
