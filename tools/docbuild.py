"""
docbuild — build an APA 7 assignment paper in Word format.

The formatting is not invented here. It is lifted from templates/apa7_template.docx
(originally IFT533_DWarren_Assignment2.1) so every paper in this repo comes out
looking like the ones already turned in: Times New Roman 12 pt, double spaced,
1 in margins, a page-number header, and a centered title block.

The template's body is stripped and rebuilt; only its section properties survive,
which is what carries the header and the margins.

Usage:

    from docbuild import Paper

    p = Paper(out="IFT530_DWarren_Assignment_CreatingTables.docx")
    p.title_page("Assignment: Creating Tables",
                 course="IFT 530: Advanced Database Management Systems (Fall C 2026)",
                 instructor="Ashish Gulati",
                 date="September 2, 2026")
    p.h1("Setting Up SQL Server Locally")
    p.body("Microsoft does not ship a native macOS build ...")
    p.figure("screenshots/fig1_version.png", "Figure 1. The container running locally.")
    p.code(open("01_create_tables.sql").read())
    p.save()
"""

from __future__ import annotations

import re
import shutil
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor

REPO = Path(__file__).resolve().parent.parent
DEFAULT_TEMPLATE = REPO / "templates" / "apa7_template.docx"

BODY_FONT = "Times New Roman"
CODE_FONT = "Courier New"
BODY_SIZE = 12
CODE_SIZE = 9

AUTHOR = "Daniel Warren"
SCHOOL = "Arizona State University"


# --------------------------------------------------------------------------
# low-level xml helpers
# --------------------------------------------------------------------------
def _strip_body(doc):
    """Remove every block-level element except the trailing sectPr."""
    body = doc.element.body
    for child in list(body):
        if child.tag != qn("w:sectPr"):
            body.remove(child)


def _strip_orphan_media(doc):
    """Drop images the template carried that this document never shows.

    templates/apa7_template.docx was cloned from IFT533 Assignment 2.1, and it
    still contains that assignment's four charts. Stripping the body removes the
    paragraphs that displayed them but not the image parts themselves, so every
    document built from the template shipped ~160 KB of another course's
    figures inside the .docx - invisible when opened, obvious to anyone who
    unzipped it.
    """
    part = doc.part
    used = set(re.findall(r'r:(?:id|embed)="([^"]+)"', part.element.xml))
    for r_id, rel in list(part.rels.items()):
        if "image" in rel.reltype and r_id not in used:
            part.drop_rel(r_id)

def _style_run(run, font=BODY_FONT, size=BODY_SIZE, bold=False, italic=False,
               color=None):
    run.bold = bold
    if color:
        run.font.color.rgb = RGBColor.from_string(color)
    run.italic = italic
    run.font.size = Pt(size)
    run.font.name = font
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = rpr.makeelement(qn("w:rFonts"), {})
        rpr.insert(0, rfonts)
    for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
        rfonts.set(qn(attr), font)
    return run


def _repeat_header_row(row):
    """Mark a header row to repeat when the table breaks across pages.

    Without this a long table continues onto the next page with no headers,
    which is how Table 5 in the M-4 lab first came out.
    """
    tr_pr = row._tr.get_or_add_trPr()
    el = tr_pr.makeelement(qn("w:tblHeader"), {})
    el.set(qn("w:val"), "true")
    tr_pr.append(el)


def _no_row_split(row):
    """Stop a row being broken across a page boundary.

    Without this, a tall row splits and the overflow lands under a repeated
    header on the next page - which is how Table 8 of the M-4 weather lab came
    out, a header row followed by the single word "node". Trimming the text
    only changes which word spills; cantSplit fixes the class of problem.
    """
    tr_pr = row._tr.get_or_add_trPr()
    tr_pr.append(tr_pr.makeelement(qn("w:cantSplit"), {}))

def _set_table_borders(table, color="000000"):
    """The template carries no 'Table Grid' style, so draw the borders directly."""
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.makeelement(qn("w:tblBorders"), {})
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        el = borders.makeelement(qn(f"w:{edge}"), {})
        el.set(qn("w:val"), "single")
        el.set(qn("w:sz"), "4")
        el.set(qn("w:color"), color)
        borders.append(el)
    tbl_pr.append(borders)


# A shaded table reads as three bands: a dark header with white type, and
# body rows alternating white against a pale grey. Anything heavier fights
# the text; anything lighter does not survive a greyscale print.
SHADE = {
    "blue": dict(header="1F3864", band="E8EDF5", alt="FFFFFF",
                 header_text="FFFFFF", border="8EA9DB"),
    "grey": dict(header="404040", band="F2F2F2", alt="FFFFFF",
                 header_text="FFFFFF", border="BFBFBF"),
}


def _shade_cell(cell, hex_fill):
    """Fill one cell. python-docx has no API for this; write the w:shd."""
    tc_pr = cell._tc.get_or_add_tcPr()
    for old in tc_pr.findall(qn("w:shd")):
        tc_pr.remove(old)
    shd = tc_pr.makeelement(qn("w:shd"), {})
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_fill)
    tc_pr.append(shd)


def _fix_column_widths(table, widths):
    """Pin the column widths so a narrow column stays narrow.

    Setting cell.width alone is not enough. Word and LibreOffice both lay a
    table out from its tblGrid unless tblLayout is "fixed", so a 0.4 in column
    that python-docx wrote onto every cell still came out a sixth of the page
    wide - which is how the step-number column in the M-4 IoT tables first
    rendered. Writing the grid and the layout type fixes it.
    """
    tbl = table._tbl
    tbl_pr = tbl.tblPr

    layout = tbl_pr.makeelement(qn("w:tblLayout"), {})
    layout.set(qn("w:type"), "fixed")
    tbl_pr.append(layout)

    grid = tbl.find(qn("w:tblGrid"))
    if grid is not None:
        tbl.remove(grid)
    grid = tbl.makeelement(qn("w:tblGrid"), {})
    for w in widths:
        col = grid.makeelement(qn("w:gridCol"), {})
        col.set(qn("w:w"), str(int(w.twips)))
        grid.append(col)
    tbl.insert(list(tbl).index(tbl_pr) + 1, grid)


class Paper:
    """An APA 7 paper cloned from the template."""

    def __init__(self, out, template=DEFAULT_TEMPLATE, base=None):
        self.out = Path(out)
        self.base = Path(base) if base else self.out.parent
        shutil.copy(template, self.out)
        self.doc = Document(self.out)
        _strip_body(self.doc)
        _strip_orphan_media(self.doc)
        self._figures = 0
        self._tables = 0

    # ---------------------------------------------------------- primitives
    def _para(self, text="", *, align=None, bold=False, italic=False,
              first_line=None, before=0, after=0, line=2.0,
              font=BODY_FONT, size=BODY_SIZE, keep_with_next=False):
        p = self.doc.add_paragraph()
        pf = p.paragraph_format
        pf.space_before = Pt(before)
        pf.space_after = Pt(after)
        pf.line_spacing = line
        if first_line is not None:
            pf.first_line_indent = Inches(first_line)
        if align is not None:
            p.alignment = align
        if keep_with_next:
            pf.keep_with_next = True
        if text:
            _style_run(p.add_run(text), font=font, size=size, bold=bold, italic=italic)
        return p

    # ------------------------------------------------------------- content
    def title_page(self, title, course, instructor, date,
                   author=AUTHOR, school=SCHOOL):
        """Centered APA title block, a page break, then the running title."""
        self.title = title
        for _ in range(4):
            self._para()
        self._para(title, align=WD_ALIGN_PARAGRAPH.CENTER, bold=True)
        for line in (author, school, course, instructor, date):
            self._para(line, align=WD_ALIGN_PARAGRAPH.CENTER)
        self.page_break()
        self._para(title, align=WD_ALIGN_PARAGRAPH.CENTER, bold=True)

    def page_break(self):
        """A hard page break on its own paragraph."""
        p = self.doc.add_paragraph()
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.line_spacing = 2.0
        p.add_run().add_break(WD_BREAK.PAGE)
        return p

    def body(self, text, line=2.0, first_line=0.5, after=0):
        """Indented, double-spaced body paragraph.

        `line`, `first_line` and `after` are overridable for the occasional
        assignment that is not asked for in APA form and reads better plain:
        no indent, single spaced, blank line between paragraphs.
        """
        return self._para(text, align=WD_ALIGN_PARAGRAPH.LEFT,
                          first_line=first_line, line=line, after=after)

    def plain_heading(self, lines):
        """A simple name/course/date block for non-APA submissions."""
        for i, text in enumerate(lines):
            self._para(text, align=WD_ALIGN_PARAGRAPH.LEFT, line=1.0,
                       bold=(i == 0), after=2)
        self._para("", line=1.0, after=6)

    def h1(self, text):
        """APA Level 1: bold, flush left."""
        return self._para(text, align=WD_ALIGN_PARAGRAPH.LEFT, bold=True,
                          before=12, keep_with_next=True)

    def h2(self, text):
        """APA Level 2: bold italic, flush left."""
        return self._para(text, align=WD_ALIGN_PARAGRAPH.LEFT, bold=True,
                          italic=True, before=6, keep_with_next=True)

    def figure(self, image, caption, width=6.5):
        """Centered image with an italic centered caption. Numbers itself."""
        self._figures += 1
        path = Path(image)
        if not path.is_absolute():
            path = self.base / path
        p = self._para(align=WD_ALIGN_PARAGRAPH.CENTER, before=6, after=3,
                       line=1.0, keep_with_next=True)
        p.add_run().add_picture(str(path), width=Inches(width))
        return self._para(f"Figure {self._figures}. {caption}",
                          align=WD_ALIGN_PARAGRAPH.CENTER, italic=True,
                          after=10, line=1.0)

    def code(self, text, size=CODE_SIZE, keep=False):
        """Monospaced, single-spaced listing. Pass a whole file's text.

        keep=True holds a short snippet on one page. Leave it off for whole
        files, which have to be allowed to break across pages."""
        lines = text.rstrip("\n").split("\n")
        for i, line in enumerate(lines):
            self._para(line or " ", align=WD_ALIGN_PARAGRAPH.LEFT, line=1.0,
                       font=CODE_FONT, size=size,
                       keep_with_next=keep and i < len(lines) - 1)

    def code_file(self, path, size=CODE_SIZE):
        p = Path(path)
        if not p.is_absolute():
            p = self.base / p
        self.code(p.read_text(), size=size)

    def table(self, caption, headers, rows, widths=None, size=10,
              shade=None):
        """Bordered APA table with an italic 'Table N' label above it.

        shade="blue" or "grey" fills the header row and bands the body.
        Left off, the table renders exactly as it always has, so no
        existing assignment changes.
        """
        self._tables += 1
        # keep_with_next on both, or a page break lands between the "Table N"
        # label and its caption - which is how Table 4 of the M-4 IoT
        # assignment first came out, label alone at the foot of a page.
        self._para(f"Table {self._tables}", align=WD_ALIGN_PARAGRAPH.LEFT,
                   italic=True, before=6, line=1.0, keep_with_next=True)
        self._para(caption, align=WD_ALIGN_PARAGRAPH.LEFT, after=6, line=1.0,
                   keep_with_next=True)
        pal = SHADE.get(shade) if shade else None
        t = self.doc.add_table(rows=1, cols=len(headers))
        _set_table_borders(t, color=pal["border"] if pal else "000000")
        if widths:
            t.autofit = False
            widths = [Inches(w) for w in widths]
            _fix_column_widths(t, widths)

        def fill(cell, value, bold=False, width=None, color=None, bg=None):
            cell.paragraphs[0].text = ""
            _style_run(cell.paragraphs[0].add_run(value), bold=bold, size=size,
                       color=color)
            if bg:
                _shade_cell(cell, bg)
            cell.paragraphs[0].paragraph_format.line_spacing = 1.0
            cell.paragraphs[0].paragraph_format.space_after = Pt(0)
            if width is not None:
                cell.width = width

        for i, (cell, label) in enumerate(zip(t.rows[0].cells, headers)):
            fill(cell, label, bold=True, width=widths[i] if widths else None,
                 color=pal["header_text"] if pal else None,
                 bg=pal["header"] if pal else None)
        _repeat_header_row(t.rows[0])
        _no_row_split(t.rows[0])
        for n, r in enumerate(rows):
            row = t.add_row()
            _no_row_split(row)
            bg = None
            if pal:
                bg = pal["band"] if n % 2 == 0 else pal["alt"]
            for i, (cell, val) in enumerate(zip(row.cells, r)):
                fill(cell, val, width=widths[i] if widths else None, bg=bg)
        self._para("", after=6, line=1.0)
        return t

    def references(self, entries, heading="References"):
        """APA reference list: new page, centered bold heading, hanging indents.

        Entries are written in the order given, so alphabetize them in the
        caller where APA wants them alphabetized.

        The new page comes from page_break_before on the heading rather than
        from page_break(). A break paragraph is itself a paragraph, so when the
        body happens to end exactly at the page boundary that empty paragraph
        lands on the next page and the break pushes the references one further,
        leaving a blank page behind. Setting the property on the heading has no
        such paragraph to strand.
        """
        h = self._para(heading, align=WD_ALIGN_PARAGRAPH.CENTER, bold=True)
        h.paragraph_format.page_break_before = True
        for entry in entries:
            p = self._para(entry, align=WD_ALIGN_PARAGRAPH.LEFT)
            p.paragraph_format.left_indent = Inches(0.5)
            p.paragraph_format.first_line_indent = Inches(-0.5)
        return self

    def save(self):
        self.doc.save(self.out)
        print("wrote", self.out)
        return self.out
