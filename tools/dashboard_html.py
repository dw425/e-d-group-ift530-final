#!/usr/bin/env python3
"""Build docs/dashboard.html from the live E_D_Group database.

Every number on the page is read out of the database at build time - the
same views, procedure and tables the submitted script creates - so the
dashboard cannot drift from the data it describes. Run it after the
script has been executed:

    source .env && /usr/local/bin/python3 tools/dashboard_html.py

The world map is a vendored Natural Earth path; see tools/data/README.md.
"""
import os
import subprocess
import sys
from datetime import datetime, timezone
from html import escape
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
DB = "E_D_Group"
SEP = "\x1f"

# equirectangular frame the vendored path was projected into
MAP_W, MAP_H = 1000.0, 394.4
LAT_MAX, LAT_MIN = 84.0, -58.0

C = {
    "bg": "#0a0e13", "panel": "#121a23", "panel2": "#0f161e",
    "line": "#1e2a36", "text": "#e6edf3", "mute": "#8b98a5",
    "dim": "#5d6b7a",
    "teal": "#2dd4bf", "blue": "#60a5fa", "violet": "#a78bfa",
    "amber": "#fbbf24", "rose": "#fb7185", "green": "#34d399",
}


def q(sql):
    pw = os.environ.get("MSSQL_SA_PASSWORD")
    if not pw:
        sys.exit("source .env first")
    out = subprocess.run(
        ["sqlcmd", "-S", "localhost,1433", "-U", "sa", "-C", "-d", DB,
         "-h", "-1", "-W", "-s", SEP, "-Q", f"SET NOCOUNT ON; {sql}"],
        capture_output=True, text=True,
        env={**os.environ, "SQLCMDPASSWORD": pw})
    if out.returncode:
        sys.exit(out.stdout + out.stderr)
    rows = []
    for line in out.stdout.splitlines():
        line = line.rstrip()
        if not line or line.startswith("Warning:"):
            continue
        rows.append([c.strip() for c in line.split(SEP)])
    return rows


def one(sql):
    return q(sql)[0][0]


def fnum(v, nd=0):
    return f"{float(v):,.{nd}f}"


# ----------------------------------------------------------------- data

def collect():
    d = {}
    d["users"] = int(one("SELECT COUNT(*) FROM dbo.DimUser;"))
    d["accounts"] = int(one("SELECT COUNT(*) FROM dbo.DimAccount;"))
    d["open"] = int(one(
        "SELECT COUNT(*) FROM dbo.DimAccount WHERE ClosedDate IS NULL;"))
    d["paid"] = int(one(
        "SELECT COUNT(*) FROM dbo.DimAccount a JOIN dbo.DimPlan p"
        " ON p.PlanID=a.PlanID WHERE a.ClosedDate IS NULL AND p.IsPaid=1;"))
    d["events"] = int(one("SELECT COUNT(*) FROM dbo.FactUserEvent;"))
    d["sessions"] = int(one(
        "SELECT COUNT(DISTINCT SessionID) FROM dbo.FactUserEvent;"))
    d["payments"] = int(one("SELECT COUNT(*) FROM dbo.FactPayment;"))
    d["subs"] = int(one("SELECT COUNT(*) FROM dbo.FactSubscription;"))
    d["flagged"] = int(one(
        "SELECT COUNT(*) FROM dbo.vwSuspiciousTransactions;"))

    r = q("SELECT CAST(SUM(CASE WHEN PaymentType='Refund' THEN -AmountUSD"
          " ELSE AmountUSD END) AS DECIMAL(10,2)),"
          " CAST(SUM(CASE WHEN PaymentType='Refund' THEN AmountUSD ELSE 0"
          " END) AS DECIMAL(10,2)),"
          " CAST(SUM(CASE WHEN PaymentType<>'Refund' THEN AmountUSD ELSE 0"
          " END) AS DECIMAL(10,2)) FROM dbo.FactPayment;")[0]
    d["net"], d["refunds"], d["gross"] = (float(x) for x in r)

    d["dau"] = [(a, int(b), int(c), int(e), int(f), float(g))
                for a, b, c, e, f, g in
                q("SELECT ActivityDate, DAU, PaidDAU, FreeDAU,"
                  " Rolling30DayMAU, StickinessPct"
                  " FROM dbo.vwDailyActiveUsers ORDER BY ActivityDate;")]
    d["plans"] = [(n, float(p), int(ac), int(se), int(ev), float(nr))
                  for _, n, p, ac, se, ev, _, nr, _ in
                  q("SELECT * FROM dbo.vwFreeVsPaidValue;")]
    d["mau"] = [(int(y), int(m), int(mau), int(nu), int(ru), float(rev))
                for y, m, mau, nu, ru, rev, _ in
                q("EXEC dbo.spMonthlyActiveUsers @Year=2026;")]
    d["geo"] = [(cc, city, float(la), float(lo), int(ev), int(pl), rt)
                for cc, city, la, lo, ev, pl, rt in
                q("SELECT g.CountryCode, g.City, g.Latitude, g.Longitude,"
                  " COUNT(e.EventID), COUNT(DISTINCT e.UserID), g.RiskTier"
                  " FROM dbo.DimGeography g"
                  " LEFT JOIN dbo.FactUserEvent e ON e.GeoID=g.GeoID"
                  " GROUP BY g.CountryCode, g.City, g.Latitude,"
                  " g.Longitude, g.RiskTier ORDER BY COUNT(e.EventID) DESC;")]
    d["levels"] = [(int(l), int(a), int(w), int(ls), int(ab))
                   for l, a, w, ls, ab in
                   q("SELECT LevelNumber, COUNT(*),"
                     " SUM(CASE WHEN Outcome='Win' THEN 1 ELSE 0 END),"
                     " SUM(CASE WHEN Outcome='Loss' THEN 1 ELSE 0 END),"
                     " SUM(CASE WHEN Outcome='Abandon' THEN 1 ELSE 0 END)"
                     " FROM dbo.FactUserEvent WHERE LevelNumber IS NOT NULL"
                     " AND Outcome IS NOT NULL GROUP BY LevelNumber"
                     " ORDER BY LevelNumber;")]
    d["etypes"] = [(a, int(b)) for a, b in
                   q("SELECT EventType, COUNT(*) FROM dbo.FactUserEvent"
                     " GROUP BY EventType ORDER BY COUNT(*) DESC;")]
    d["devices"] = [(a, int(b)) for a, b in
                    q("SELECT DeviceType, COUNT(*) FROM dbo.FactUserEvent"
                      " GROUP BY DeviceType ORDER BY COUNT(*) DESC;")]
    d["subevents"] = [(a, int(b), float(c)) for a, b, c in
                      q("SELECT EventType, COUNT(*),"
                        " CAST(SUM(MRRDeltaUSD) AS DECIMAL(10,2))"
                        " FROM dbo.FactSubscription GROUP BY EventType"
                        " ORDER BY COUNT(*) DESC;")]
    d["reasons"] = [(a, int(b)) for a, b in
                    q("SELECT Reason, COUNT(*) FROM"
                      " dbo.vwSuspiciousTransactions GROUP BY Reason"
                      " ORDER BY COUNT(*) DESC;")]
    d["stages"] = [(a, int(b)) for a, b in
                   q("SELECT LifecycleStage, COUNT(*) FROM dbo.DimUser"
                     " GROUP BY LifecycleStage ORDER BY COUNT(*) DESC;")]
    d["paytypes"] = [(a, int(b), float(c)) for a, b, c in
                     q("SELECT PaymentType, COUNT(*),"
                       " CAST(SUM(AmountUSD) AS DECIMAL(10,2))"
                       " FROM dbo.FactPayment GROUP BY PaymentType"
                       " ORDER BY COUNT(*) DESC;")]
    return d


# --------------------------------------------------------------- charts

def kpi(label, value, sub, accent):
    return (f'<div class="kpi"><div class="kpi-l">{escape(label)}</div>'
            f'<div class="kpi-v" style="color:{accent}">{value}</div>'
            f'<div class="kpi-s">{escape(sub)}</div></div>')


def chart_dau(d):
    """DAU bars with the rolling 30-day count as a line over them."""
    rows = d["dau"]
    W, H = 920, 260
    L, R, T, B = 52, 46, 18, 46
    iw, ih = W - L - R, H - T - B
    maxv = max(max(r[1] for r in rows), max(r[4] for r in rows))
    maxv = max(maxv, 1)
    n = len(rows)
    step = iw / n
    bw = min(34, step * 0.5)
    s = []
    for g in range(0, maxv + 1, max(1, maxv // 4)):
        y = T + ih - (g / maxv) * ih
        s.append(f'<line class="grid" x1="{L}" y1="{y:.1f}" x2="{L+iw}" '
                 f'y2="{y:.1f}"/>')
        s.append(f'<text class="ax" x="{L-10}" y="{y+4:.1f}" '
                 f'text-anchor="end">{g}</text>')
    pts = []
    for i, (date, dau, paid, free, mau, stick) in enumerate(rows):
        cx = L + step * (i + 0.5)
        hp = (paid / maxv) * ih
        hf = (free / maxv) * ih
        yp = T + ih - hp
        yf = yp - hf
        if paid:
            s.append(f'<rect class="bar" x="{cx-bw/2:.1f}" y="{yp:.1f}" '
                     f'width="{bw:.1f}" height="{hp:.1f}" rx="2" '
                     f'fill="{C["teal"]}"><title>{date}: {paid} paid'
                     f'</title></rect>')
        if free:
            s.append(f'<rect class="bar" x="{cx-bw/2:.1f}" y="{yf:.1f}" '
                     f'width="{bw:.1f}" height="{hf:.1f}" rx="2" '
                     f'fill="{C["blue"]}"><title>{date}: {free} free'
                     f'</title></rect>')
        pts.append((cx, T + ih - (mau / maxv) * ih, date, mau, stick))
        s.append(f'<text class="ax" x="{cx:.1f}" y="{T+ih+18}" '
                 f'text-anchor="middle">{date[5:]}</text>')
    line = ' '.join(f'{x:.1f},{y:.1f}' for x, y, *_ in pts)
    s.append(f'<polyline class="mau" points="{line}"/>')
    for x, y, date, mau, stick in pts:
        s.append(f'<circle class="dot" cx="{x:.1f}" cy="{y:.1f}" r="4">'
                 f'<title>{date}: MAU {mau}, stickiness {stick:.1f}%</title>'
                 f'</circle>')
    s.append(f'<text class="ax" x="{L-10}" y="{T-4}" text-anchor="end">'
             f'players</text>')
    return (f'<svg viewBox="0 0 {W} {H}" class="chart">' + ''.join(s) +
            '</svg>')


def chart_map(d):
    """Land path with one bubble per city, sized by events."""
    land = (HERE / "tools/data/world_land_110m.path").read_text()
    rows = [r for r in d["geo"]]
    maxev = max((r[4] for r in rows), default=1) or 1
    s = [f'<path d="{land}" class="land"/>']
    for lon in range(-180, 181, 60):
        x = (lon + 180) / 360 * MAP_W
        s.append(f'<line class="mgrid" x1="{x:.1f}" y1="0" x2="{x:.1f}" '
                 f'y2="{MAP_H}"/>')
    for lat in (-30, 0, 30, 60):
        y = (LAT_MAX - lat) / (LAT_MAX - LAT_MIN) * MAP_H
        s.append(f'<line class="mgrid" x1="0" y1="{y:.1f}" x2="{MAP_W}" '
                 f'y2="{y:.1f}"/>')
    labels = []
    risk = {"Low": C["teal"], "Medium": C["amber"], "High": C["rose"]}
    for cc, city, la, lo, ev, pl, rt in sorted(rows, key=lambda r: -r[4]):
        x = (lo + 180) / 360 * MAP_W
        y = (LAT_MAX - la) / (LAT_MAX - LAT_MIN) * MAP_H
        r = 5 + 20 * (ev / maxev) ** 0.5 if ev else 4
        col = risk.get(rt, C["blue"])
        s.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" '
                 f'class="bub" fill="{col}"><title>{escape(city)} '
                 f'({escape(cc)}) - {ev} events, {pl} player(s), '
                 f'{escape(rt)} risk</title></circle>')
        s.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="1.8" '
                 f'fill="{C["bg"]}" opacity=".85"/>')
        if ev >= maxev * 0.5:
            labels.append((x, y, r, city))
    placed = []
    for x, y, r, city in labels:
        ly, dy = y - r - 7, -1
        while any(abs(px - x) < 54 and abs(py - ly) < 13
                  for px, py in placed):
            ly, dy = (y + r + 14, 1) if dy < 0 else (ly + 13, 1)
        placed.append((x, ly))
        s.append(f'<text class="mlab" x="{x:.1f}" y="{ly:.1f}" '
                 f'text-anchor="middle">{escape(city)}</text>')
    return (f'<svg viewBox="0 0 {MAP_W} {MAP_H}" class="map">'
            + ''.join(s) + '</svg>')


def hbars(rows, accent_for, fmt, width=430):
    """Horizontal bars: rows are (label, value, sublabel)."""
    maxv = max((abs(v) for _, v, _ in rows), default=1) or 1
    out = []
    for label, v, sub in rows:
        pct = abs(v) / maxv * 100
        out.append(
            f'<div class="hb"><div class="hb-l">{escape(label)}</div>'
            f'<div class="hb-t"><div class="hb-f" style="width:{pct:.1f}%;'
            f'background:{accent_for(label, v)}"></div></div>'
            f'<div class="hb-v">{fmt(v)}</div>'
            f'<div class="hb-s">{escape(sub)}</div></div>')
    return ''.join(out)


def chart_levels(d):
    rows = d["levels"]
    out = []
    for lv, att, win, loss, ab in rows:
        pct = win / att * 100 if att else 0
        flag = pct < 50
        col = C["rose"] if flag else (C["amber"] if pct < 60 else C["green"])
        tag = ('<span class="tag rose">churn risk</span>' if flag else
               '<span class="tag amber">hard</span>' if pct < 60 else
               '<span class="tag green">ok</span>')
        out.append(
            f'<div class="hb"><div class="hb-l">Level {lv}</div>'
            f'<div class="hb-t"><div class="hb-f" style="width:{pct:.0f}%;'
            f'background:{col}"></div></div>'
            f'<div class="hb-v">{pct:.0f}%</div>'
            f'<div class="hb-s">{win}/{att} won {tag}</div></div>')
    return ''.join(out)


# ------------------------------------------------------------------ page

CSS = """
*{box-sizing:border-box}
body{margin:0;background:%(bg)s;color:%(text)s;
 font:14px/1.5 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,
 Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased}
a{color:%(blue)s;text-decoration:none}
a:hover{text-decoration:underline}
.wrap{max-width:1180px;margin:0 auto;padding:28px 22px 56px}
header{display:flex;flex-wrap:wrap;gap:16px;align-items:flex-end;
 justify-content:space-between;padding-bottom:18px;
 border-bottom:1px solid %(line)s;margin-bottom:22px}
h1{margin:0;font-size:23px;letter-spacing:-.3px;font-weight:650}
.sub{color:%(mute)s;font-size:13px;margin-top:5px}
.sitenav{display:flex;gap:8px;flex-wrap:wrap}
.sitenav a{display:inline-block;padding:7px 13px;border:1px solid %(line)s;
 border-radius:7px;background:%(panel)s;color:%(text)s;font-size:12.5px;
 font-weight:500}
.sitenav a:hover{border-color:%(teal)s;color:%(teal)s;text-decoration:none}
.sitenav a.on{border-color:%(teal)s;color:%(teal)s}
h2{font-size:12px;text-transform:uppercase;letter-spacing:.9px;
 color:%(mute)s;margin:0 0 3px;font-weight:600}
.note{color:%(dim)s;font-size:12px;margin:0 0 14px}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(168px,1fr));
 gap:12px;margin-bottom:24px}
.kpi{background:%(panel)s;border:1px solid %(line)s;border-radius:11px;
 padding:14px 15px}
.kpi-l{color:%(mute)s;font-size:11px;text-transform:uppercase;
 letter-spacing:.7px;font-weight:600}
.kpi-v{font-size:26px;font-weight:660;margin:7px 0 2px;
 letter-spacing:-.6px;font-variant-numeric:tabular-nums}
.kpi-s{color:%(dim)s;font-size:11.5px}
.grid{display:grid;gap:16px;margin-bottom:16px}
.g2{grid-template-columns:1fr 1fr}
.g3{grid-template-columns:1fr 1fr 1fr}
.card{background:%(panel)s;border:1px solid %(line)s;border-radius:12px;
 padding:17px 18px 15px}
.chart{width:100%%;height:auto;display:block;overflow:visible}
.grid line,.grid{stroke:%(line)s}
line.grid{stroke:%(line)s;stroke-width:1}
line.mgrid{stroke:#182330;stroke-width:1}
text.ax{fill:%(dim)s;font-size:11px;
 font-family:-apple-system,BlinkMacSystemFont,sans-serif}
text.mlab{fill:#cbd5e1;font-size:11px;font-weight:600;paint-order:stroke;stroke:%(panel2)s;stroke-width:3px;stroke-linejoin:round;
 font-family:-apple-system,BlinkMacSystemFont,sans-serif}
polyline.mau{fill:none;stroke:%(violet)s;stroke-width:2.2;
 stroke-linejoin:round;stroke-linecap:round}
circle.dot{fill:%(violet)s;stroke:%(panel)s;stroke-width:2}
rect.bar:hover,circle.bub:hover{opacity:.82}
.map{width:100%%;height:auto;display:block;background:%(panel2)s;
 border-radius:9px;border:1px solid %(line)s}
path.land{fill:#1b2733;stroke:#243343;stroke-width:.6}
circle.bub{opacity:.72;stroke:%(bg)s;stroke-width:1.2;cursor:pointer}
.legend{display:flex;gap:15px;flex-wrap:wrap;color:%(mute)s;font-size:11.5px;
 margin-top:11px}
.sw{display:inline-block;width:9px;height:9px;border-radius:50%%;
 margin-right:6px;vertical-align:middle}
.hb{display:grid;grid-template-columns:132px 1fr 60px;
 grid-template-areas:'l t v' '. s s';gap:3px 11px;align-items:center;
 margin-bottom:11px}
.hb-l{grid-area:l;color:%(text)s;font-size:12.5px;font-weight:500;
 overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.hb-t{grid-area:t;background:%(panel2)s;border-radius:5px;height:9px;
 overflow:hidden}
.hb-f{height:100%%;border-radius:5px}
.hb-v{grid-area:v;text-align:right;font-size:12.5px;font-weight:600;
 font-variant-numeric:tabular-nums}
.hb-s{grid-area:s;color:%(dim)s;font-size:11px}
.tag{display:inline-block;padding:1px 6px;border-radius:4px;font-size:10px;
 font-weight:650;text-transform:uppercase;letter-spacing:.4px;margin-left:5px}
.tag.rose{background:rgba(251,113,133,.15);color:%(rose)s}
.tag.amber{background:rgba(251,191,36,.15);color:%(amber)s}
.tag.green{background:rgba(52,211,153,.15);color:%(green)s}
table{width:100%%;border-collapse:collapse;font-size:12.5px}
th{text-align:left;color:%(mute)s;font-weight:600;font-size:11px;
 text-transform:uppercase;letter-spacing:.6px;padding:0 8px 8px 0;
 border-bottom:1px solid %(line)s}
td{padding:8px 8px 8px 0;border-bottom:1px solid #16212c;
 font-variant-numeric:tabular-nums}
tr:last-child td{border-bottom:0}
td.r,th.r{text-align:right}
footer{margin-top:30px;padding-top:18px;border-top:1px solid %(line)s;
 color:%(dim)s;font-size:12px;line-height:1.7}
@media(max-width:860px){.g2,.g3{grid-template-columns:1fr}}
""" % C


def build(d):
    stick_now = d["dau"][-1][5]
    mau_now = d["mau"][-1][2] if d["mau"] else 0
    peak_dau = max(r[1] for r in d["dau"])
    arpu = d["net"] / d["users"] if d["users"] else 0
    conv = d["paid"] / d["open"] * 100 if d["open"] else 0
    refund_rate = d["refunds"] / d["gross"] * 100 if d["gross"] else 0
    fraud_rate = d["flagged"] / d["payments"] * 100 if d["payments"] else 0
    churn_levels = sum(1 for _, a, w, _, _ in d["levels"]
                       if a and w / a < 0.5)
    eps = d["events"] / d["sessions"] if d["sessions"] else 0
    mrr = sum(x[2] for x in d["subevents"])

    k = [
        kpi("Players", fnum(d["users"]),
            f'{d["open"]} open accounts', C["text"]),
        kpi("MAU", fnum(mau_now), "October, from the procedure", C["blue"]),
        kpi("Peak DAU", fnum(peak_dau),
            f'over {len(d["dau"])} active days', C["teal"]),
        kpi("Stickiness", f"{stick_now:.1f}%",
            "DAU / rolling MAU, latest day", C["violet"]),
        kpi("Sessions", fnum(d["sessions"]),
            f"{eps:.1f} events per session", C["text"]),
        kpi("Events", fnum(d["events"]), "all tracked actions", C["text"]),
        kpi("Net revenue", "$" + fnum(d["net"], 2), "after refunds",
            C["green"]),
        kpi("ARPU", "$" + fnum(arpu, 2), "net revenue / player",
            C["green"]),
        kpi("Paid conversion", f"{conv:.1f}%",
            f'{d["paid"]} of {d["open"]} open accounts', C["amber"]),
        kpi("Refund rate", f"{refund_rate:.1f}%",
            "$" + fnum(d["refunds"], 2) + " of $" + fnum(d["gross"], 2),
            C["amber"]),
        kpi("Flagged payments", fnum(d["flagged"]),
            f'{fraud_rate:.1f}% of {d["payments"]} payments', C["rose"]),
        kpi("Churn-risk levels", fnum(churn_levels),
            "lost more often than won", C["rose"]),
        kpi("Net MRR movement", ("+" if mrr >= 0 else "-") + "$"
            + fnum(abs(mrr), 2), f'{d["subs"]} lifecycle events',
            C["teal"]),
    ]

    plan_rows = [(n, nr, f"{ac} account(s) - ${p:,.2f}/mo - {ev} events")
                 for n, p, ac, se, ev, nr in
                 sorted(d["plans"], key=lambda r: -r[5])]
    plan_col = lambda label, v: (C["blue"] if label == "Free" else C["teal"])

    dev_total = sum(v for _, v in d["devices"]) or 1
    dev_rows = [(n, v, f"{v/dev_total*100:.0f}% of events")
                for n, v in d["devices"]]
    dev_pal = {"iOS": C["teal"], "PC": C["blue"], "Android": C["violet"],
               "Console": C["amber"]}
    dev_col = lambda label, v: dev_pal.get(label, C["blue"])

    ev_total = sum(v for _, v in d["etypes"]) or 1
    ev_rows = [(n, v, f"{v/ev_total*100:.0f}% of traffic")
               for n, v in d["etypes"]]
    ev_col = lambda label, v: (
        C["rose"] if label == "LevelFail" else
        C["teal"] if label.startswith("Level") else
        C["blue"] if label.startswith("Session") else C["violet"])

    sub_rows = [(n, c, ("+" if m >= 0 else "-") + "$" + fnum(abs(m), 2)
                 + " MRR") for n, c, m in d["subevents"]]
    sub_col = lambda label, v: (
        C["rose"] if label in ("Cancel", "Downgrade") else
        C["green"] if label in ("Start", "Upgrade") else C["blue"])

    reason_rows = [(n, v, "") for n, v in d["reasons"]]
    reason_col = lambda label, v: (
        C["rose"] if "travel" in label.lower() else C["amber"])

    stage_rows = [(n, v, "") for n, v in d["stages"]]
    stage_col = lambda label, v: (
        C["green"] if label == "Active" else
        C["amber"] if label == "AtRisk" else C["blue"])

    mau_tbl = ''.join(
        f'<tr><td>{y}-{m:02d}</td><td class="r">{mau}</td>'
        f'<td class="r">{nu}</td><td class="r">{ru}</td>'
        f'<td class="r">${rev:,.2f}</td>'
        f'<td class="r">${rev/mau if mau else 0:,.2f}</td></tr>'
        for y, m, mau, nu, ru, rev in d["mau"])

    geo_tbl = ''.join(
        f'<tr><td>{escape(city)}</td><td>{escape(cc)}</td>'
        f'<td class="r">{ev}</td><td class="r">{pl}</td>'
        f'<td class="r"><span class="tag '
        f'{"rose" if rt=="High" else "amber" if rt=="Medium" else "green"}">'
        f'{escape(rt)}</span></td></tr>'
        for cc, city, la, lo, ev, pl, rt in d["geo"])

    built = datetime.now(timezone.utc).astimezone().strftime(
        "%B %-d, %Y at %-I:%M %p %Z")

    return f"""<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>E &amp; D Group - Player Analytics Dashboard</title>
<style>{CSS}</style>
</head><body>
<div class="wrap">

<header>
  <div>
    <h1>Player Analytics Dashboard</h1>
    <div class="sub">E &amp; D Group &middot; <code>E_D_Group</code>
      &middot; live-ops KPIs read straight from the database</div>
  </div>
  <nav class="sitenav">
    <a href="index.html">Project home</a>
    <a href="erd.html">ERD</a>
    <a class="on" href="dashboard.html">Dashboard</a>
    <a href="design_spec.html">Design spec</a>
  </nav>
</header>

<h2>Headline KPIs</h2>
<p class="note">Thirteen measures, every one computed at build time from
  the tables, views and stored procedure the submitted script creates.</p>
<div class="kpis">{''.join(k)}</div>

<div class="grid g2">
  <div class="card" style="grid-column:1/-1">
    <h2>Traffic &mdash; daily active users and the rolling 30-day count</h2>
    <p class="note">Bars are that day's active players split paid against
      free; the line is the rolling 30-day active count. Days nobody
      played are absent, which is why there are {len(d['dau'])} points and
      not thirty.</p>
    {chart_dau(d)}
    <div class="legend">
      <span><span class="sw" style="background:{C['teal']}"></span>Paid
        DAU</span>
      <span><span class="sw" style="background:{C['blue']}"></span>Free
        DAU</span>
      <span><span class="sw" style="background:{C['violet']}"></span>
        Rolling 30-day MAU</span>
    </div>
  </div>

  <div class="card" style="grid-column:1/-1">
    <h2>Where the players are</h2>
    <p class="note">One bubble per location in
      <code>DimGeography</code>, sized by the events recorded there and
      colored by the risk tier the fraud view reads. Hover for the
      counts.</p>
    {chart_map(d)}
    <div class="legend">
      <span><span class="sw" style="background:{C['teal']}"></span>Low
        risk</span>
      <span><span class="sw" style="background:{C['amber']}"></span>
        Medium risk</span>
      <span><span class="sw" style="background:{C['rose']}"></span>High
        risk</span>
      <span>Bubble area &prop; events</span>
    </div>
  </div>

  <div class="card">
    <h2>Net revenue by plan</h2>
    <p class="note">The free tier out-earns every single paid plan, on
      one-time store purchases.</p>
    {hbars(plan_rows, plan_col, lambda v: '$' + fnum(v, 2))}
  </div>

  <div class="card">
    <h2>Level difficulty</h2>
    <p class="note">Win rate per level, from the same data the cursor
      walks. Under 50% is flagged as a churn risk.</p>
    {chart_levels(d)}
  </div>

  <div class="card">
    <h2>Traffic mix by event type</h2>
    {hbars(ev_rows, ev_col, lambda v: fnum(v))}
  </div>

  <div class="card">
    <h2>Platform mix</h2>
    {hbars(dev_rows, dev_col, lambda v: fnum(v))}
  </div>

  <div class="card">
    <h2>Subscription movement</h2>
    <p class="note">Lifecycle events and what each did to monthly
      recurring revenue.</p>
    {hbars(sub_rows, sub_col, lambda v: fnum(v))}
  </div>

  <div class="card">
    <h2>Player lifecycle</h2>
    {hbars(stage_rows, stage_col, lambda v: fnum(v))}
  </div>

  <div class="card">
    <h2>Monthly active users</h2>
    <p class="note">Straight from
      <code>spMonthlyActiveUsers @Year=2026</code>.</p>
    <table><thead><tr><th>Month</th><th class="r">MAU</th>
      <th class="r">New</th><th class="r">Returning</th>
      <th class="r">Net revenue</th><th class="r">ARPU</th></tr></thead>
      <tbody>{mau_tbl}</tbody></table>
  </div>

  <div class="card">
    <h2>Flagged payments</h2>
    <p class="note">{d['flagged']} of {d['payments']} payments caught by
      <code>vwSuspiciousTransactions</code>, by reason.</p>
    {hbars(reason_rows, reason_col, lambda v: fnum(v))}
  </div>

  <div class="card" style="grid-column:1/-1">
    <h2>Traffic concentration by location</h2>
    <table><thead><tr><th>City</th><th>Country</th>
      <th class="r">Events</th><th class="r">Players</th>
      <th class="r">Risk tier</th></tr></thead>
      <tbody>{geo_tbl}</tbody></table>
  </div>
</div>

<footer>
  Built by <code>tools/dashboard_html.py</code> from the live
  <code>E_D_Group</code> database on {built}. Every figure on this page is
  a query against the tables, views and stored procedure created by
  <code>IFT530_EDGroup_FinalProject.sql</code> &mdash; nothing here is
  typed in by hand.<br>
  Row counts behind it: {d['users']} users, {d['accounts']} accounts,
  {d['events']} events across {d['sessions']} sessions,
  {d['payments']} payments, {d['subs']} subscription events.<br>
  World map: Natural Earth 110m land, public domain &mdash; see
  <code>tools/data/README.md</code>.
</footer>

</div></body></html>
"""


def main():
    d = collect()
    out = HERE / "docs/dashboard.html"
    out.write_text(build(d))
    print(f"wrote {out}  ({out.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
