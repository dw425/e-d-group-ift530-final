# IFT 530 Final Project — Player Analytics for an Online Game

**Group:** E & D Group &nbsp;·&nbsp; **Members:** Ethan Oxley, Daniel Warren
&nbsp;·&nbsp; **Database:** `E_D_Group`

> **Finishing the project?** [`finish.md`](finish.md) is the runbook —
> every remaining step with the exact command for each, driven by
> `./tools/finish.sh`.

Two separately graded deliverables:

| Deliverable | Marks | Status |
|---|---|---|
| Final Project Summary — description + table specs | 50 | **done** |
| Final Project — SQL script | 150 | **script done and verified**; screenshots + ERD outstanding |

## Files

| File | What it is |
|---|---|
| `build_summary.py` | Builds the Summary doc. **Source of truth for every column and constraint name.** |
| `build.py` | Builds the Final Project doc. Slices listings out of the `.sql` so the two cannot drift. |
| `IFT530_EDGroup_FinalProject.sql` | The combined deliverable, assembled from `parts/`. |
| `IFT530_EDGroup_FinalProject.txt` | Byte-identical twin (Canvas rejects `.sql`). |
| `parts/*.sql` | The script in nine sections while it is being written. |
| `tools/gendata.py` | Seeded data generator → `parts/40_populate.sql`. Not submitted. |
| `tools/assemble.py` | Joins `parts/` into the `.sql` and `.txt`. |
| `tools/figs.sh` | Produces one figure's worth of output. |
| `finish.md` | The runbook for everything still outstanding. |
| `tools/finish.sh` | Drives it: `check`, `shots`, `build`, `publish`, `all`. |
| `tools/sync_repo.sh` | Copies the deliverables into the public repo and pushes. |
| `docs/SCREENSHOTS.md` | The twelve-figure capture checklist. |
| `docs/erd.html` | Self-contained interactive ERD. |
| `docs/design_spec.html` | One-page design spec. |
| `parts/README.md` | What each section of the script does, and why each view earns its place. |
| `database/E_D_Group.bak` | A restorable backup of the built, populated database. |
| `database/DATA_DICTIONARY.md` | Every column and constraint, read out of the live catalog. |
| `tools/dbdoc.py` | Generates that dictionary from the running server. |

## Rebuild

    source .env && ./tools/mssql.sh start          # from the repo root
    /usr/local/bin/python3 tools/gendata.py        # only if the data changes
    /usr/local/bin/python3 tools/assemble.py
    sqlcmd -S localhost,1433 -U sa -C -i IFT530_EDGroup_FinalProject.sql
    /usr/local/bin/python3 build.py

`python3` must be the python.org 3.13 build — Homebrew's has no `python-docx`.

`tools/mssql.sh` lives in the course repo root and is not part of the public
mirror. From a standalone checkout, point `sqlcmd` at any SQL Server 2025
instance; the script creates its own database and needs nothing else.

**Never edit the `.sql` directly.** It is assembled from `parts/`; an edit there
is lost on the next assemble. Edit the part, then re-assemble.

## Verified

Run three times in a row, clean each time: **13 PASS, 0 FAIL**, zero errors.
Out of the catalog views, on user tables only: 10 tables, 10 primary keys,
3 unique constraints, 15 foreign keys, 32 check constraints, 7 defaults,
6 nonclustered indexes, 4 identity columns, 3 views, 1 procedure, 1 scalar
function, 1 trigger. `.sql` and `.txt` confirmed byte-identical with `cmp`.

Loaded data, at the volumes the assignment asks for — 10 rows in every
dimension, 20–50 in every transactional table: 10 users, 10 accounts,
48 events, 30 payments, 23 subscription events, across 12 sessions in a
30-day window. DAU runs 1–3 over 9 active days; 2 months for MAU; 6 paid
open accounts against 3 free; 5 of 30 payments flagged by the fraud view;
level 5 flagged as a churn risk at a 25% win rate.

## Schema — 10 tables, the cap exactly

    DimGeography  DimPlan  DimProduct  DimCampaign     no outbound FKs
      -> DimUser                                       person, 10 rows
           -> DimAccount                               billing entity, 10 rows
                -> FactUserEvent       48              sessions + in-game
                -> FactPayment         30              sales, subs, refunds
                -> FactSubscription    23              MRR lifecycle
    DimPlanAudit                                       written by trigger only

**`DimGeography` is a role-playing dimension, referenced five times** —
`DimUser.RegisteredGeoID`, `DimUser.LastSeenGeoID`, `DimAccount.BillingGeoID`,
`FactUserEvent.GeoID`, `FactPayment.GeoID`. That is what makes the fraud view
possible. `DimPlan` is referenced three times, the third being
`FactSubscription.PrevPlanID`, which distinguishes an upgrade from a downgrade.

## Decisions worth remembering

- **`FactMarketingClick` was cut** to land on exactly 10 tables. `DimCampaign`
  survives and `DimUser` carries `AcqCampaignID` + `AcqCostUSD`, so CAC still
  computes. What is gone is the unconverted click.
- **Sessions and in-game actions share one table.** `SessionID` is a degenerate
  dimension; session length is the span of events carrying the same value.
- **Row counts follow the spec: 10 per dimension, 20–50 per fact table.** An
  earlier draft carried 60 users and 3,343 events because small data makes a
  time series flat; that was wrong against the stated requirement and 20 marks
  ride on it. The data is now laid out by hand instead — the window crosses a
  month boundary, sessions cluster on 9 days with 2–3 players on some of them,
  level 5 loses 3 of 4, and 3 payments are planted far from their account
  holder. `tools/gendata.py` asserts each of those before emitting a single
  INSERT, because at 10 users a random draw misses them.
- **`DimPlanAudit` has no FK to `DimPlan`** — a DELETE audit row must outlive
  the row it describes.
- **The audit rows do not survive a re-run**, because section 2 drops the table
  with everything else. A real deployment would create it once and never drop
  it; that is the one way this script differs from how it would ship.
- **The cursor is `GLOBAL` on purpose** so `DECLARE` and `DEALLOCATE` are the
  "create and drop scripts" the assignment asks for. T-SQL has no CREATE CURSOR.
- **`fnGeoDistanceKm` returns NULL, not 0,** when either location is unknown.
- **`MinsSinceLastSeen` is NULL when the payment predates the last session.**
  `LastSeenAt` is the person's most recent session, not the last one before that
  payment — correct for a live screen, backwards over history. Fixing it
  properly costs a correlated subquery per row.
- **"Null value is eliminated by an aggregate" is expected output**, from
  `COUNT(DISTINCT CASE WHEN … END)` in view 1 and the procedure. NULLs being
  skipped is the mechanism that makes a conditional distinct count work.
  Commented in both places.
- **FK constraint names are short** (`FK_Event_Geo`). Long forms overflowed the
  Constraint column in the Summary's spec tables and broke mid-word in the PDF.

## Gotchas hit while building this

- `column -t -s'|'` pads every row to the width of SQL Server's warning line,
  which carries no `|`. `figs.sh` filters warnings out of the alignment and
  prints them after the table.
- `RIGHT()` does not pad — the prefix must be at least as wide as the field, or
  short values come back short and the cursor's columns drift.
- Dimension keys are explicit so the generated inserts can reference them; fact
  keys are IDENTITY, so the generator omits those columns entirely.

## Public repo

Everything here except secrets is mirrored to a public repo for the group:

    ./tools/sync_repo.sh        # copy, commit and push

## Still to do

**Twelve screenshots, then `build.py`.** That is the only thing between
this and a finished submission. The full checklist — what each figure has to
show, and how to get the ERD out of the VS Code extension — is in
`docs/SCREENSHOTS.md`. `build.py` reads `screenshots/fig1_env.png` through
`fig12_rerun.png` by exact name and will not build until all twelve exist.
