#!/usr/bin/env python3
"""Put the shared header and palette on the hand-written pages.

erd.html and dashboard.html get it from their generators. index.html and
design_spec.html are written by hand, so this applies the same thing to
them: drop their private palettes, link site.css, insert the topbar.
Safe to run again - it reports pages that already carry the header.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(HERE, "tools"))
import site_chrome  # noqa: E402

TARGETS = {
    "index.html": ('<div class="wrap">\n', "index.html"),
    "design_spec.html": ('<div class="page">\n', "design_spec.html"),
}


def strip_palette(css):
    """Remove the page's own tokens and theme block; site.css owns both."""
    css = re.sub(r'\s*:root\s*\{[^}]*\}', '', css, count=1)
    css = re.sub(r'\s*@media\s*\(prefers-color-scheme:\s*dark\)\s*\{'
                 r'(?:[^{}]|\{[^{}]*\})*\}', '', css, count=1)
    css = re.sub(r'\s*:root\[data-theme="dark"\]\s*\{[^}]*\}', '', css,
                 count=1)
    # the shared sheet sets these; a second copy only fights it
    css = re.sub(r'\n\s*body\s*\{[^}]*\}', '', css, count=1)
    css = re.sub(r'\n\s*\*\s*\{\s*box-sizing:[^}]*\}', '', css, count=1)
    return css


def main():
    for name, (anchor, current) in TARGETS.items():
        path = os.path.join(HERE, "docs", name)
        s = open(path).read()
        if 'class="topbar"' in s:
            print(f"  {name}: already has the shared header")
            continue
        head_end = s.index("</head>")
        style_start, style_end = s.index("<style>"), s.index("</style>")
        css = strip_palette(s[style_start + 7:style_end])
        s = (s[:style_start] + site_chrome.HEAD + "\n<style>" + css
             + s[style_end:])
        # the nav added before the shared header existed
        s = re.sub(r'\s*<nav class="sitenav">.*?</nav>\n', '\n', s,
                   flags=re.S)
        s = re.sub(r'\s*\.sitenav[^\n]*\{(?:[^{}]|\{[^{}]*\})*?\}\n', '\n', s)
        s = re.sub(r'\s*@media print \{ \.sitenav \{ display:none; \} \}\n',
                   '\n', s)
        anchor_at = s.index(anchor) + len(anchor)
        s = s[:anchor_at - len(anchor)] + site_chrome.topbar(current) \
            + s[anchor_at - len(anchor):]
        s = s.replace("</body>", site_chrome.FOOT + "\n</body>", 1)
        open(path, "w").write(s)
        print(f"  {name}: shared header applied")


if __name__ == "__main__":
    main()
