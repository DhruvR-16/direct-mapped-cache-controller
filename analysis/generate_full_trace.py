#!/usr/bin/env python3
"""Build one deterministic trace covering the complete cache controller."""

import argparse
from pathlib import Path


TRACE_DIR = Path(__file__).resolve().parents[1] / "traces"


def read_operations(path: Path):
    return [line.strip() for line in path.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=TRACE_DIR / "full_project.trace")
    args = parser.parse_args()

    lines = ["# One continuous run: locality, conflicts, random reads, writes, and reset checks."]
    lines += ["# Sequential words across four blocks."]
    lines += [f"R 0x{word * 4:08X}" for word in range(16)]
    lines += ["# Repeated address shows temporal locality."]
    lines += ["R 0x00000080"] * 16
    lines += ["# Prime line zero, then alternate conflicting blocks.", "R 0x00000400"]
    lines += [f"R 0x{0x400 if i % 2 else 0:08X}" for i in range(16)]
    for label, filename in (
        ("Uniform random reads", "random_read.trace"),
        ("Mixed reads and writes", "phase2_random.trace"),
        ("Directed hits, misses, and writes", "phase2_smoke.trace"),
    ):
        lines.append(f"# {label}.")
        lines.extend(read_operations(TRACE_DIR / filename))
    # The post-trace reset/backpressure checks expect these known memory words.
    lines += ["# Set known values for post-reset and stalled-write checks.",
              "W 0x00000008 0x12345678",
              "W 0x00000400 0xDEADBEEF",
              "W 0x0000000C 0xA5000003"]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n")
    print(f"Generated {sum(line.startswith(('R ', 'W ')) for line in lines)} accesses in {args.output}")


if __name__ == "__main__":
    main()
