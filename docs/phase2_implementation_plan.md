# Team responsibilities for the complete cache project

The final project is one 1 KB direct-mapped cache controller. It handles aligned 32-bit reads and writes with 16-byte blocks, 64 cache lines, write-through, and write-allocate. The team's demonstration uses one command, `make test`, which creates `results/full_project.log` and `results/full_project.vcd` and runs generic synthesis.

These are assigned areas to study and explain. Repository commits and each person's actual work determine individual contribution credit.

| Member | Area | Main files and concepts |
|---|---|---|
| M1 Naman Jain | Controller and integration | `rtl/direct_mapped_cache.sv`; five-state FSM, hit/miss decision, request/response handshakes, refill, and write completion |
| M2 Kavya Jain | Storage and address mapping | `rtl/cache_line_store.sv`; 64 lines, 22/6/4 tag/index/offset split, data/tag/valid arrays, block refill, selected-word update |
| M3 Lakshay Agrawal | Memory model and write protocol | `tb/main_memory_model.sv`; 4 KB test memory, three-cycle block reads, word writes, write-through and write-allocate behavior |
| M4 Dhruv Ramani | Verification and traces | `tb/tb_direct_mapped_cache_phase2.sv`, `Makefile`, and `traces/`; self-checking requests, counters, memory traffic, reset persistence, backpressure, one VCD |
| M5 Akhilesh Kumar | Reference model and results | `analysis/cache_reference.py`, `results/phase2_summary.md`, report; independent expected vectors, hit/miss ratios, AMAT, synthesis interpretation |

## One complete test run

```sh
make test
```

The command generates a deterministic 317-access trace with sequential, repeated, conflict, uniform-random, mixed read/write, and directed operations. It compares every response with independent expected vectors, checks hit/miss and memory-transaction counts, then checks written data after cache reset and a stalled write. A successful run prints `PROJECT ALL TESTS PASSED`, `SYNTHESIS CHECK PASSED: 0 problems`, and `PROJECT TEST PASSED`.

Open `results/full_project.vcd` in a waveform viewer for the final demonstration. Show request, response, memory block-read and word-write handshakes, and hit/miss counters. The trace's overall result is 137 hits and 180 misses in 317 accesses. The measured average is 4.98 cycles/access under the included memory model.

The cache RTL is synthesizable. The 4 KB main memory and testbenches are simulation models. Generic Yosys synthesis does not establish a target FPGA's frequency or mapped resource use.
