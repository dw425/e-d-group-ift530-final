#!/usr/bin/env python3
"""The header every published page shares.

One definition of the navigation bar, the theme toggle and the no-flash
theme snippet, imported by the page generators and applied to the static
pages by tools/apply_chrome.py, so the four pages cannot drift apart.
"""

PAGES = [("index.html", "Home"), ("erd.html", "ERD"),
         ("dashboard.html", "Dashboard"), ("design_spec.html", "Design spec")]

# Runs before first paint: without it the page flashes the wrong theme.
HEAD = """<link rel="stylesheet" href="site.css">
<script>try{var t=localStorage.getItem('edg-theme')||(window.matchMedia\
&&window.matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light');\
document.documentElement.setAttribute('data-theme',t);}catch(e){}</script>"""

FOOT = '<script src="site.js"></script>'

_SUN = ('<svg class="i-sun" viewBox="0 0 24 24" fill="none" '
        'stroke="currentColor" stroke-width="2" stroke-linecap="round">'
        '<circle cx="12" cy="12" r="4.2"/><path d="M12 2.6v2.2M12 19.2v2.2'
        'M2.6 12h2.2M19.2 12h2.2M5.1 5.1l1.6 1.6M17.3 17.3l1.6 1.6'
        'M18.9 5.1l-1.6 1.6M6.7 17.3l-1.6 1.6"/></svg>')
_MOON = ('<svg class="i-moon" viewBox="0 0 24 24" fill="none" '
         'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
         'stroke-linejoin="round"><path d="M20.5 14.3A8.5 8.5 0 1 1 9.7 3.5'
         'a6.8 6.8 0 0 0 10.8 10.8z"/></svg>')


def topbar(current):
    """The sticky header. `current` is the page's own filename."""
    links = "".join(
        '      <a%s href="%s">%s</a>\n'
        % (' class="on"' if href == current else "", href, label)
        for href, label in PAGES)
    return (
        '<div class="topbar">\n'
        '  <div class="topbar-in">\n'
        '    <a class="brand" href="index.html">'
        '<span class="mark"></span>E &amp; D Group</a>\n'
        '    <nav class="sitenav">\n' + links +
        '    </nav>\n'
        '    <button class="themetoggle" type="button" '
        'aria-label="Switch theme">' + _SUN + _MOON + '</button>\n'
        '  </div>\n'
        '</div>\n')
