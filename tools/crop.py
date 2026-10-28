#!/usr/bin/env python3
"""crop.py - trim the empty terminal space off the bottom of the figures.

screenshots_full/ keeps the untouched full-display captures. This writes
screenshots/, which is what build.py places in the document.

The terminal figures end with a lot of empty black: the output is 20-45
lines and the maximised panel is far taller than that. Scaled to 6.5 in
in the report, that empty half makes the text half as big as it needs to
be, and WORKFLOW step 7 is explicit that an unreadable figure has to be
cropped. Nothing is added, moved or scaled - the only thing removed is
background below the last row of text, so the menu bar with the clock,
the window chrome, the sidebar, the tabs and the whole of the output are
all still in frame.

The editor figures are full top to bottom and are copied through as they
are.
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "screenshots_full")
DST = os.path.join(HERE, "screenshots")

PANE_TOP, PANE_BOT = 200, 2570   # above the status bar, below the title bar
PANE_L, PANE_R = 760, 4050       # right of the sidebar
MARGIN = 60                      # black left under the last line of text
MIN_KEEP = 1200                  # never crop a figure shorter than this


def content_bottom(path):
    """y of the last row in the pane that has anything drawn on it."""
    a = np.array(Image.open(path).convert("L"))
    pane = a[PANE_TOP:PANE_BOT, PANE_L:PANE_R]
    rows = np.where(pane.std(axis=1) > 3)[0]
    return (int(rows.max()) + PANE_TOP) if len(rows) else PANE_BOT


def main():
    os.makedirs(DST, exist_ok=True)
    figs = sorted(
        (f for f in os.listdir(SRC) if f.startswith("fig") and f.endswith(".png")),
        key=lambda f: int(f.split("_")[0][3:]),
    )
    if not figs:
        sys.exit("no figures in %s" % SRC)

    for name in figs:
        src = os.path.join(SRC, name)
        dst = os.path.join(DST, name)
        im = Image.open(src)
        bottom = content_bottom(src)
        keep = max(MIN_KEEP, min(im.height, bottom + MARGIN))
        if keep >= im.height - MARGIN:
            shutil.copy2(src, dst)
            print("  %-28s full frame, copied as is (%dx%d)" % (name, im.width, im.height))
        else:
            im.crop((0, 0, im.width, keep)).save(dst)
            print("  %-28s %dx%d -> %dx%d  (%d empty rows trimmed)"
                  % (name, im.width, im.height, im.width, keep, im.height - keep))


if __name__ == "__main__":
    main()
