# Generic synthesis result - Phase II

Command: `make synth`, Yosys 0.71+post, `read_verilog -sv; hierarchy -top direct_mapped_cache; synth -top direct_mapped_cache -flatten; stat`.

| Reported item | Phase I read-only | Phase II read/write |
|---|---:|---:|
| Design-check problems | 0 | 0 |
| Generic cells (includes one scope-information pseudo cell) | 29,525 | 55,448 |
| Enabled flip-flop cells (`$_DFFE_PP_`) | 9,600 | 9,600 |

The Phase I log is `results/phase1_synthesis.log`; the current Phase II log is `results/synthesis.log`. Both synthesize only `rtl/cache_line_store.sv` and `rtl/direct_mapped_cache.sv`, not the testbench memory model. The increased generic cell count reflects the added word-update and write-control logic in this flow. It is **not** a target-device area or performance measurement.

No FPGA target, technology library, or clock constraint was supplied. These outputs do **not** report FPGA LUT/flip-flop/BRAM utilization or maximum operating frequency. A device-specific tool flow is required for those claims.
