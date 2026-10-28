#!/usr/bin/env python3
"""Concatenate parts/*.sql into the single submitted script.

The assignment wants one combined file. Keeping it in numbered parts while
it is being written makes it reviewable; this joins them in order and
writes both the .sql and the byte-identical .txt twin Canvas accepts.

    python3 tools/assemble.py           # all parts
    python3 tools/assemble.py 00 10 20  # just those, to /tmp, for testing
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PARTS = HERE.parent / "parts"
NAME = "IFT530_EDGroup_FinalProject"


def main():
    wanted = sys.argv[1:]
    files = sorted(PARTS.glob("*.sql"))
    if wanted:
        files = [f for f in files if f.name.split("_")[0] in wanted]
    # Every part carries the required IFT 530 header block, so each one
    # stands on its own when read in the repository. The combined file
    # must carry exactly one, so it is stripped from all but the first.
    chunks = []
    for i, f in enumerate(files):
        body = f.read_text()
        if i and body.startswith("/*\n** Author:"):
            body = body[body.index("*/\n") + 3:]
        chunks.append(body.rstrip("\n"))
    text = "\n".join(chunks) + "\n"

    if wanted:
        out = Path("/tmp/partial_ift530.sql")
        out.write_text(text)
        print(f"wrote {out} from {len(files)} parts")
        return

    sql = HERE.parent / f"{NAME}.sql"
    txt = HERE.parent / f"{NAME}.txt"
    sql.write_text(text)
    txt.write_text(text)
    lines = text.count("\n")
    over = [n for n, l in enumerate(text.split("\n"), 1) if len(l) > 86]
    print(f"wrote {sql.name} and {txt.name}: {len(files)} parts, {lines} lines")
    if over:
        print(f"  WARNING: {len(over)} line(s) over 86 chars: {over[:5]}")


if __name__ == "__main__":
    main()
