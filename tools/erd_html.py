#!/usr/bin/env python3
"""
Generates docs/erd.html - a standalone ERD for the E & D Group schema.

Geometry is computed here rather than hand-typed so a column added to a
table moves its box and every connector that lands on it. Column lists
mirror parts/30_tables.sql; if that file changes, change this one.
"""

import html
import os

BOX_W    = 280
ROW_H    = 18
HEADER_H = 30
PAD_B    = 8
GAP_Y    = 40
COL_X    = [40, 380, 720]

# kind: pk, fk, pkfk, dd (degenerate dimension), plain
# Each column is (name, type, kind, nullable)
TABLES = {
    "DimGeography": dict(col=0, kind="dim", rows=10, note="role-playing", cols=[
        ("GeoID",       "INT",          "pk",    False),
        ("CountryCode", "CHAR(2)",      "plain", False),
        ("CountryName", "VARCHAR(60)",  "plain", False),
        ("Region",      "VARCHAR(40)",  "plain", False),
        ("City",        "VARCHAR(60)",  "plain", False),
        ("Latitude",    "DECIMAL(9,6)", "plain", False),
        ("Longitude",   "DECIMAL(9,6)", "plain", False),
        ("RiskTier",    "VARCHAR(10)",  "plain", False),
    ]),
    "DimCampaign": dict(col=0, kind="dim", rows=10, note="", cols=[
        ("CampaignID",   "INT",           "pk",    False),
        ("CampaignName", "VARCHAR(60)",   "plain", False),
        ("Channel",      "VARCHAR(30)",   "plain", False),
        ("CostModel",    "VARCHAR(10)",   "plain", False),
        ("StartDate",    "DATE",          "plain", False),
        ("EndDate",      "DATE",          "plain", True),
        ("BudgetUSD",    "DECIMAL(10,2)", "plain", False),
    ]),
    "DimProduct": dict(col=0, kind="dim", rows=10, note="", cols=[
        ("ProductID",       "INT",          "pk",    False),
        ("ProductName",     "VARCHAR(60)",  "plain", False),
        ("ProductCategory", "VARCHAR(20)",  "plain", False),
        ("ListPriceUSD",    "DECIMAL(6,2)", "plain", False),
        ("IsActive",        "BIT",          "plain", False),
        ("ReleaseDate",     "DATE",         "plain", False),
    ]),
    "DimPlan": dict(col=0, kind="dim", rows=10, note="audited", cols=[
        ("PlanID",        "INT",          "pk",    False),
        ("PlanName",      "VARCHAR(30)",  "plain", False),
        ("PriceUSD",      "DECIMAL(6,2)", "plain", False),
        ("BillingPeriod", "VARCHAR(10)",  "plain", False),
        ("IsPaid",        "BIT",          "plain", False),
        ("TrialDays",     "INT",          "plain", False),
        ("AdsEnabled",    "BIT",          "plain", False),
        ("EffectiveDate", "DATE",         "plain", False),
    ]),
    "DimUser": dict(col=1, kind="dim", rows=10, note="", cols=[
        ("UserID",          "INT",          "pk",    False),
        ("Username",        "VARCHAR(30)",  "plain", False),
        ("Email",           "VARCHAR(100)", "plain", False),
        ("SignupDate",      "DATE",         "plain", False),
        ("RegisteredGeoID", "INT",          "fk",    False),
        ("LastSeenGeoID",   "INT",          "fk",    True),
        ("LastSeenAt",      "DATETIME2",    "plain", True),
        ("AgeBand",         "VARCHAR(10)",  "plain", False),
        ("PreferredDevice", "VARCHAR(20)",  "plain", False),
        ("LifecycleStage",  "VARCHAR(12)",  "plain", False),
        ("AcqCampaignID",   "INT",          "fk",    True),
        ("AcqCostUSD",      "DECIMAL(8,2)", "plain", True),
    ]),
    "DimAccount": dict(col=1, kind="dim", rows=10, note="", cols=[
        ("AccountID",     "INT",         "pk",    False),
        ("UserID",        "INT",         "fk",    False),
        ("AccountNumber", "VARCHAR(20)", "plain", False),
        ("PlanID",        "INT",         "fk",    False),
        ("AccountStatus", "VARCHAR(12)", "plain", False),
        ("OpenedDate",    "DATE",        "plain", False),
        ("ClosedDate",    "DATE",        "plain", True),
        ("IsAutoRenew",   "BIT",         "plain", False),
        ("BillingGeoID",  "INT",         "fk",    False),
    ]),
    "DimPlanAudit": dict(col=1, kind="audit", rows=0, note="no FK to DimPlan, by design", cols=[
        ("AuditID",     "INT",          "pk",    False),
        ("PlanID",      "INT",          "plain", False),
        ("ChangeType",  "VARCHAR(6)",   "plain", False),
        ("OldPlanName", "VARCHAR(30)",  "plain", True),
        ("NewPlanName", "VARCHAR(30)",  "plain", True),
        ("OldPriceUSD", "DECIMAL(6,2)", "plain", True),
        ("NewPriceUSD", "DECIMAL(6,2)", "plain", True),
        ("OldIsPaid",   "BIT",          "plain", True),
        ("NewIsPaid",   "BIT",          "plain", True),
        ("ChangedBy",   "VARCHAR(128)", "plain", False),
        ("ChangedAt",   "DATETIME2",    "plain", False),
    ]),
    "FactUserEvent": dict(col=2, kind="fact", rows=48, note="grain: one player action", cols=[
        ("EventID",      "INT IDENTITY", "pk",    False),
        ("UserID",       "INT",          "fk",    False),
        ("SessionID",    "INT",          "dd",    False),
        ("GeoID",        "INT",          "fk",    False),
        ("EventType",    "VARCHAR(20)",  "plain", False),
        ("EventTS",      "DATETIME2",    "plain", False),
        ("LevelNumber",  "INT",          "plain", True),
        ("Outcome",      "VARCHAR(10)",  "plain", True),
        ("DeviceType",   "VARCHAR(20)",  "plain", False),
        ("SourceSystem", "VARCHAR(30)",  "plain", False),
    ]),
    "FactPayment": dict(col=2, kind="fact", rows=30, note="grain: one transaction", cols=[
        ("PaymentID",     "INT IDENTITY", "pk",    False),
        ("AccountID",     "INT",          "fk",    False),
        ("ProductID",     "INT",          "fk",    True),
        ("CampaignID",    "INT",          "fk",    True),
        ("GeoID",         "INT",          "fk",    False),
        ("PaymentTS",     "DATETIME2",    "plain", False),
        ("AmountUSD",     "DECIMAL(8,2)", "plain", False),
        ("PaymentType",   "VARCHAR(12)",  "plain", False),
        ("PaymentMethod", "VARCHAR(20)",  "plain", False),
        ("IsFlagged",     "BIT",          "plain", False),
        ("SourceSystem",  "VARCHAR(30)",  "plain", False),
    ]),
    "FactSubscription": dict(col=2, kind="fact", rows=23, note="grain: one lifecycle change", cols=[
        ("SubEventID",   "INT IDENTITY", "pk",    False),
        ("AccountID",    "INT",          "fk",    False),
        ("PlanID",       "INT",          "fk",    False),
        ("PrevPlanID",   "INT",          "fk",    True),
        ("EventType",    "VARCHAR(12)",  "plain", False),
        ("EventDate",    "DATE",         "plain", False),
        ("MRRDeltaUSD",  "DECIMAL(8,2)", "plain", False),
        ("TermMonths",   "INT",          "plain", True),
        ("CancelReason", "VARCHAR(40)",  "plain", True),
        ("SourceSystem", "VARCHAR(30)",  "plain", False),
    ]),
}

# Stacking order within each column
ORDER = [
    ["DimGeography", "DimCampaign", "DimProduct", "DimPlan"],
    ["DimUser", "DimAccount", "DimPlanAudit"],
    ["FactUserEvent", "FactPayment", "FactSubscription"],
]

# (constraint, child table, child column, parent table, parent column)
FKS = [
    ("FK_User_RegGeo",      "DimUser",          "RegisteredGeoID", "DimGeography", "GeoID"),
    ("FK_User_LastGeo",     "DimUser",          "LastSeenGeoID",   "DimGeography", "GeoID"),
    ("FK_User_Campaign",    "DimUser",          "AcqCampaignID",   "DimCampaign",  "CampaignID"),
    ("FK_Account_User",     "DimAccount",       "UserID",          "DimUser",      "UserID"),
    ("FK_Account_Plan",     "DimAccount",       "PlanID",          "DimPlan",      "PlanID"),
    ("FK_Account_BillGeo",  "DimAccount",       "BillingGeoID",    "DimGeography", "GeoID"),
    ("FK_Event_User",       "FactUserEvent",    "UserID",          "DimUser",      "UserID"),
    ("FK_Event_Geo",        "FactUserEvent",    "GeoID",           "DimGeography", "GeoID"),
    ("FK_Payment_Account",  "FactPayment",      "AccountID",       "DimAccount",   "AccountID"),
    ("FK_Payment_Product",  "FactPayment",      "ProductID",       "DimProduct",   "ProductID"),
    ("FK_Payment_Campaign", "FactPayment",      "CampaignID",      "DimCampaign",  "CampaignID"),
    ("FK_Payment_Geo",      "FactPayment",      "GeoID",           "DimGeography", "GeoID"),
    ("FK_Sub_Account",      "FactSubscription", "AccountID",       "DimAccount",   "AccountID"),
    ("FK_Sub_Plan",         "FactSubscription", "PlanID",          "DimPlan",      "PlanID"),
    ("FK_Sub_PrevPlan",     "FactSubscription", "PrevPlanID",      "DimPlan",      "PlanID"),
]

COLORS = {
    "DimGeography": "#0d9488",
    "DimCampaign":  "#c2410c",
    "DimProduct":   "#7c3aed",
    "DimPlan":      "#be185d",
    "DimUser":      "#1d4ed8",
    "DimAccount":   "#15803d",
}

FILL = {"dim": "#ffffff", "fact": "#ffffff", "audit": "#ffffff"}
HEAD = {"dim": "#1e3a5f", "fact": "#7c2d12", "audit": "#44403c"}


def layout():
    """Assign every table an (x, y, w, h). Returns the canvas size too."""
    for ci, names in enumerate(ORDER):
        y = 50
        for name in names:
            t = TABLES[name]
            t["w"] = BOX_W
            t["h"] = HEADER_H + ROW_H * len(t["cols"]) + PAD_B
            t["x"] = COL_X[ci]
            t["y"] = y
            y += t["h"] + GAP_Y
    w = COL_X[-1] + BOX_W + 40
    h = max(t["y"] + t["h"] for t in TABLES.values()) + 40
    return w, h


def row_y(table, column):
    t = TABLES[table]
    idx = [c[0] for c in t["cols"]].index(column)
    return t["y"] + HEADER_H + idx * ROW_H + ROW_H / 2


def connector(child, ccol, parent, pcol):
    """Bezier from the parent's key row to the child's FK row."""
    p, c = TABLES[parent], TABLES[child]
    py, cy = row_y(parent, pcol), row_y(child, ccol)

    if p["x"] < c["x"]:                      # normal left-to-right
        x1, x2 = p["x"] + p["w"], c["x"]
        dx = max(60, (x2 - x1) * 0.5)
        return f"M{x1},{py} C{x1+dx},{py} {x2-dx},{cy} {x2},{cy}", (x1, py), (x2, cy)

    # same column - loop out to the left of both boxes
    x1, x2 = p["x"], c["x"]
    out = 46
    return (f"M{x1},{py} C{x1-out},{py} {x2-out},{cy} {x2},{cy}",
            (x1, py), (x2, cy))


def esc(s):
    return html.escape(str(s))


def table_svg(name):
    t = TABLES[name]
    x, y, w, h = t["x"], t["y"], t["w"], t["h"]
    head = HEAD[t["kind"]]
    label = {"dim": "DIMENSION", "fact": "FACT", "audit": "AUDIT"}[t["kind"]]
    rows = f"{t['rows']:,} rows" if t["rows"] else "written by trigger"

    out = [f'<g class="tbl" data-table="{esc(name)}">']
    out.append(f'<rect class="shadow" x="{x+2}" y="{y+3}" width="{w}" height="{h}" rx="7"/>')
    out.append(f'<rect class="box" x="{x}" y="{y}" width="{w}" height="{h}" rx="7" '
               f'fill="{FILL[t["kind"]]}"/>')
    out.append(f'<path class="hd" d="M{x},{y+7} a7,7 0 0 1 7,-7 h{w-14} a7,7 0 0 1 7,7 '
               f'v{HEADER_H-7} h{-w} z" fill="{head}"/>')
    out.append(f'<text class="tname" x="{x+10}" y="{y+20}">{esc(name)}</text>')
    out.append(f'<text class="tkind" x="{x+w-10}" y="{y+20}" text-anchor="end">{label}</text>')

    for i, (cname, ctype, kind, nullable) in enumerate(t["cols"]):
        ry = y + HEADER_H + i * ROW_H
        if i % 2:
            out.append(f'<rect class="zebra" x="{x+1}" y="{ry}" width="{w-2}" height="{ROW_H}"/>')
        badge = {"pk": "PK", "fk": "FK", "dd": "DD"}.get(kind, "")
        if badge:
            out.append(f'<text class="badge b-{kind}" x="{x+10}" y="{ry+13}">{badge}</text>')
        cls = "col pk" if kind == "pk" else "col"
        out.append(f'<text class="{cls}" x="{x+36}" y="{ry+13}">{esc(cname)}</text>')
        tcls = "typ null" if nullable else "typ"
        out.append(f'<text class="{tcls}" x="{x+w-10}" y="{ry+13}" '
                   f'text-anchor="end">{esc(ctype)}</text>')

    out.append(f'<text class="rowcount" x="{x+10}" y="{y+h-1}">{rows}'
               + (f' &#183; {esc(t["note"])}' if t["note"] else '') + '</text>')
    out.append('</g>')
    return "\n".join(out)


def build():
    w, h = layout()
    parts = []

    # marker defs, one pair per parent color
    defs = ['<defs>']
    for parent, color in COLORS.items():
        key = parent.lower()
        defs.append(
            f'<marker id="crow-{key}" viewBox="0 0 12 12" refX="11" refY="6" '
            f'markerWidth="11" markerHeight="11" orient="auto">'
            f'<path d="M1,6 L11,1 M1,6 L11,6 M1,6 L11,11" fill="none" '
            f'stroke="{color}" stroke-width="1.4"/></marker>')
        defs.append(
            f'<marker id="one-{key}" viewBox="0 0 12 12" refX="1" refY="6" '
            f'markerWidth="11" markerHeight="11" orient="auto">'
            f'<path d="M1,1.5 L1,10.5" fill="none" stroke="{color}" '
            f'stroke-width="1.8"/></marker>')
    defs.append('</defs>')
    parts.append("\n".join(defs))

    # connectors first, so the opaque table boxes sit on top of them
    parts.append('<g id="links">')
    for cons, child, ccol, parent, pcol in FKS:
        d, _, _ = connector(child, ccol, parent, pcol)
        color, key = COLORS[parent], parent.lower()
        parts.append(
            f'<path class="lnk" data-con="{cons}" data-a="{parent}" data-b="{child}" '
            f'd="{d}" fill="none" stroke="{color}" stroke-width="1.6" '
            f'marker-start="url(#one-{key})" marker-end="url(#crow-{key})"/>')
    parts.append('</g>')

    for names in ORDER:
        for name in names:
            parts.append(table_svg(name))

    svg = (f'<svg id="erd" viewBox="0 0 {w} {h}" width="{w}" height="{h}" '
           f'xmlns="http://www.w3.org/2000/svg">\n' + "\n".join(parts) + '\n</svg>')

    legend = "\n".join(
        f'<tr data-a="{p}" data-b="{c}"><td><span class="dot" style="background:{COLORS[p]}">'
        f'</span><code>{k}</code></td><td><code>{c}.{cc}</code></td>'
        f'<td><code>{p}.{pc}</code></td></tr>'
        for k, c, cc, p, pc in FKS)

    req = {"dim": (10, 10), "fact": (20, 50)}
    vol = []
    for name, t in sorted(TABLES.items(),
                          key=lambda kv: ({"dim": 0, "audit": 1, "fact": 2}
                                          [kv[1]["kind"]], kv[0])):
        n, kind = t["rows"], t["kind"]
        if kind in req:
            lo, hi = req[kind]
            need = str(lo) if lo == hi else f"{lo}\u2013{hi}"
            ok = lo <= n <= hi
            status = ('<span class="ok">meets</span>' if ok
                      else '<span class="bad">OUT OF RANGE</span>')
            shown = f"{n}"
        else:
            need, status, shown = "n/a", '<span class="na">trigger-written</span>', "0"
        label = {"dim": "dimension", "fact": "transactional",
                 "audit": "audit"}[kind]
        vol.append(f'<tr><td><code>{name}</code></td><td>{label}</td>'
                   f'<td class="num">{shown}</td><td class="num">{need}</td>'
                   f'<td>{status}</td></tr>')
    volumes = "\n".join(vol)

    graded = [t for t in TABLES.values() if t["kind"] in req]
    assert all(req[t["kind"]][0] <= t["rows"] <= req[t["kind"]][1]
               for t in graded), "a table is outside the required row range"

    counts = dict(
        tables=len(TABLES), fks=len(FKS),
        dims=sum(1 for t in TABLES.values() if t["kind"] == "dim"),
        facts=sum(1 for t in TABLES.values() if t["kind"] == "fact"),
    )

    return HTML.replace("{{SVG}}", svg).replace("{{LEGEND}}", legend) \
               .replace("{{TABLES}}", str(counts["tables"])) \
               .replace("{{DIMS}}", str(counts["dims"])) \
               .replace("{{FACTS}}", str(counts["facts"])) \
               .replace("{{FKS}}", str(counts["fks"])) \
               .replace("{{VOLUMES}}", volumes) \
               .replace("{{LOADED}}", str(sum(t["rows"] for t in TABLES.values())))


HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>E &amp; D Group ERD</title>
<style>
  :root {
    --ink:#111827; --muted:#6b7280; --line:#d1d5db; --bg:#f3f4f6;
    --card:#ffffff; --accent:#1e3a5f;
  }
  * { box-sizing:border-box; }
  body {
    margin:0; padding:28px 16px 56px; background:var(--bg); color:var(--ink);
    font:14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  }
  .wrap { max-width:1120px; margin:0 auto; }
  header { margin-bottom:18px; }
  h1 { margin:0 0 4px; font-size:24px; letter-spacing:-0.01em; }
  .sub { color:var(--muted); margin:0; }
  .sitenav { display:flex; gap:8px; flex-wrap:wrap; margin:0 0 18px; }
  .sitenav a { display:inline-block; padding:7px 13px; border:1px solid var(--line);
    border-radius:7px; background:var(--card,#fff); color:var(--ink);
    font-size:12.5px; font-weight:500; text-decoration:none; }
  .sitenav a:hover { border-color:var(--accent); color:var(--accent); }
  .sitenav a.on { border-color:var(--accent); color:var(--accent);
    box-shadow:inset 0 0 0 1px var(--accent); }
  @media print { .sitenav { display:none; } }
  .stats { display:flex; flex-wrap:wrap; gap:8px; margin:16px 0 0; padding:0; list-style:none; }
  .stats li {
    background:var(--card); border:1px solid var(--line); border-radius:999px;
    padding:4px 12px; font-size:12px;
  }
  .stats b { font-size:13px; }
  .panel {
    background:var(--card); border:1px solid var(--line); border-radius:12px;
    padding:14px; margin-top:18px; overflow:auto;
  }
  .hint { color:var(--muted); font-size:12px; margin:0 0 10px; }
  svg { display:block; max-width:100%; height:auto; }
  .shadow { fill:#000; opacity:.07; }
  .box { stroke:#cbd5e1; stroke-width:1; }
  .zebra { fill:#f8fafc; }
  .tname { fill:#fff; font:600 13px ui-monospace, SFMono-Regular, Menlo, monospace; }
  .tkind { fill:#ffffff; opacity:.62; font:600 9px -apple-system, sans-serif; letter-spacing:.09em; }
  .col  { fill:#1f2937; font:12px ui-monospace, SFMono-Regular, Menlo, monospace; }
  .col.pk { font-weight:700; }
  .typ  { fill:#6b7280; font:10.5px ui-monospace, SFMono-Regular, Menlo, monospace; }
  .typ.null { fill:#9ca3af; font-style:italic; }
  .badge { font:700 8.5px -apple-system, sans-serif; }
  .b-pk { fill:#b45309; } .b-fk { fill:#1d4ed8; } .b-dd { fill:#7c3aed; }
  .rowcount { fill:#9ca3af; font:9.5px -apple-system, sans-serif; }
  .lnk { opacity:.85; }

  /* hover isolation - 15 keys cross, so let one table answer at a time */
  #erd.focus .lnk { opacity:.07; }
  #erd.focus .tbl { opacity:.3; }
  #erd.focus .lnk.on { opacity:1; stroke-width:2.4; }
  #erd.focus .tbl.on { opacity:1; }
  .tbl { cursor:default; transition:opacity .12s; }
  .lnk { transition:opacity .12s, stroke-width .12s; }

  table.fks { border-collapse:collapse; width:100%; font-size:12.5px; }
  table.fks th {
    text-align:left; color:var(--muted); font-weight:600; font-size:11px;
    letter-spacing:.05em; text-transform:uppercase; padding:6px 10px;
    border-bottom:1px solid var(--line);
  }
  table.fks td { padding:5px 10px; border-bottom:1px solid #f1f5f9; }
  table.fks code { font:11.5px ui-monospace, SFMono-Regular, Menlo, monospace; }
  table.vol { border-collapse:collapse; width:100%; font-size:12.5px; }
  table.vol th {
    text-align:left; font-weight:600; color:var(--muted); font-size:11px;
    text-transform:uppercase; letter-spacing:.04em; padding:0 10px 6px;
    border-bottom:1px solid var(--line);
  }
  table.vol td { padding:5px 10px; border-bottom:1px solid #f1f5f9; }
  table.vol code { font:11.5px ui-monospace, SFMono-Regular, Menlo, monospace; }
  table.vol .num { text-align:right; font-variant-numeric:tabular-nums; }
  .ok, .bad, .na {
    font-size:11px; font-weight:600; padding:1px 7px; border-radius:999px;
  }
  .ok  { background:#dcfce7; color:#14532d; }
  .bad { background:#fee2e2; color:#7f1d1d; }
  .na  { background:#f1f5f9; color:#475569; font-weight:500; }
  .dot {
    display:inline-block; width:8px; height:8px; border-radius:50%;
    margin-right:7px; vertical-align:middle;
  }
  h2 { font-size:15px; margin:0 0 10px; }
  footer { color:var(--muted); font-size:11.5px; margin-top:22px; text-align:center; }

  @media print {
    @page { size:letter landscape; margin:9mm; }
    body { background:#fff; padding:0; }
    .wrap { max-width:none; }
    header { margin-bottom:8px; }
    h1 { font-size:17px; }
    .sub { font-size:11px; }
    .stats { margin-top:8px; }
    .stats li { border-color:#999; padding:2px 9px; font-size:10px; }
    .panel { border:none; padding:0; box-shadow:none; margin-top:10px; }
    .hint { display:none; }
    /* The diagram is nearly square and the page is not, so fit it by
       height - that is the binding dimension on landscape letter. */
    #erd { height:6.35in; width:auto; max-width:100%; }
    #erd.focus .lnk, #erd.focus .tbl { opacity:1 !important; }
    .break { page-break-before:always; }
    table.fks { font-size:10pt; }
    footer { display:none; }
  }
</style>
</head>
<body>
<div class="wrap">
  <nav class="sitenav">
    <a href="index.html">Project home</a>
    <a class="on" href="erd.html">ERD</a>
    <a href="dashboard.html">Dashboard</a>
    <a href="design_spec.html">Design spec</a>
  </nav>
  <header>
    <h1>E &amp; D Group &mdash; Entity Relationship Diagram</h1>
    <p class="sub">Online game live-ops analytics &middot; star schema &middot; IFT 530 Final Project</p>
    <ul class="stats">
      <li><b>{{TABLES}}</b> tables</li>
      <li><b>{{DIMS}}</b> dimensions</li>
      <li><b>{{FACTS}}</b> fact tables</li>
      <li><b>{{FKS}}</b> foreign keys</li>
      <li>0 circular references</li>
      <li><b>{{LOADED}}</b> rows loaded</li>
      <li><b>PK</b> primary key &middot; <b>FK</b> foreign key &middot; <b>DD</b> degenerate dimension</li>
    </ul>
  </header>

  <div class="panel">
    <p class="hint">Hover a table to isolate its relationships. Line color follows the parent table.</p>
    {{SVG}}
  </div>

  <div class="panel break">
    <h2>Foreign keys</h2>
    <table class="fks">
      <thead><tr><th>Constraint</th><th>Child column</th><th>Parent column</th></tr></thead>
      <tbody>
        {{LEGEND}}
      </tbody>
    </table>
  </div>

  <div class="panel break">
    <h2>Data volumes</h2>
    <p class="hint">The assignment sets the load: 10 rows in every dimension
      table and 20&ndash;50 in every transactional table. The data is laid out
      by hand to stay analytically useful at that size &mdash; the window
      crosses a month boundary, sessions cluster onto nine days, and the
      payments that trip the fraud view are planted deliberately.</p>
    <table class="vol">
      <thead><tr><th>Table</th><th>Kind</th><th class="num">Rows</th>
        <th class="num">Required</th><th>Status</th></tr></thead>
      <tbody>
        {{VOLUMES}}
      </tbody>
    </table>
  </div>

  <footer>Generated from <code>parts/30_tables.sql</code> by <code>tools/erd_html.py</code></footer>
</div>

<script>
(function () {
  var svg = document.getElementById('erd');
  var links = Array.prototype.slice.call(svg.querySelectorAll('.lnk'));
  var tbls  = Array.prototype.slice.call(svg.querySelectorAll('.tbl'));

  function clear() {
    svg.classList.remove('focus');
    links.forEach(function (l) { l.classList.remove('on'); });
    tbls.forEach(function (t) { t.classList.remove('on'); });
    rows().forEach(function (r) { r.style.background = ''; });
  }
  function rows() {
    return Array.prototype.slice.call(document.querySelectorAll('table.fks tr[data-a]'));
  }
  function focus(name) {
    clear();
    svg.classList.add('focus');
    var keep = {};
    keep[name] = true;
    links.forEach(function (l) {
      if (l.dataset.a === name || l.dataset.b === name) {
        l.classList.add('on');
        keep[l.dataset.a] = true;
        keep[l.dataset.b] = true;
      }
    });
    tbls.forEach(function (t) { if (keep[t.dataset.table]) t.classList.add('on'); });
    rows().forEach(function (r) {
      if (r.dataset.a === name || r.dataset.b === name) r.style.background = '#fef9c3';
    });
  }

  tbls.forEach(function (t) {
    t.addEventListener('mouseenter', function () { focus(t.dataset.table); });
  });
  svg.addEventListener('mouseleave', clear);
  rows().forEach(function (r) {
    r.addEventListener('mouseenter', function () { focus(r.dataset.b); });
    r.addEventListener('mouseleave', clear);
  });
})();
</script>
</body>
</html>
"""

if __name__ == "__main__":
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(here, "docs", "erd.html")
    with open(out, "w") as fh:
        fh.write(build())
    print("wrote", out)
