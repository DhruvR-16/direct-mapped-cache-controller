# Direct-Mapped Cache Controller

This project implements a 1 KB direct-mapped cache in SystemVerilog. Phase I established and verified the read-only lookup/refill path. Phase II adds aligned 32-bit writes with a **write-through, write-allocate** policy, mixed-access verification, and measured simulation results. The cache RTL is synthesizable; the main-memory model and testbenches are simulation-only.

## Reports and demonstration

- [Complete IEEE report covering both phases](report/Direct_Mapped_Cache_Complete_IEEE_Report.pdf) and [editable LaTeX source](report/Direct_Mapped_Cache_Complete_IEEE_Report.tex)
- [Phase I prototype video](video/mca-phase1.mp4)
- [Phase II architecture diagram](docs/phase2_block_diagram.png)
- [Phase II results](results/phase2_summary.md) and [team handoff](docs/phase2_implementation_plan.md)
- [Phase II live demo and viva guide](docs/phase2_demo_and_viva.md)

The report describes the verified four-state Phase I read prototype and five-state Phase II read/write controller. The team must confirm actual individual contributions before formal submission; assigned roles in the report are not proof of authorship.

## Architecture

| Property | Value |
|---|---:|
| CPU address and word | 32 bits each; 4-byte aligned |
| Cache data capacity | 1,024 bytes |
| Block size and line count | 16 bytes; 64 lines |
| Words per block | 4 |
| Tag / index / offset | 22 / 6 / 4 bits |
| Simulated main memory | 4,096 bytes; 3-cycle block read |
| Outstanding CPU requests | 1 |

Address mapping: `tag=address[31:10]`, `index=address[9:4]`, and `offset=address[3:0]`. Offset bits `[3:2]` select the 32-bit word. Each line stores a 128-bit block, a 22-bit tag, and a valid bit. Reset invalidates the cache and clears hit/miss counters; it does not erase words written to the test memory.

| Operation | On a hit | On a miss |
|---|---|---|
| Read | Return the cached word | Fetch the aligned 16-byte block, refill, return the word |
| Write | Update one cached word and write the word to memory | Fetch the block, patch and refill it, then write the word to memory |

The controller uses `IDLE`, `LOOKUP`, `MISS_REQUEST`, `MISS_WAIT`, and `WRITE_REQUEST`. A write response is issued only after the main-memory word-write handshake. The memory model initializes word `i` to `0xA5000000+i` and preserves writes across cache reset.

The suggested Project 6 modules are grouped into two synthesizable RTL modules: `cache_line_store.sv` contains the data, tag, and valid arrays; `direct_mapped_cache.sv` contains address decoding, tag comparison, the FSM, and the main-memory interface. The simulated main-memory model is in `tb/main_memory_model.sv`.

## Run and inspect

Install Icarus Verilog, Python 3, and Yosys. Tectonic is also needed to rebuild the IEEE PDFs. From this folder:

```sh
make test                 # Phase I read-only regression on the Phase II RTL
make phase2-test          # directed and seeded mixed read/write traces
make synth               # generic synthesis of the cache RTL
make reports             # rebuild the single IEEE-format PDF
```

`make phase2-test` regenerates expected vectors with `analysis/cache_reference.py`, compiles the RTL/testbench, and checks each operation. Inspect `results/phase2_smoke.log`, `results/phase2_random.log`, and `results/random_read.log` for `PHASE2 ALL TESTS PASSED`. Open the matching VCD files in GTKWave to show request, response, refill, and write handshakes. The mixed trace is reproducible with `python3 analysis/generate_random_trace.py --seed 20261123 --count 128`; the uniform random-read trace uses `--mode read-random` with the same seed.

## Measured results

| Trace | Accesses | Hits | Misses | Hit / miss ratio | Avg. cycles/access |
|---|---:|---:|---:|---:|---:|
| Phase I sequential reads | 16 | 12 | 4 | 75.00% / 25.00% | 3.25 |
| Phase I repeated reads | 16 | 15 | 1 | 93.75% / 6.25% | 2.31 |
| Phase I alternating conflict | 16 | 0 | 16 | 0.00% / 100.00% | 7.00 |
| Uniform random reads | 128 | 13 | 115 | 10.16% / 89.84% | 6.49 |
| Phase II directed mixed | 9 | 5 | 4 | 55.56% / 44.44% | 4.44 |
| Phase II seeded mixed | 128 | 83 | 45 | 64.84% / 35.16% | 4.06 |

The Phase II seeded trace contains 89 reads and 39 writes. It causes 45 block reads and 39 word writes, transferring 876 bytes under the model. Generic Yosys synthesis reports zero design-check problems and 55,448 technology-independent cells for the Phase II RTL. No target-specific frequency result is claimed. See the detailed [hit/miss and AMAT report](results/phase2_summary.md) and [synthesis summary](results/synthesis_summary.md).

## Main files

| Path | Purpose |
|---|---|
| `rtl/direct_mapped_cache.sv` | Synthesizable five-state cache controller |
| `rtl/cache_line_store.sv` | Synthesizable data/tag/valid line storage |
| `tb/main_memory_model.sv` | Simulation-only memory with block reads and word writes |
| `tb/tb_direct_mapped_cache.sv` | Phase I regression testbench |
| `tb/tb_direct_mapped_cache_phase2.sv` | Phase II mixed-access self-checking testbench |
| `analysis/cache_reference.py` | Independent expected-data and hit/miss model |
| `analysis/generate_random_trace.py` | Deterministic mixed-trace generator |
| `traces/` | Directed and seeded mixed-access traces |
| `results/` | Logs, reference vectors, synthesis output, and VCD waveforms |

The repository and group contribution history require each member's own verified work and commits. This local build does not attribute files to individual members.
