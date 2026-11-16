# Phase I report and video handoff

Use this document with the verified source and simulation results in the repository. The official Phase I submission requires an IEEE-format report, a video no longer than five minutes, and a GitHub repository link. The deadline provided by the course is **16 November 2026, 11:59 PM IST**.

## What the team built

The prototype is a read-only, 1 KB direct-mapped cache with 16-byte blocks, 64 lines, and 32-bit addresses. It receives aligned word-read requests from a requester and connects to a fixed-latency simulated memory. The address is split into a 22-bit tag, 6-bit index, and 4-bit offset. The `cache_line_store` module holds each block, its tag, and a valid bit; `direct_mapped_cache` controls lookup and refill. A tag match on a valid line is a hit; otherwise the controller requests the aligned block from memory and refills the line. The design counts hits and misses. See `cache_block_diagram.svg` and the RTL for the implemented behavior.

## IEEE report outline

Keep claims within the demonstrated prototype. Use the course's IEEE paper template and identify all five authors. Suggested content:

1. **Abstract:** State the memory-hierarchy problem, the 1 KB direct-mapped design, the Verilog/simulation method, and a concise result: 75% hit rate for sequential word access, 93.75% for repeated access, and 0% for alternating same-index conflicts in the supplied traces. These numbers are trace-specific.
2. **Literature Review:** Explain temporal locality, spatial locality, direct mapping, valid/tag/index/offset, compulsory and conflict misses, and average memory access time. Compare the direct-mapped approach conceptually with an uncached memory and a set-associative cache. Cite architecture textbooks, course notes, or papers that the team actually consulted; verify bibliographic details before submission.
3. **Proposed Solution:** Include the architecture diagram, configuration table, 22/6/4-bit address split, cache arrays, CPU and memory interfaces, controller state sequence, and a paragraph on reset/valid bits. The arrays hold 8,192 data bits, 1,408 tag bits, and 64 valid bits. Explain that the memory model holds deterministic words and responds after a fixed three-cycle latency. Include the test plan and expected behavior of the four traces.
4. **Individual Contributions:** Make a five-row table with each real member's name, files/sections/tasks completed, and GitHub commit evidence. Do not attribute unperformed work.
5. **References:** Number IEEE references in citation order and cite them in the text. Include the actual simulator/tool documentation if you discuss tool behavior. Do not invent sources.

The Phase I rubric does not require a Results and Discussion section, but a small prototype-evidence table after Proposed Solution may help explain the working demonstration. The final Phase II report must add the full Results and Discussion and Conclusion sections.

### Verified evidence to use

| Trace | Pattern | Hits / total | Hit rate | Average cycles/access |
|---|---|---:|---:|---:|
| Directed | Cold, within-block, conflict replacement | 4 / 7 | 57.14% | 4.14 |
| Sequential | 16 consecutive word addresses | 12 / 16 | 75.00% | 3.25 |
| Repeated | Same word 16 times | 15 / 16 | 93.75% | 2.31 |
| Conflict | Alternate addresses `0x0` and `0x400` | 0 / 16 | 0.00% | 7.00 |

The testbench also verifies returned data and checks that the number of actual main-memory requests equals the miss count. The 7-cycle figure is the observed **miss path** in this model, not a separately implemented uncached architecture, physical-memory result, or FPGA measurement. A simple model-level AMAT for a trace is `hit rate × 2 + miss rate × 7` cycles, which matches the measured averages apart from rounding. Generic synthesis also completed; see `results/synthesis_summary.md`. It does not establish FPGA utilization or maximum frequency.

## Video script and screen plan (target: 4:30–4:50)

Replace bracketed names with the actual members. Everyone must be introduced clearly. Give each member a real speaking or screen role where practical.

| Time | Spoken content | Screen |
|---|---|---|
| 0:00–0:35 | “Our project is a Direct-Mapped Cache Controller. The five team members are [names]. We built a Verilog prototype that stores recently fetched memory blocks and reports hits and misses.” | Title slide with project title and all five names. |
| 0:35–1:20 | “The cache is 1 KB, with 64 lines and 16 bytes per line. A 32-bit address has a 22-bit tag, 6-bit index, and 4-bit offset. The index selects one line; its valid bit and tag determine a hit.” | `docs/cache_block_diagram.svg`; highlight address fields. |
| 1:20–2:05 | “On a hit, the controller returns the requested word. On a miss, it requests the whole aligned block, stores the block and tag, sets valid, then returns the word. We used a three-cycle simulated memory.” | Show `rtl/direct_mapped_cache.sv`, state names and refill logic. |
| 2:05–3:30 | “We run a self-checking testbench. A first read misses, other words in that block hit, and addresses 0 and 0x400 conflict because they map to the same line.” | Run `make test`; show PASS lines and `ALL TESTS PASSED`. Optionally show `results/cache.vcd` in a waveform viewer. |
| 3:30–4:20 | “Sequential access gave 12 hits out of 16; repetition gave 15 out of 16; alternating conflict addresses gave zero hits. This shows how locality and mapping change cache effectiveness.” | Show the result table in README or a slide. |
| 4:20–4:45 | “[Names] worked on [actual tasks]. Next we plan to add writes and synthesis analysis for Phase II.” | Contributions slide; repository URL and QR code if useful. |

Record the terminal at a readable font size. Do one rehearsal and check the exported video duration, audio, all five names, visible simulation, and share permissions.

## Submission checklist

- [ ] Add the five real names and contributions to README and report.
- [ ] Add the IEEE-format Phase I report to the repository and link it in README.
- [ ] Record and upload a video **under five minutes**; put the working link in README.
- [ ] Ensure all source, testbench, diagram, simulation log, and waveform files are committed.
- [ ] If discussing synthesis, use the generic-cell result with its stated limitations.
- [ ] Have each member commit their own meaningful work from their own account.
- [ ] Check that another person can open the GitHub repository and video link.
- [ ] Submit the repository link through the course form before the deadline.

