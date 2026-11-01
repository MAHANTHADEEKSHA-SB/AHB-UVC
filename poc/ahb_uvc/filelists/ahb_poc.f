// Full UVM POC: reusable HDL + HVL core, example HDL, tests, HVL top.
// Tops: ahb_hdl_top ahb_hvl_top. UVM library supplied by the simulator.
// Use with -F: paths are relative to this file's directory.
-F ahb_hdl.f
-F ahb_hvl.f
../examples/ahb_example_slave.sv
../examples/ahb_hdl_top.sv
+incdir+../tests
../tests/ahb_poc_test_pkg.sv
../examples/ahb_hvl_top.sv
