# Generic synthesis result

Command: `make synth` (Yosys 0.71, `read_verilog -sv; hierarchy; synth -flatten; stat`)

| Reported item | Value |
|---|---:|
| Design-check problems | 0 |
| Reported cells | 29,525 (including one scope-information pseudo cell) |
| Enabled flip-flop cells (`$_DFFE_PP_`) | 9,600 |
| Enabled resettable flip-flop cells (`$_DFFE_PN0P_`) | 191 |
| Plain/resettable flip-flop cells (other DFF types) | 5 |

This run synthesized both cache RTL modules; it did not include the testbench-only memory model. Yosys flattened the data, tag, and valid arrays into registers in this generic flow. The cell counts are **not** mapped FPGA LUT/flip-flop/BRAM utilization. No target FPGA, timing constraint, or technology library was supplied, so there is **no maximum operating frequency result**. Full tool output is in `synthesis.log`.
