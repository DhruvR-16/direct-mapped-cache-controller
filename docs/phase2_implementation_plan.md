# Phase II implementation plan

## Goal and scope

Extend the Phase I read-only, 1 KB direct-mapped cache to support aligned 32-bit writes. Use a **write-through, write-allocate** policy. Keep the existing 32-bit address, 16-byte block, 64-line organization, one outstanding CPU request, and four-word block refill. Complete the project with mixed read/write tests, a reference trace, hit/miss and memory-traffic measurements, generic synthesis, and a final IEEE report with results and discussion.

The integrated implementation and tests are now complete in this local workspace. The member sections below are **assigned review and contribution areas**, not proof that a particular person authored these files. Each member should inspect the corresponding code, make any substantive corrections or improvements, and commit only their own actual work under their own GitHub account when the team is ready to publish.

## Behavioral contract

| Event | Cache action | Main-memory action | CPU response |
|---|---|---|---|
| Read hit | Select the cached word | None | Return word, `resp_hit=1` |
| Read miss | Refill the indexed line | Read one aligned 16-byte block | Return requested word, `resp_hit=0` |
| Write hit | Replace the selected cached word | Write one 32-bit word | Respond after memory accepts the write, `resp_hit=1` |
| Write miss | Read a block, patch the selected word, and refill the line | Read one aligned block, then write one 32-bit word | Respond after memory accepts the write, `resp_hit=0` |

The tag/index/offset split remains 22/6/4 bits. CPU addresses must be aligned to 4 bytes. A write response uses `resp_valid` and `resp_hit`; set `resp_data` to zero for writes. `hit_count` and `miss_count` count all accepted CPU operations, including writes. Cache reset invalidates lines and clears counters, while the test memory retains its word contents. Only the controller and line-store modules are synthesizable; the main-memory model stays in `tb/`.

### Interface changes

Add `req_write` and `req_wdata[31:0]` to `direct_mapped_cache`. The existing CPU read signals and block-read memory signals remain. Add a separate word-write memory channel:

```text
mem_write_valid   cache -> memory
mem_write_ready   memory -> cache
mem_write_addr[31:0] cache -> memory
mem_write_data[31:0] cache -> memory
```

A write transfers on a clock edge with `mem_write_valid && mem_write_ready`. The controller holds valid, address, and data stable until that edge. The test memory can accept a write when it is not servicing a block read. The cache must not issue read and write memory requests together. There is no separate write acknowledgement; acceptance completes the write. The controller must not respond to the CPU before acceptance. On a write miss, merge `req_wdata` into the returned block before refilling so that the new cached line and main memory agree. On a write hit, update the cached word on the same accepted memory-write edge. The legacy Phase I testbench should tie the new CPU write inputs low so `make test` remains a regression check.

For the line store, use `word_write_en`, `word_write_index[5:0]`, `word_write_select[1:0]`, and `word_write_data[31:0]`. The controller drives these on an accepted write hit; `word_write_select` comes from address bits `[3:2]`. Give `refill_en` priority over `word_write_en`. In `main_memory_model`, call the new ports `write_valid`, `write_ready`, `write_addr[31:0]`, and `write_data[31:0]`; the testbench connects them to the controller's `mem_write_*` signals. This naming contract lets the modules be developed independently.

## Member work and commit boundaries

### M1 Naman Jain — controller and system integration

- Own `rtl/direct_mapped_cache.sv` and the top-level signal connections.
- Latch `req_write` and `req_wdata` with `req_addr`. Implement write hit, write miss, block refill, and word-write handshake with the policy above. Preserve the read path and one-request-at-a-time behavior.
- Connect the new ports in the Phase I regression testbench with `req_write=0` and `req_wdata=0` unless Lakshay has already integrated the Phase II bench.
- Write the final report's controller-FSM and end-to-end workflow subsection, using the implemented states and waveform evidence.
- **Completion evidence:** `make test` still passes; the mixed read/write test passes after integration; a waveform shows one write hit and one write miss. Commit the controller change in Naman's account.

### M2 Kavya Jain — cache-line storage

- Own `rtl/cache_line_store.sv`; coordinate the exact added port names with Naman before editing the controller interface.
- Add a selected-word write port for a write hit. A refill writes the entire block and tag; a word write changes only one 32-bit lane in an existing line. Reset clears valid bits but does not erase data or tags.
- Handle refill/write priority explicitly, although the controller should never request both on one edge.
- Write the final report's cache-organization and address-mapping subsection. Check the literature-review statements and references for this topic.
- **Completion evidence:** a small line-store test checks that three other words remain unchanged after a word update, that a refill replaces the old block/tag, and that reset invalidates the line. Commit RTL and that focused test in Kavya's account.

### M3 Lakshay Agrawal — main-memory model and protocol

- Own `tb/main_memory_model.sv`.
- Add the word-write channel above. Accept a word write only when ready; update exactly the addressed word; preserve the existing three-cycle block-read behavior and initialization pattern. Reject unaligned or out-of-range addresses in simulation.
- Keep memory contents across a cache reset. Avoid accepting a block read and word write on the same edge.
- Write the final report's memory-interface and write-policy subsection, including why memory retains data across cache reset.
- **Completion evidence:** a focused memory test writes one word and then reads its block, confirming that the new word is present and adjacent words are unchanged. Commit model and focused test in Akhilesh's account.

### M4 Dhruv Ramani — integrated verification

- Own `tb/tb_direct_mapped_cache_phase2.sv` and the Phase II simulation target in `Makefile`.
- Add directed checks for read/write hit and miss, same-block word preservation, same-index conflict replacement, write-through to main memory, and a write followed by a read after cache reset.
- Add a deterministic mixed trace and compare each operation against `analysis/cache_reference.py` output. Check returned data, `resp_hit`, hit/miss counters, block-read count, and word-write count. Include a timeout and print a clear final pass marker.
- Write the final report's verification-method and measured-results subsection from actual Phase II logs.
- **Completion evidence:** `make test` and `make phase2-test` pass, with a saved log and waveform. Commit the testbench and test target in Lakshay's account.

### M5 Akhilesh Kumar — reference model, measurements, and final integration

- Own `analysis/cache_reference.py`, `traces/phase2_smoke.trace`, the final results tables, and integration documentation. The first two are the Phase II starter files in this workspace.
- Compare the integrated RTL trace with the reference model. Record read/write hit rates, average request-to-response cycles, block reads, word writes, and bytes transferred. Run generic synthesis after the RTL is complete and record its tool version and limitations.
- Integrate the team's writing into the final IEEE report with these required sections: Abstract, Literature Review, Proposed Solution, Results and Discussion, Individual Contributions, Conclusion, and References. Update `README.md`. Obtain an FPGA device/tool flow before claiming FPGA resource use or maximum frequency.
- **Completion evidence:** archived test output, reproducible metrics, a passing synthesis check, and a final report whose statements match the code. Commit these changes in Dhruv's account.

## Integration order and acceptance

1. Kavya and Akhilesh review and improve the line store and memory model, with focused checks.
2. Naman reviews the controller and interface, keeping the Phase I regression passing.
3. Lakshay reviews the end-to-end testbench and mixed trace checks.
4. Dhruv reviews the full checks, results, documentation, and report. Each person records their own actual contribution.

The final demonstration must show: a read miss followed by a hit, a write hit, a write miss with allocation, a conflict eviction, and a read after reset proving that write-through updated main memory. Do not use the Phase I log as evidence for new write behavior.

The directed trace produces **9 operations, 5 hits, 4 misses, 4 block reads, 2 word writes, and 72 bytes of memory traffic** in both the independent model and the passing RTL simulation. The seeded 128-operation trace also passes; see `results/phase2_summary.md`.
