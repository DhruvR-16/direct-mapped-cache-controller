#!/usr/bin/env python3
"""Independent functional reference for the Phase II direct-mapped cache.

Input lines are `R ADDRESS` or `W ADDRESS DATA`. This model is not RTL and does
not predict clock cycles; it predicts data, hit/miss decisions, and traffic.
"""

import argparse
import json
from pathlib import Path


CACHE_BYTES = 1024
BLOCK_BYTES = 16
WORD_BYTES = 4
MEMORY_BYTES = 4096
WORDS_PER_BLOCK = BLOCK_BYTES // WORD_BYTES
LINE_COUNT = CACHE_BYTES // BLOCK_BYTES


def load_trace(path: Path):
    operations = []
    for number, raw_line in enumerate(path.read_text().splitlines(), 1):
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        op = parts[0].upper()
        if (op == "R" and len(parts) != 2) or (op == "W" and len(parts) != 3):
            raise ValueError(f"{path}:{number}: expected R ADDRESS or W ADDRESS DATA")
        if op not in ("R", "W"):
            raise ValueError(f"{path}:{number}: unknown operation {op!r}")
        try:
            address = int(parts[1], 0)
            data = int(parts[2], 0) if op == "W" else None
        except ValueError as exc:
            raise ValueError(f"{path}:{number}: invalid number") from exc
        if address < 0 or address >= MEMORY_BYTES or address % WORD_BYTES:
            raise ValueError(f"{path}:{number}: address must be an aligned word in 4 KB memory")
        if data is not None and not 0 <= data <= 0xFFFFFFFF:
            raise ValueError(f"{path}:{number}: write data must fit in 32 bits")
        operations.append((op, address, data))
    return operations


def simulate(operations):
    memory = [0xA5000000 + index for index in range(MEMORY_BYTES // WORD_BYTES)]
    lines = [None] * LINE_COUNT
    hits = misses = block_reads = word_writes = 0
    events = []

    for sequence, (op, address, write_data) in enumerate(operations, 1):
        block_number = address // BLOCK_BYTES
        line_index = block_number % LINE_COUNT
        tag = block_number // LINE_COUNT
        word_index = (address % BLOCK_BYTES) // WORD_BYTES
        line = lines[line_index]
        hit = line is not None and line["tag"] == tag

        if hit:
            hits += 1
        else:
            misses += 1
            block_reads += 1
            base_word = (address // BLOCK_BYTES) * WORDS_PER_BLOCK
            line = {"tag": tag, "words": memory[base_word:base_word + WORDS_PER_BLOCK]}
            lines[line_index] = line

        read_data = None
        if op == "W":
            line["words"][word_index] = write_data
            memory[address // WORD_BYTES] = write_data
            word_writes += 1
        else:
            read_data = line["words"][word_index]

        events.append({
            "sequence": sequence,
            "op": op,
            "address": f"0x{address:08X}",
            "hit": hit,
            "read_data": None if read_data is None else f"0x{read_data:08X}",
            "write_data": None if write_data is None else f"0x{write_data:08X}",
        })

    accesses = len(events)
    summary = {
        "accesses": accesses,
        "hits": hits,
        "misses": misses,
        "hit_rate_percent": round(100 * hits / accesses, 2) if accesses else 0.0,
        "miss_rate_percent": round(100 * misses / accesses, 2) if accesses else 0.0,
        "block_reads": block_reads,
        "word_writes": word_writes,
        "memory_bytes_transferred": block_reads * BLOCK_BYTES + word_writes * WORD_BYTES,
    }
    return {"events": events, "summary": summary}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path, help="input trace: R address or W address data")
    parser.add_argument("--output", type=Path, help="write JSON to a file instead of stdout")
    parser.add_argument("--vectors", type=Path,
                        help="write plain vectors for the SystemVerilog testbench")
    args = parser.parse_args()
    result = simulate(load_trace(args.trace))
    payload = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload)
    else:
        print(payload, end="")
    if args.vectors:
        args.vectors.parent.mkdir(parents=True, exist_ok=True)
        args.vectors.write_text("".join(
            f"{int(event['op'] == 'W')} {int(event['address'], 16):08x} "
            f"{int(event['write_data'] or '0', 16):08x} {int(event['hit'])} "
            f"{int(event['read_data'] or '0', 16):08x}\n"
            for event in result["events"]
        ))


if __name__ == "__main__":
    main()
