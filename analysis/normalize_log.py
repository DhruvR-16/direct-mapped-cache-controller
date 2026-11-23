#!/usr/bin/env python3
"""Remove tool-generated trailing whitespace from saved text logs."""

import sys
from pathlib import Path


for name in sys.argv[1:]:
    path = Path(name)
    path.write_text("\n".join(line.rstrip() for line in path.read_text().splitlines()) + "\n")
