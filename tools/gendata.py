#!/usr/bin/env python3
"""Generate the populate section of the final project script.

Writes parts/40_populate.sql. Only literal INSERT statements ship; this
generator stays in the repo so the data can be regenerated and explained.

Volumes follow the assignment exactly: 10 rows in every dimension table,
and 20-50 rows in each transactional table.

At those volumes the data is written out explicitly rather than sampled.
Ten users is small enough that a random draw can easily produce no paid
accounts, no second calendar month, or no level with a losing record -
and three of the views, the procedure and the cursor each depend on one
of those being true. Anything structural is therefore stated here as a
literal. Only incidental fields (device, payment method, the minutes
inside a session) are drawn from the seeded generator, so the output is
still identical on every run.
"""
import random
from datetime import date, datetime, time, timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "parts" / "40_populate.sql"

SEED = 530
WINDOW_START = date(2026, 9, 26)
WINDOW_END = date(2026, 10, 25)
WINDOW_DAYS = (WINDOW_END - WINDOW_START).days + 1

rng = random.Random(SEED)

# ---------------------------------------------------------------- dimensions
# id, cc, country, region, city, lat, lon, risk
GEO = [
    (1,  "US", "United States",  "North America", "Phoenix",   33.448377, -112.074037, "Low"),
    (2,  "US", "United States",  "North America", "Seattle",   47.606209, -122.332071, "Low"),
    (3,  "CA", "Canada",         "North America", "Toronto",   43.653226,  -79.383184, "Low"),
    (4,  "GB", "United Kingdom", "EMEA",          "London",    51.507351,   -0.127758, "Low"),
    (5,  "DE", "Germany",        "EMEA",          "Berlin",    52.520007,   13.404954, "Low"),
    (6,  "BR", "Brazil",         "LATAM",         "Sao Paulo", -23.550520, -46.633309, "Medium"),
    (7,  "IN", "India",          "APAC",          "Mumbai",     19.075984,  72.877656, "Medium"),
    (8,  "PH", "Philippines",    "APAC",          "Manila",     14.599512, 120.984219, "Medium"),
    (9,  "NG", "Nigeria",        "EMEA",          "Lagos",       6.524379,   3.379206, "High"),
    (10, "RU", "Russia",         "EMEA",          "Moscow",     55.755826,  37.617300, "High"),
]

# id, name, price, period, is_paid, trial_days, ads, effective
PLAN = [
    (1,  "Free",            0.00, "None",    0,  0, 1, "2026-01-01"),
    (2,  "Plus Monthly",    4.99, "Monthly", 1,  7, 0, "2026-01-01"),
    (3,  "Plus Annual",    49.99, "Annual",  1, 14, 0, "2026-01-01"),
    (4,  "Premium Monthly", 9.99, "Monthly", 1,  7, 0, "2026-01-01"),
    (5,  "Premium Annual", 99.99, "Annual",  1, 14, 0, "2026-01-01"),
    (6,  "Student Monthly", 2.99, "Monthly", 1, 30, 0, "2026-02-01"),
    (7,  "Family Monthly", 14.99, "Monthly", 1, 14, 0, "2026-03-01"),
    (8,  "Founders Annual",19.99, "Annual",  1,  0, 0, "2026-01-01"),
    (9,  "Trial",           0.00, "None",    0, 14, 1, "2026-01-01"),
    (10, "Legacy Basic",    2.99, "Monthly", 1,  0, 1, "2025-06-01"),
]
PLAN_PRICE = {p[0]: p[2] for p in PLAN}
PLAN_PERIOD = {p[0]: p[3] for p in PLAN}

# id, name, category, price, active, release
PRODUCT = [
    (1,  "Small Gem Pack",       "Currency",     1.99, 1, "2026-01-15"),
    (2,  "Medium Gem Pack",      "Currency",     4.99, 1, "2026-01-15"),
    (3,  "Large Gem Pack",       "Currency",    19.99, 1, "2026-01-15"),
    (4,  "Starter Bundle",       "Currency",     9.99, 1, "2026-02-01"),
    (5,  "Shadow Skin",          "Cosmetic",     3.99, 1, "2026-03-10"),
    (6,  "Dragon Armor",         "Cosmetic",     7.99, 1, "2026-04-01"),
    (7,  "Emote Pack",           "Cosmetic",     2.99, 0, "2026-02-20"),
    (8,  "Season 1 Battle Pass", "BattlePass",   9.99, 0, "2026-05-01"),
    (9,  "Season 2 Battle Pass", "BattlePass",   9.99, 1, "2026-08-01"),
    (10, "Premium Upgrade",      "Subscription", 9.99, 1, "2026-01-15"),
]
PRODUCT_PRICE = {p[0]: p[3] for p in PRODUCT}

# id, name, channel, cost model, start, end, budget
CAMPAIGN = [
    (1,  "Launch Search US",   "Paid Search", "CPC", "2026-07-01", None,         25000.00),
    (2,  "Launch Search EU",   "Paid Search", "CPC", "2026-07-01", "2026-09-30", 15000.00),
    (3,  "Summer Social Push", "Social",      "CPM", "2026-07-15", "2026-09-15", 18000.00),
    (4,  "Influencer Wave 1",  "Influencer",  "CPI", "2026-08-01", "2026-09-30", 30000.00),
    (5,  "Influencer Wave 2",  "Influencer",  "CPI", "2026-09-15", None,         22000.00),
    (6,  "Email Winback Q3",   "Email",       "CPC", "2026-08-15", None,          5000.00),
    (7,  "Retargeting APAC",   "Social",      "CPM", "2026-08-01", None,         12000.00),
    (8,  "Video Preroll",      "Social",      "CPM", "2026-07-20", "2026-10-01", 20000.00),
    (9,  "App Store Feature",  "Paid Search", "CPI", "2026-09-01", None,          8000.00),
    (10, "Referral Boost",     "Email",       "CPC", "2026-10-01", None,          3000.00),
]

DEVICES = ["iOS", "Android", "PC", "Console"]
SOURCE_EVENT = ["GameClient", "MobileSDK", "WebClient"]
SOURCE_BILL = ["BillingAPI", "AppStore", "PlayStore"]
METHODS = ["Card", "PayPal", "AppStore", "GooglePlay"]

# ------------------------------------------------------------------- users
# One per geography, so every row of DimGeography is actually referenced
# and the fraud view has genuinely distant pairs to compare.
# id, signup, reg geo, age band, device, stage, acq campaign, acq cost
USERS = [
    (1,  date(2026, 3, 12),  1, "25-34", "PC",      "Active", 1,    6.40),
    (2,  date(2026, 5,  4),  2, "18-24", "iOS",     "Active", 3,    2.15),
    (3,  date(2026, 6, 18),  3, "35-49", "Console", "AtRisk", None, None),
    (4,  date(2026, 7,  2),  4, "25-34", "Android", "AtRisk", 2,    4.80),
    (5,  date(2026, 8, 11),  5, "50+",   "PC",      "Active", 8,    3.25),
    (6,  date(2026, 9,  1),  6, "18-24", "Android", "AtRisk", 4,   11.90),
    (7,  date(2026, 9, 20),  7, "13-17", "iOS",     "Active", 7,    1.35),
    (8,  date(2026, 10, 2),  8, "18-24", "Android", "Active", 5,    9.60),
    (9,  date(2026, 10, 8),  9, "25-34", "iOS",     "New",    9,   14.20),
    (10, date(2026, 10, 14), 10, "35-49", "PC",     "New",    10,   2.75),
]

# ---------------------------------------------------------------- accounts
# Ten accounts over ten users, deliberately not one apiece: user 1 holds a
# second, older, cancelled account and user 10 holds none. That is the whole
# reason DimAccount carries its own key instead of hanging off DimUser.
#
# PlanID is the plan the account is on NOW. Where FactSubscription records an
# upgrade or a downgrade, the plan here is the one that move landed on.
# id, user, plan, status, opened, closed, auto renew
ACCOUNTS = [
    (1,  1, 4, "Active",    date(2026, 3, 14),  None,              1),
    (2,  1, 2, "Cancelled", date(2025, 11, 1),  date(2026, 3, 10), 0),
    (3,  2, 1, "Active",    date(2026, 5, 5),   None,              0),
    (4,  3, 5, "Active",    date(2026, 6, 20),  None,              1),
    (5,  4, 1, "Active",    date(2026, 7, 3),   None,              0),
    (6,  5, 2, "Active",    date(2026, 8, 12),  None,              1),
    (7,  6, 2, "Active",    date(2026, 9, 2),   None,              1),
    (8,  7, 6, "PastDue",   date(2026, 9, 21),  None,              1),
    (9,  8, 1, "Active",    date(2026, 10, 3),  None,              0),
    (10, 9, 5, "Active",    date(2026, 10, 9),  None,              1),
]

# -------------------------------------------------------------- user events
# Twelve sessions across nine active days. Days with two and three distinct
# players are deliberate: a daily active user count that is 1 every day is
# not a time series, and view 1 would demonstrate nothing.
#
# Each session is (day, user, geo override, [actions]), and each action is
# (event type, level, outcome). The level outcomes are laid out so the
# cursor in section 8 has something to find - level 5 is lost three times
# out of four, which is the churn risk it reports.
SESSIONS = [
    (date(2026, 9, 27),  1, None, [("LevelComplete", 1, "Win"),
                                   ("LevelComplete", 2, "Win")]),
    (date(2026, 9, 29),  3, None, [("LevelComplete", 1, "Win"),
                                   ("LevelComplete", 3, "Win")]),
    (date(2026, 10, 2),  2, None, [("LevelFail",     2, "Loss"),
                                   ("ItemUsed",      2, None)]),
    (date(2026, 10, 5),  1, None, [("LevelComplete", 3, "Win"),
                                   ("LevelComplete", 4, "Win")]),
    (date(2026, 10, 5),  4, None, [("LevelComplete", 1, "Win"),
                                   ("LevelFail",     4, "Loss")]),
    (date(2026, 10, 9),  6, None, [("LevelFail",     5, "Loss"),
                                   ("AdWatched",  None, None)]),
    (date(2026, 10, 12), 2, None, [("LevelComplete", 2, "Win"),
                                   ("LevelFail",     5, "Loss")]),
    # Playing from London while registered in Berlin - a real trip, which
    # is why it moves LastSeenGeoID and not the fraud flag.
    (date(2026, 10, 12), 5, 4,    [("LevelComplete", 4, "Win"),
                                   ("LevelComplete", 5, "Win")]),
    (date(2026, 10, 12), 7, None, [("LevelFail",     3, "Abandon"),
                                   ("LevelFail",     5, "Loss")]),
    (date(2026, 10, 17), 8, None, [("LevelComplete", 1, "Win"),
                                   ("LevelComplete", 6, "Win")]),
    (date(2026, 10, 20), 1, None, [("LevelFail",     4, "Loss"),
                                   ("ItemUsed",      4, None)]),
    (date(2026, 10, 23), 9, None, [("LevelFail",     6, "Abandon"),
                                   ("AdWatched",  None, None)]),
]

# ------------------------------------------------------------ store sales
# (account, product, date, discount multiplier)
ONE_TIME = [
    (1,  2, date(2026, 9, 28),  1.0),
    (1,  5, date(2026, 10, 6),  1.0),
    (1,  9, date(2026, 10, 21), 1.0),
    (3,  1, date(2026, 10, 2),  1.0),
    (3,  4, date(2026, 10, 12), 0.7),      # a promo code was applied
    (3,  2, date(2026, 10, 19), 1.0),
    (4,  3, date(2026, 9, 29),  1.0),
    (4,  6, date(2026, 10, 8),  1.0),
    (5,  1, date(2026, 10, 5),  1.0),
    (5,  5, date(2026, 10, 15), 1.0),
    (6,  2, date(2026, 9, 27),  1.0),
    (6,  9, date(2026, 10, 12), 1.0),
    (6,  1, date(2026, 10, 22), 1.0),
    (7,  4, date(2026, 10, 9),  1.0),
    (7,  5, date(2026, 10, 18), 1.0),
    (8,  1, date(2026, 10, 12), 1.0),
    (8,  2, date(2026, 10, 20), 1.0),
    (9,  3, date(2026, 10, 17), 1.0),
    (9,  6, date(2026, 10, 23), 1.0),
    (10, 9, date(2026, 10, 23), 1.0),
]

# Recurring charges that fall inside the window, at the plan the account is
# on now. Annual plans only bill on their anniversary, so only the one that
# opened inside the window appears. (account, date)
RECURRING = [
    (1,  date(2026, 10, 14)),   # Premium Monthly, billed on the 14th
    (6,  date(2026, 10, 12)),   # Plus Monthly, first charge after downgrade
    (7,  date(2026, 10, 16)),   # Plus Monthly, first charge after trial
    (8,  date(2026, 10, 21)),   # Student Monthly, the charge that went PastDue
    (10, date(2026, 10, 9)),    # Premium Annual, charged on opening
]

# (account, product, original date, refund date)
REFUNDS = [
    (1, 5, date(2026, 10, 6),  date(2026, 10, 9)),
    (7, 4, date(2026, 10, 9),  date(2026, 10, 13)),
]

# Planted so the fraud view has something real to find. Each one is a normal
# row in every respect except its geography, which disagrees with where the
# account holder was last seen minutes earlier.
# (account, product, geo, minutes after that user's last session, amount)
SUSPICIOUS = [
    (1, 3,  9, 40,  149.99),    # Phoenix to Lagos in forty minutes
    (4, 3, 10, 55,   89.99),    # Toronto to Moscow in under an hour
    (9, 9,  9, 70,  119.99),    # Manila to Lagos in seventy minutes
]

# --------------------------------------------------------- subscriptions
# The lifecycle, including the moves that carry no money. Dates before the
# window are kept: a subscription that started in March is why the account
# exists, and dropping it would make the Renew rows look unexplained.
# (account, plan, prev plan, type, date, term months, cancel reason)
SUBS = [
    (2,  2, None, "Start",     date(2025, 11, 1),  1,    None),
    (2,  2, None, "Cancel",    date(2026, 3, 10),  None, "Too expensive"),
    (1,  4, None, "Start",     date(2026, 3, 14),  1,    None),
    (1,  4, None, "Renew",     date(2026, 4, 14),  1,    None),
    (1,  4, None, "Renew",     date(2026, 5, 14),  1,    None),
    (1,  4, None, "Renew",     date(2026, 6, 14),  1,    None),
    (1,  4, None, "Renew",     date(2026, 7, 14),  1,    None),
    (1,  4, None, "Renew",     date(2026, 8, 14),  1,    None),
    (1,  4, None, "Renew",     date(2026, 9, 14),  1,    None),
    (1,  4, None, "Renew",     date(2026, 10, 14), 1,    None),
    (3,  1, None, "Start",     date(2026, 5, 5),   None, None),
    (4,  3, None, "Start",     date(2026, 6, 20),  12,   None),
    (4,  5, 3,    "Upgrade",   date(2026, 8, 20),  12,   None),
    (5,  1, None, "Start",     date(2026, 7, 3),   None, None),
    (6,  7, None, "Start",     date(2026, 8, 12),  1,    None),
    (6,  7, None, "Renew",     date(2026, 9, 12),  1,    None),
    (6,  2, 7,    "Downgrade", date(2026, 10, 12), 1,    None),
    (7,  9, None, "Start",     date(2026, 9, 2),   None, None),
    (7,  2, 9,    "Upgrade",   date(2026, 10, 16), 1,    None),
    (8,  6, None, "Start",     date(2026, 9, 21),  1,    None),
    (8,  6, None, "Renew",     date(2026, 10, 21), 1,    None),
    (9,  1, None, "Start",     date(2026, 10, 3),  None, None),
    (10, 5, None, "Start",     date(2026, 10, 9),  12,   None),
]


def q(s):
    """Single-quote a string for T-SQL."""
    return "'" + str(s).replace("'", "''") + "'"


def nz(v):
    return "NULL" if v is None else str(v)


def nq(v):
    return "NULL" if v is None else q(v)


def money(v):
    return "NULL" if v is None else f"{v:.2f}"


def ts(dt):
    return q(dt.strftime("%Y-%m-%d %H:%M:%S"))


# -------------------------------------------------------------------- build
users = [{
    "id": u[0], "username": f"player{u[0]:03d}",
    "email": f"player{u[0]:03d}@example.com",
    "signup": u[1], "reg_geo": u[2], "age": u[3], "device": u[4],
    "stage": u[5], "camp": u[6], "cost": u[7],
    "last_geo": None, "last_at": None,
} for u in USERS]
user_by_id = {u["id"]: u for u in users}

accounts = [{
    "id": a[0], "user": a[1], "number": f"ACC-{a[0]:05d}", "plan": a[2],
    "status": a[3], "opened": a[4], "closed": a[5], "renew": a[6],
    "geo": user_by_id[a[1]]["reg_geo"],
} for a in ACCOUNTS]
acct_by_id = {a["id"]: a for a in accounts}

# ---- the event stream, one session at a time
events = []
for sid, (day, uid, geo_override, actions) in enumerate(SESSIONS, start=1):
    u = user_by_id[uid]
    geo = geo_override or u["reg_geo"]
    dev = u["device"] if rng.random() < 0.8 else rng.choice(DEVICES)
    src = rng.choices(SOURCE_EVENT, weights=[62, 30, 8])[0]
    t = datetime.combine(day, time()) + timedelta(
        hours=rng.randint(7, 22), minutes=rng.randint(0, 59),
        seconds=rng.randint(0, 59))
    events.append((uid, sid, geo, "SessionStart", t, None, None, dev, src))
    for kind, lvl, outcome in actions:
        t += timedelta(minutes=rng.randint(2, 14), seconds=rng.randint(0, 59))
        events.append((uid, sid, geo, kind, t, lvl, outcome, dev, src))
    t += timedelta(minutes=rng.randint(1, 9), seconds=rng.randint(0, 59))
    events.append((uid, sid, geo, "SessionEnd", t, None, None, dev, src))
    # The last session wins, which is what LastSeen* means.
    u["last_at"], u["last_geo"] = t, geo

# ---- payments
payments = []
for aid, day in RECURRING:
    a = acct_by_id[aid]
    u = user_by_id[a["user"]]
    payments.append({
        "acct": aid, "prod": None, "camp": u["camp"], "geo": u["reg_geo"],
        "ts": datetime.combine(day, time()) + timedelta(
            hours=rng.randint(0, 23), minutes=rng.randint(0, 59)),
        "amt": PLAN_PRICE[a["plan"]], "type": "Subscription",
        "method": rng.choice(METHODS), "flag": 0,
        "src": rng.choices(SOURCE_BILL, weights=[55, 28, 17])[0],
    })

for aid, pid, day, mult in ONE_TIME:
    u = user_by_id[acct_by_id[aid]["user"]]
    payments.append({
        "acct": aid, "prod": pid, "camp": u["camp"], "geo": u["reg_geo"],
        "ts": datetime.combine(day, time()) + timedelta(
            hours=rng.randint(8, 23), minutes=rng.randint(0, 59)),
        "amt": round(PRODUCT_PRICE[pid] * mult, 2), "type": "OneTime",
        "method": rng.choice(METHODS), "flag": 0,
        "src": rng.choices(SOURCE_BILL, weights=[40, 35, 25])[0],
    })

for aid, pid, _orig, day in REFUNDS:
    u = user_by_id[acct_by_id[aid]["user"]]
    payments.append({
        "acct": aid, "prod": pid, "camp": u["camp"], "geo": u["reg_geo"],
        "ts": datetime.combine(day, time()) + timedelta(
            hours=rng.randint(8, 20), minutes=rng.randint(0, 59)),
        "amt": PRODUCT_PRICE[pid], "type": "Refund",
        "method": rng.choice(METHODS), "flag": 0,
        "src": rng.choices(SOURCE_BILL, weights=[40, 35, 25])[0],
    })

for aid, pid, geo, mins, amt in SUSPICIOUS:
    u = user_by_id[acct_by_id[aid]["user"]]
    assert u["last_at"], f"user {u['id']} never played, cannot be followed"
    payments.append({
        "acct": aid, "prod": pid, "camp": None, "geo": geo,
        "ts": u["last_at"] + timedelta(minutes=mins),
        "amt": amt, "type": "OneTime",
        "method": rng.choice(["Card", "PayPal"]), "flag": 0,
        "src": "BillingAPI",
    })

payments.sort(key=lambda p: p["ts"])

# ---- subscription lifecycle. MRR delta is derived, not typed, so it can
# never disagree with the plan prices above.
subs = []
for aid, plan, prev, kind, day, term, reason in SUBS:
    price = PLAN_PRICE[plan]
    monthly = price if PLAN_PERIOD[plan] == "Monthly" else price / 12.0
    if kind in ("Start", "Upgrade", "Downgrade"):
        prev_monthly = 0.0
        if prev is not None:
            prev_price = PLAN_PRICE[prev]
            prev_monthly = (prev_price if PLAN_PERIOD[prev] == "Monthly"
                            else prev_price / 12.0)
        mrr = monthly - prev_monthly
    elif kind in ("Cancel", "Expire"):
        mrr = -monthly
    else:                                   # a renewal changes nothing
        mrr = 0.0
    subs.append({
        "acct": aid, "plan": plan, "prev": prev, "type": kind, "date": day,
        "mrr": round(mrr, 2), "term": term, "reason": reason,
    })
subs.sort(key=lambda s: (s["date"], s["acct"]))

# ---- guardrails. These are the properties the rest of the script depends
# on, so they are asserted here rather than discovered in a failing test.
assert len(users) == 10 and len(accounts) == 10
for name, rows in (("FactUserEvent", events), ("FactPayment", payments),
                   ("FactSubscription", subs)):
    assert 20 <= len(rows) <= 50, f"{name} has {len(rows)}, needs 20-50"
open_accts = [a for a in accounts if a["closed"] is None]
assert {PLAN[a["plan"] - 1][4] for a in open_accts} == {0, 1}, \
    "view 2 needs both a free and a paid open account"
months = {(e[4].year, e[4].month) for e in events}
assert len(months) >= 2, "the procedure needs more than one month of activity"

# ------------------------------------------------------------------ emit SQL
def insert_block(table, columns, rows, chunk=250):
    out = []
    for i in range(0, len(rows), chunk):
        part = rows[i:i + chunk]
        out.append(f"INSERT INTO dbo.{table}\n    ({columns})\nVALUES")
        out.append(",\n".join("  " + r for r in part) + ";")
        out.append("GO")
        out.append("")
    return out


L = []
A = L.append
A("/* ======================================================================")
A("   SECTION 4: POPULATE")
A("")
A("   Rows are literal INSERT statements so the script is self-contained,")
A("   but they were produced by tools/gendata.py with a fixed seed, which")
A("   is why the data is reproducible and why the numbers below are stable.")
A("")
A("   Volumes follow the assignment: 10 rows in every dimension table, and")
A("   20-50 rows in each transactional table.")
A("")
A(f"   Window: {WINDOW_START} to {WINDOW_END} ({WINDOW_DAYS} days), which")
A("   spans two calendar months so the monthly procedure has more than one")
A("   row to return.")
A("")
A(f"   DimGeography {len(GEO)}, DimPlan {len(PLAN)}, DimProduct"
  f" {len(PRODUCT)}, DimCampaign {len(CAMPAIGN)},")
A(f"   DimUser {len(users)}, DimAccount {len(accounts)},"
  f" FactUserEvent {len(events)},")
A(f"   FactPayment {len(payments)}, FactSubscription {len(subs)}.")
A("")
A("   No deletes are needed here: section 2 drops every table and section")
A("   3 rebuilds them, so this section always loads into empty tables.")
A("   Inserts run parent-first, because a foreign key is checked per row.")
A("   ====================================================================== */")
A("")
A("/* ---- DimGeography: every place, and how risky it is ---------------- */")
L.extend(insert_block(
    "DimGeography",
    "GeoID, CountryCode, CountryName, Region, City,\n     Latitude, Longitude, RiskTier",
    [f"({g[0]},{q(g[1])},{q(g[2])},{q(g[3])},{q(g[4])},"
     f"{g[5]},{g[6]},{q(g[7])})" for g in GEO]))

A("/* ---- DimPlan: the audited lookup table ----------------------------- */")
L.extend(insert_block(
    "DimPlan",
    "PlanID, PlanName, PriceUSD, BillingPeriod, IsPaid,\n     TrialDays, AdsEnabled, EffectiveDate",
    [f"({p[0]},{q(p[1])},{p[2]:.2f},{q(p[3])},{p[4]},{p[5]},{p[6]},{q(p[7])})"
     for p in PLAN]))

A("/* ---- DimProduct: the store catalog --------------------------------- */")
L.extend(insert_block(
    "DimProduct",
    "ProductID, ProductName, ProductCategory, ListPriceUSD,\n     IsActive, ReleaseDate",
    [f"({p[0]},{q(p[1])},{q(p[2])},{p[3]:.2f},{p[4]},{q(p[5])})"
     for p in PRODUCT]))

A("/* ---- DimCampaign: what marketing ran, and what it cost ------------- */")
L.extend(insert_block(
    "DimCampaign",
    "CampaignID, CampaignName, Channel, CostModel,\n     StartDate, EndDate, BudgetUSD",
    [f"({c[0]},{q(c[1])},{q(c[2])},{q(c[3])},{q(c[4])},{nq(c[5])},{c[6]:.2f})"
     for c in CAMPAIGN]))

A("/* ---- DimUser: the customer profile every report slices on ---------- */")
L.extend(insert_block(
    "DimUser",
    "UserID, Username, Email, SignupDate, RegisteredGeoID,\n"
    "     LastSeenGeoID, LastSeenAt, AgeBand, PreferredDevice,\n"
    "     LifecycleStage, AcqCampaignID, AcqCostUSD",
    [f"({u['id']},{q(u['username'])},{q(u['email'])},{q(u['signup'])},\n"
     f"   {u['reg_geo']},{nz(u['last_geo'])},"
     f"{ts(u['last_at']) if u['last_at'] else 'NULL'},"
     f"{q(u['age'])},\n"
     f"   {q(u['device'])},{q(u['stage'])},"
     f"{nz(u['camp'])},{money(u['cost'])})"
     for u in users]))

A("/* ---- DimAccount: the billing entity -------------------------------- */")
L.extend(insert_block(
    "DimAccount",
    "AccountID, UserID, AccountNumber, PlanID, AccountStatus,\n"
    "     OpenedDate, ClosedDate, IsAutoRenew, BillingGeoID",
    [f"({a['id']},{a['user']},{q(a['number'])},{a['plan']},{q(a['status'])},"
     f"{q(a['opened'])},{nq(a['closed'])},{a['renew']},{a['geo']})"
     for a in accounts]))

A("/* ---- FactUserEvent: sessions and in-game actions, one stream ------- */")
L.extend(insert_block(
    "FactUserEvent",
    "UserID, SessionID, GeoID, EventType, EventTS,\n"
    "     LevelNumber, Outcome, DeviceType, SourceSystem",
    [f"({e[0]},{e[1]},{e[2]},{q(e[3])},{ts(e[4])},{nz(e[5])},{nq(e[6])},"
     f"{q(e[7])},{q(e[8])})" for e in events], chunk=500))

A("/* ---- FactPayment: sales, subscription charges and refunds ---------- */")
L.extend(insert_block(
    "FactPayment",
    "AccountID, ProductID, CampaignID, GeoID, PaymentTS,\n"
    "     AmountUSD, PaymentType, PaymentMethod, IsFlagged, SourceSystem",
    [f"({p['acct']},{nz(p['prod'])},{nz(p['camp'])},{p['geo']},"
     f"{q(p['ts'].strftime('%Y-%m-%d %H:%M'))},{p['amt']:.2f},"
     f"{q(p['type'])},{q(p['method'])},{p['flag']},{q(p['src'])})"
     for p in payments]))

A("/* ---- FactSubscription: the lifecycle, including the free moves ----- */")
L.extend(insert_block(
    "FactSubscription",
    "AccountID, PlanID, PrevPlanID, EventType, EventDate,\n"
    "     MRRDeltaUSD, TermMonths, CancelReason, SourceSystem",
    [f"({s['acct']},{s['plan']},{nz(s['prev'])},{q(s['type'])},"
     f"{q(s['date'])},{s['mrr']:.2f},{nz(s['term'])},{nq(s['reason'])},"
     f"{q(rng.choice(SOURCE_BILL))})" for s in subs]))

OUT.write_text("\n".join(L) + "\n")

print(f"wrote {OUT}")
for label, n in (("DimGeography", len(GEO)), ("DimPlan", len(PLAN)),
                 ("DimProduct", len(PRODUCT)), ("DimCampaign", len(CAMPAIGN)),
                 ("DimUser", len(users)), ("DimAccount", len(accounts)),
                 ("FactUserEvent", len(events)), ("FactPayment", len(payments)),
                 ("FactSubscription", len(subs))):
    print(f"  {label:<18}{n:>4}")
print(f"  {'sessions':<18}{len(SESSIONS):>4}")
print(f"  {'active days':<18}{len({s[0] for s in SESSIONS}):>4}")
print(f"  {'months covered':<18}{len(months):>4}")
