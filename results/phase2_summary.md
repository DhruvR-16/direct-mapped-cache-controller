# Verified hit/miss and AMAT results

Run `make test` for the Phase I read traces and `make phase2-test` for the separate random-read and mixed traces. The testbenches check every response, hit/miss counters, memory-request counts, reset persistence, and a stalled write handshake. All logs end with a pass marker.

| Read trace | Accesses | Hits | Misses | Hit ratio | Miss ratio | Average cycles/access |
|---|---:|---:|---:|---:|---:|---:|
| Directed | 7 | 4 | 3 | 57.14% | 42.86% | 4.14 |
| Sequential | 16 | 12 | 4 | 75.00% | 25.00% | 3.25 |
| Repeated | 16 | 15 | 1 | 93.75% | 6.25% | 2.31 |
| Alternating conflict | 16 | 0 | 16 | 0.00% | 100.00% | 7.00 |
| Uniform random (seed 20261123) | 128 | 13 | 115 | 10.16% | 89.84% | 6.49 |

| Mixed trace | Accesses | Read hits/misses | Write hits/misses | Hit ratio | Miss ratio | Block reads | Word writes | Average cycles/access |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Directed mixed | 9 | 4 / 3 | 1 / 1 | 55.56% | 44.44% | 4 | 2 | 4.44 |
| Seeded mixed (seed 20261123) | 128 | 68 / 21 | 15 / 24 | 64.84% | 35.16% | 45 | 39 | 4.06 |

Hit ratio is `hits / accesses`; miss ratio is `misses / accesses`. Under the included three-cycle block-read memory model and no added backpressure, read hits take 2 measured cycles and read misses 7. Uniform random-read AMAT is `(13*2 + 115*7)/128 = 6.4921875` cycles/access. Write hits take 3 measured cycles and write misses 8, so mixed-trace AMAT is `(68*2 + 21*7 + 15*3 + 24*8)/128 = 4.0625` cycles/access. These values count cycles from request issue to response under this testbench; they are not hardware timing results.

The directed trace writes `0x12345678` at address `0x8` and `0xDEADBEEF` at `0x400`. After cache reset, both values are read back from main memory, while the untouched adjacent word retains its original value. The stalled write holds address/data steady and does not respond early. The traffic formula is `16 * block_reads + 4 * word_writes`. Block fills can make transferred bytes exceed a simple 4-byte-per-access count; no separate uncached architecture was implemented.

Evidence: `results/phase1_regression.log`, `results/random_read.log`, `results/phase2_smoke.log`, `results/phase2_random.log`, matching VCD files, and generated reference JSON/vector files. See `results/synthesis_summary.md` for the synthesis result and its limits.
