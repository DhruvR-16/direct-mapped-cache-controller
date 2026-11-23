# Complete project demonstration and viva guide

## What the project does

The project is a 1 KB direct-mapped cache controller for aligned 32-bit CPU reads and writes. It has 64 lines of 16 bytes each. The address split is tag `[31:10]`, index `[9:4]`, offset `[3:0]`. Bits `[3:2]` select one of four words in a line. A valid line with a matching tag is a hit; otherwise the controller fetches the mapped block and replaces that line.

The final controller implements write-through, write-allocate: every write goes to main memory, and a write miss fetches and installs the block before updating the requested word. The cache accepts one CPU request at a time. The five implemented states are `IDLE`, `LOOKUP`, `MISS_REQUEST`, `MISS_WAIT`, and `WRITE_REQUEST`.

## Live demonstration (about 5 minutes)

1. Open `docs/phase2_block_diagram.png`. Explain the CPU request/response, controller FSM, line storage, and simulated main memory.
2. Run **`make test` once**. Show `PROJECT ALL TESTS PASSED`, `SYNTHESIS CHECK PASSED: 0 problems`, and `PROJECT TEST PASSED`. The single run verifies 317 accesses plus reset and write-stall checks.
3. Open **`results/full_project.vcd`** in Surfer. Show `req_valid/req_ready`, `req_addr`, `req_write/req_wdata`, `resp_valid/resp_hit`, `mem_req_valid/mem_req_ready`, `mem_resp_valid`, `mem_write_valid/mem_write_ready`, and hit/miss counters. Explain a read hit, a refill, a write, and a stalled write in one timeline.
4. Open `results/full_project.log` and `results/phase2_summary.md`. Explain the integrated result: 137 hits and 180 misses across 317 accesses, a 43.22% hit ratio, and 4.98 measured cycles/access. The detailed trace table shows how sequential, repeated, random, and conflict patterns affect locality.
5. State that the cycle values depend on the included three-cycle memory model. Generic synthesis checks the RTL but does not give a target FPGA frequency.

## Questions each member should be able to answer

### M1 Naman Jain - controller and integration

- **What happens on a read miss?** `LOOKUP` detects invalid/mismatched tag; `MISS_REQUEST` sends the aligned block address; `MISS_WAIT` receives and refills the block, then responds with the selected word.
- **Why is there a separate `WRITE_REQUEST` state?** The controller must hold the word-write request stable until memory accepts it and must not acknowledge the CPU write early.
- **What remains stable while waiting?** The captured address, write data, and operation flag. Only one CPU request can be outstanding.

### M2 Kavya Jain - architecture and line storage

- **Why 64 lines?** `1024 / 16 = 64`.
- **Why 22/6/4 address bits?** A 16-byte block needs 4 offset bits and 64 lines need 6 index bits, leaving 22 tag bits in a 32-bit address.
- **What does reset clear?** Valid bits and counters. Data/tag bits need no reset because invalid lines cannot hit. Main memory retains accepted writes.
- **How is one word updated?** The selected 32-bit lane is written while other words in the 128-bit block remain unchanged.

### M3 Lakshay Agrawal - memory model and write policy

- **What is write-through?** Every accepted CPU write also updates main memory.
- **What is write-allocate?** A write miss reads and installs the containing block, then updates the addressed word.
- **Why patch the refill block?** The cache line must contain the new value before the write completes; the other three words come from the fetched block.
- **What does the memory handshake mean?** A word write takes effect on a clock edge with valid and ready both high; no separate write acknowledgement is modeled.

### M4 Dhruv Ramani - verification

- **How is correctness checked?** The testbench compares every response with independent reference vectors, then checks hit/miss counters and memory traffic. A failure calls `$fatal`.
- **Which traces and special cases were tested?** Sequential, repeated, uniform random, and mixed accesses, plus cold miss, block hit, conflict replacement, write hit, write miss, adjacent word preservation, readback after reset, and stalled write readiness.
- **How is the random trace repeatable?** `analysis/generate_random_trace.py` uses a fixed seed of `20261123`; the committed trace has 128 operations.

### M5 Akhilesh Kumar - analysis and reports

- **How are hit and miss ratios calculated?** `hits / accesses` and `misses / accesses`; for the mixed trace, `83/128 = 64.84%` and `45/128 = 35.16%`.
- **How is average access time calculated?** `(68*2 + 21*7 + 15*3 + 24*8)/128 = 4.0625` measured cycles/access for read hits, read misses, write hits, and write misses.
- **Why can bytes transferred exceed 4 bytes per request?** Every miss fetches a full 16-byte block, and every write also sends a 4-byte word.
- **What does synthesis establish?** The RTL can be synthesized in the generic Yosys flow with zero design-check problems; it does not establish FPGA frequency or mapped resource usage.

These are assigned explanation areas. Each member should describe only work they actually performed or reviewed; the local build alone does not prove personal authorship.
