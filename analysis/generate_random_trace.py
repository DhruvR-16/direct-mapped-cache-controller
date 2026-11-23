#!/usr/bin/env python3
"""Generate a reproducible mixed read/write trace with locality and conflicts."""

import argparse
import random
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=20261123)
    parser.add_argument("--count", type=int, default=128)
    parser.add_argument("--mode", choices=("mixed", "read-random"), default="mixed")
    parser.add_argument("--output", type=Path, default=Path("traces/phase2_random.trace"))
    args = parser.parse_args()
    if args.count <= 0:
        parser.error("count must be positive")

    rng = random.Random(args.seed)
    previous = 0
    lines = [f"# Generated with seed={args.seed}, count={args.count}."]
    for index in range(args.count):
        if args.mode == "read-random":
            address = rng.randrange(4096 // 4) * 4
        else:
            choice = rng.random()
            if choice < 0.30:
                address = previous
            elif choice < 0.55:
                address = (previous & ~0xF) | (rng.randrange(4) * 4)
            elif choice < 0.75:
                address = rng.choice((0x000, 0x400)) + rng.randrange(4) * 4
            else:
                address = rng.randrange(4096 // 4) * 4
        previous = address
        if args.mode == "mixed" and rng.random() < 0.30:
            lines.append(f"W 0x{address:08X} 0x{rng.getrandbits(32):08X}")
        else:
            lines.append(f"R 0x{address:08X}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
