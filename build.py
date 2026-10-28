#!/usr/bin/env python3
"""Build IFT530_EDGroup_FinalProject.docx.

Content only. Formatting lives in tools/docbuild.py.

Code listings are sliced out of the submitted .sql file, so the document and
the script cannot drift apart. Every number quoted here was read off the
captures in screenshots/, which are the combined script actually running.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "tools"))
sys.path.insert(0, str(HERE / "tools"))  # standalone checkout

from docbuild import Paper  # noqa: E402

NAME = "IFT530_EDGroup_FinalProject"
SQL = (HERE / f"{NAME}.sql").read_text().split("\n")
SHOT = "screenshots/"

GROUP_NAME = "E & D Group"
DB_NAME = "E_D_Group"
GROUP_MEMBERS = "Ethan Oxley, Daniel Warren"


def grab(start, end="GO"):
    """Slice a statement out of the .sql, from a line prefix to its GO."""
    a = next(i for i, l in enumerate(SQL) if l.startswith(start))
    b = next(i for i in range(a, len(SQL)) if SQL[i].strip() == end)
    return "\n".join(SQL[a:b]).rstrip()


def span(start, stop):
    """Slice from one line prefix up to (not including) another.

    grab() stops at the first GO, which is no use for the audit test: the
    insert, the update and the delete are three separate batches.
    """
    a = next(i for i, l in enumerate(SQL) if l.startswith(start))
    b = next(i for i in range(a + 1, len(SQL)) if SQL[i].startswith(stop))
    return "\n".join(SQL[a:b]).rstrip()


def main():
    p = Paper(out=HERE / f"{NAME}.docx", base=HERE)
    p.title_page(
        "Final Project: Player Analytics for an Online Game",
        course="IFT 530: Advanced Database Management Systems",
        instructor="Ashish Gulati",
        date="October 27, 2026",
        author=f"Group: {GROUP_NAME}   |   Group Members: {GROUP_MEMBERS}",
    )

    def code(text, size=8):
        p.code(text, size=size)
        p._para("", after=8, line=1.0)

    # ---------------------------------------------------------- overview
    p.h1("What This Project Is")
    p.body(
        "This is the database behind a live, free-to-play online game — not the "
        "game, the system the business runs it from. Ten tables: six dimensions "
        "describing the customer from different angles, three fact tables "
        "recording what happened, and one audit table holding the change history "
        "of the plan lookup.")
    p.body(
        "The design question behind it is that a game like this earns nothing at "
        "the moment somebody installs it. It earns weeks later, from a fraction "
        "of players who decide it is worth paying for, and it only reaches those "
        "players by buying their attention first. So the questions worth asking "
        "span areas usually kept apart: who the customer is, what they did, what "
        "they pay, and whether the payment should be trusted. The schema is built "
        "to make the joins between those areas cheap and unambiguous.")
    p.body(
        f"Everything is in one script, {NAME}.sql, submitted as a .txt as the "
        "announcement requires. It creates the database, drops and rebuilds every "
        "object, loads the data, creates three views, a trigger, a function, a "
        "procedure and a cursor, and finishes with a block of tests that report "
        "PASS or FAIL. It is re-runnable: running it three times in a row "
        "produces the same objects, the same row counts and the same results.")

    p.h1("Environment")
    p.body(
        "SQL Server has no native macOS build, so the server here is Microsoft's "
        "official Linux container running under Docker — SQL Server 2025 "
        "Developer Edition, the full product, not a reduced one. The assignment "
        "asks for screenshots from SSMS or Azure Data Studio. SSMS is Windows "
        "only and Microsoft retired Azure Data Studio in February 2026, so the "
        "work was done with sqlcmd and the VS Code MSSQL extension, which is the "
        "same codebase Azure Data Studio was built from. The entity relationship "
        "diagram is drawn by tools/erd_html.py from the schema the script "
        "creates, and it is checked back against the live catalog views before "
        "it goes in, so the relationships it shows are the real foreign key "
        "constraints rather than something drawn by hand.")
    p.figure(SHOT + "fig1_env.png",
             "The environment the script was run against: the SQL Server 2025 "
             "container running under Docker, and the server version it "
             "reports. The header block required on every submitted "
             "file is shown above the output.")

    # ------------------------------------------------- 1. create tables
    p.h1("Requirement 1: Create the Tables (40 marks)")
    p.body(
        "Ten tables, created parent-first so every foreign key points at a table "
        "that already exists. The four tables with no foreign keys of their own "
        "come first, then DimUser, then DimAccount, then the three fact tables. "
        "There are no circular references, which also means the drop order in "
        "section 2 of the script is simply this order reversed.")
    p.body(
        "Two decisions are worth drawing out before the listings. The first is "
        "DimGeography, which is a role-playing dimension: five columns across "
        "four tables point at it. A user has a registered location and a last "
        "known one, an account has a billing location, and every event and every "
        "payment records where it came from. Because all five are the same table, "
        "any two of them can be compared directly — and that comparison is the "
        "whole basis of the suspicious transaction view in requirement 4.")
    p.body(
        "The second is that DimUser and DimAccount are separate. A person can "
        "close an account and open another, and plan, billing status and billing "
        "address belong to the account rather than to them. Keeping them apart is "
        "what lets the data show two users holding a second account and two users "
        "holding none at all, both of which are real states a single combined "
        "table could not represent.")

    p.h2("DimGeography")
    code(grab("CREATE TABLE dbo.DimGeography"))
    p.h2("DimPlan")
    code(grab("CREATE TABLE dbo.DimPlan"))
    p.h2("DimProduct")
    code(grab("CREATE TABLE dbo.DimProduct"))
    p.h2("DimCampaign")
    code(grab("CREATE TABLE dbo.DimCampaign"))
    p.h2("DimUser")
    code(grab("CREATE TABLE dbo.DimUser"))
    p.h2("DimAccount")
    code(grab("CREATE TABLE dbo.DimAccount"))
    p.h2("FactUserEvent")
    code(grab("CREATE TABLE dbo.FactUserEvent"))
    p.h2("FactPayment")
    code(grab("CREATE TABLE dbo.FactPayment"))
    p.h2("FactSubscription")
    code(grab("CREATE TABLE dbo.FactSubscription"))
    p.h2("DimPlanAudit")
    code(grab("CREATE TABLE dbo.DimPlanAudit"))

    p.h2("Indexes")
    p.body(
        "The primary keys give a clustered index each and the foreign keys give "
        "none, so these six cover the columns the later sections actually filter "
        "and join on. At ten users the optimizer will ignore them and scan the "
        "table every time; they are here because the schema is designed for "
        "a hundred thousand, where the two timestamp columns are what every "
        "time-series query ranges over.")
    code(grab("CREATE INDEX IX_Event_TS"))

    p.figure(SHOT + "fig2_create.png",
             "The ten tables after the script created them, read back out of "
             "sys.tables with their column, foreign key and check constraint "
             "counts. Fifteen foreign keys and thirty-two check constraints "
             "across the ten tables.")

    # ---------------------------------------------------------- 2. ERD
    p.h1("Requirement 2: Entity Relationship Diagram (5 marks)")
    p.body(
        "The diagram below is rendered by tools/erd_html.py from the schema in "
        "section 3 of the script, and every table, column, type, nullability "
        "and key in it was compared against sys.tables, sys.columns and "
        "sys.foreign_keys on the live database before it was captured. All ten "
        "tables and all fifteen foreign keys agree, so every line in it is a "
        "constraint the server actually holds, not one drawn by hand.")
    p.body(
        "The shape to look for is the two hubs. DimGeography is the first: the "
        "five lines converging on it are the registered and last-seen locations "
        "on DimUser, the billing location on DimAccount, and the transaction "
        "locations on FactUserEvent and FactPayment. DimPlan is the second, with "
        "three: the account's current plan, and both the new and previous plan on "
        "FactSubscription, which is what makes an upgrade and a downgrade "
        "distinguishable. Everything else flows left to right from the "
        "dimensions into the facts, and nothing flows back, which is how the "
        "diagram shows there are no circular references.")
    p.figure(SHOT + "fig3_erd.png",
             "Entity relationship diagram for the E_D_Group database, checked "
             "against the live catalog, showing all ten tables and the fifteen "
             "foreign key relationships between them.")

    # ------------------------------------------------------ 3. populate
    p.h1("Requirement 3: Populate the Tables (20 marks)")
    p.body(
        "Every dimension holds exactly ten rows. The three fact tables hold 48, "
        "30 and 23 rows, all inside the 20 to 50 the assignment asks for. "
        "DimPlanAudit is not loaded here at all: it is written only by the "
        "trigger in section 6, so it starts empty.")
    p.body(
        "Ten players over a short window will not demonstrate a reporting "
        "database by accident, so the rows were laid out deliberately rather "
        "than drawn at random. The window is 30 days and crosses a month "
        "boundary, so the monthly procedure returns two rows rather than one. "
        "The twelve sessions sit on nine days, and three of those days carry "
        "more than one player, so daily active users moves between one and "
        "three instead of being flat. Nine accounts are open and they cover "
        "both a free and a paid plan. Level five is lost three times out of "
        "four. Three payments happen in countries the account holder was "
        "nowhere near minutes earlier.")
    p.body(
        "Each of those is a property that a view, the procedure or the cursor "
        "depends on, and at this size a random draw can miss all of them at "
        "once. The generator asserts every one of them before it writes an "
        "INSERT, so a change that would quietly empty a result set fails when "
        "the data is built instead of being noticed by whoever reads the "
        "report.")
    p.body(
        "The rows are literal INSERT statements, so the script is self-contained. "
        "They were produced by a generator with a fixed seed, which is why the "
        "data is reproducible and why the numbers quoted throughout this document "
        "are stable. A short extract is shown below.")
    code(grab("INSERT INTO dbo.DimGeography", end="GO"))
    p.figure(SHOT + "fig4_populate.png",
             "Row counts in all ten tables after the populate section ran, "
             "counted back out of the tables themselves.")

    # --------------------------------------------------------- 4. views
    p.h1("Requirement 4: Three Queries Converted Into Views (30 marks)")
    p.body(
        "All three join more than one table and all three restrict with a WHERE "
        "clause. The three restrictions are deliberately different in kind: the "
        "first throws out rows before grouping, the second restricts to open "
        "accounts, and the third is a restriction that only exists because two "
        "copies of one dimension are being compared against each other.")
    p.body(
        "None of the three has an ORDER BY inside it. SQL Server does not allow "
        "one in a view definition without TOP or OFFSET, because a view is a "
        "table expression and a table has no order; the ordering belongs to "
        "whoever reads the view. None uses WITH SCHEMABINDING either, because "
        "binding a view to the columns it reads would block the DROP TABLE "
        "statements that make the script re-runnable.")

    p.h2("View 1: vwDailyActiveUsers")
    p.body(
        "Why this is useful: daily actives is the number this business is run on, "
        "but on its own it only says how busy yesterday was. Divided by the "
        "rolling thirty-day count it becomes stickiness — what share of the people "
        "who played this month played today — which is the difference between a "
        "game people return to and one they tried once. Splitting it free against "
        "paid in the same view shows whether paying players are the ones coming "
        "back.")
    p.body(
        "The rolling count is a CROSS APPLY rather than a window function because "
        "SQL Server has no COUNT(DISTINCT) OVER (). A correlated subquery per day "
        "is the way to get a distinct count over a moving window. Only "
        "SessionStart rows are counted, so a long session does not make somebody "
        "more active than a short one.")
    code(grab("CREATE VIEW dbo.vwDailyActiveUsers"))
    p.figure(SHOT + "fig5_view1.png",
             "Every active day in vwDailyActiveUsers: daily active users split "
             "free against paid, the rolling thirty-day count, and the "
             "stickiness ratio between them. Days nobody played do not "
             "appear, which is why there are nine rows and not thirty.")

    p.h2("View 2: vwFreeVsPaidValue")
    p.body(
        "Why this is useful: it answers the question every pricing argument turns "
        "on, which is whether paying players genuinely play more or simply pay. "
        "It also surfaces something the plan table alone would hide — the free "
        "tier produces more total revenue than any single paid plan, because free "
        "players buy one-time store items. That is the real free-to-play "
        "dynamic, and it is an argument against judging the free tier as a cost.")
    p.body(
        "Engagement and revenue sit in different fact tables at different grains, "
        "so they are aggregated separately through OUTER APPLY and only then "
        "brought together. Joining both fact tables directly would multiply "
        "sessions by payments and overstate both. Refunds are subtracted rather "
        "than ignored, so the revenue column is net.")
    code(grab("CREATE VIEW dbo.vwFreeVsPaidValue"))
    p.figure(SHOT + "fig6_view2.png",
             "vwFreeVsPaidValue: engagement and net revenue per plan, paid "
             "plans first. The free tier's total revenue comes entirely from "
             "one-time store purchases.")

    p.h2("View 3: vwSuspiciousTransactions")
    p.body(
        "Why this is useful: this is the query the whole geography design was "
        "built for. DimGeography is joined three times against the same payment — "
        "once as where the money moved, once as where the account was registered, "
        "once as where the person was last seen — and the suspicion is entirely in "
        "the disagreement between those three.")
    p.body(
        "There are three rules. A payment from a country the person never "
        "registered in. A payment from a place the dimension marks as high risk. "
        "And an implied speed between the last session and the payment of over "
        "900 km/h, which is faster than a commercial flight. That last one is "
        "where the distance function earns its place: distance alone says nothing, "
        "because people travel, but distance divided by the minutes since they "
        "were last seen says whether a human body could have made the trip.")
    p.body(
        "One limitation is worth stating rather than hiding. LastSeenAt is the "
        "person's most recent session, full stop, not the last one before this "
        "particular payment. That is the right comparison for a screen running "
        "against live traffic, where the payment being checked is the newest "
        "thing that has happened; run over history it is backwards for any "
        "payment older than that session. Those rows show NULL for the elapsed "
        "minutes rather than a negative number, and the travel rule cannot fire "
        "on them.")
    code(grab("CREATE VIEW dbo.vwSuspiciousTransactions"))
    p.figure(SHOT + "fig7_view3.png",
             "vwSuspiciousTransactions: five payments of 30 flagged. The three "
             "impossible-travel rows show the distance and the elapsed minutes "
             "that triggered them, including one payment 12,747 km from the "
             "last session seventy minutes earlier. The other two are flagged "
             "because the account holder is registered in a high-risk country, "
             "which is a different test and the view says so.")

    # --------------------------------------------------------- 5. audit
    p.h1("Requirement 5: Audit Table (20 marks)")
    p.body(
        "DimPlan is the lookup table being audited. It is the right choice "
        "because its rows are the ones that genuinely change: a price rise, a "
        "plan being made free, a plan being retired. Every one of those is a "
        "change somebody will later have to account for, and none of them leaves "
        "a trace in the table itself.")
    p.body(
        "DimPlanAudit records the old and new value of the three columns worth "
        "watching, who made the change, and the datetime it happened, which is "
        "the column the assignment specifically asks for. It deliberately has no "
        "foreign key back to DimPlan: a DELETE audit row has to outlive the row "
        "it describes, and a foreign key would either block the delete or cascade "
        "the history away.")
    p.body(
        "One trigger covers all three operations. SQL Server gives a trigger two "
        "pseudo-tables, inserted and deleted, and which of them has rows is what "
        "the operation is — rows in inserted only is an INSERT, rows in both is an "
        "UPDATE, rows in deleted only is a DELETE. So the three cases are three "
        "statements against those tables rather than three separate triggers. The "
        "trigger is set-based, which means it handles a statement that changes "
        "ten rows as correctly as one that changes one.")
    code(grab("CREATE TRIGGER dbo.TR_DimPlan_Audit"))
    p.h2("The test of all three operations")
    p.body(
        "The script inserts a test plan, updates its price, deletes it, and then "
        "reads the audit table. PlanID 99 is used throughout and removed at the "
        "end, so DimPlan is left exactly as it was found and the script stays "
        "re-runnable. The three audit rows are deliberately not cleaned up: they "
        "are the evidence the trigger fired.")
    code(span("/* 1 of 3 - INSERT a new plan. */",
              "PRINT '== Audit test: what the trigger recorded';"))
    p.figure(SHOT + "fig8_audit.png",
             "The audit table after the insert, update and delete test. Each "
             "row carries the operation, the before and after values, and the "
             "datetime the change was made.")

    # ----------------------------------------------------- 6. proc, udf
    p.h1("Requirement 6: Stored Procedure and Function (20 marks)")
    p.h2("fnGeoDistanceKm")
    p.body(
        "A scalar function returning the great-circle distance in kilometers "
        "between two places, using the haversine formula. It exists because \"the "
        "payment came from a different country\" is a weak signal on its own — "
        "plenty of people travel — while \"the payment came from 11,000 km away, "
        "forty minutes after they were last seen\" is not something a traveler "
        "can do. View 3 divides this by the elapsed time to get an implied speed, "
        "and that is what separates a holiday from a stolen card. It returns NULL "
        "rather than zero when either location is unknown, because a user who has "
        "never played has no last-seen location and that is not a distance of "
        "nothing.")
    code(grab("CREATE FUNCTION dbo.fnGeoDistanceKm"))
    p.h2("spMonthlyActiveUsers")
    p.body(
        "Monthly active users, split into new and returning, with the revenue "
        "that went with them and the average per user. @Year is required; @Month "
        "defaults to NULL, which reports every month of that year rather than "
        "forcing a caller who wants the whole year to run it twelve times. Both "
        "parameters are validated and raise a numbered error rather than "
        "returning an empty set, because an empty result and a bad argument look "
        "identical to whoever called it.")
    code(grab("CREATE PROCEDURE dbo.spMonthlyActiveUsers"))
    p.figure(SHOT + "fig9_procudf.png",
             "The procedure reporting both months of active users and revenue, "
             "the function returning distances from Phoenix, and the procedure "
             "rejecting an out-of-range year with error 50001 rather than "
             "returning nothing.")

    # -------------------------------------------------------- 7. cursor
    p.h1("Requirement 7: Cursor (10 marks)")
    p.body(
        "The cursor walks the levels in play order and prints a difficulty "
        "line for each one, comparing the difficulty the designers assigned "
        "against the failure rate the event data actually shows, and flagging any "
        "level players lose more often than they win.")
    p.body(
        "A cursor is worth defending here, because set-based SQL is almost always "
        "the right answer. The output is a printed report, one PRINT per level "
        "with running commentary and a flag, and PRINT is not something a "
        "set-based statement can do per row. A result set would be the better "
        "choice for anything a program consumes; this is for a person reading a "
        "log.")
    p.body(
        "On the create and drop scripts the assignment asks for: a cursor has no "
        "CREATE or DROP in T-SQL, only DECLARE and DEALLOCATE. Declaring it GLOBAL "
        "makes those two genuinely separate statements against a named object "
        "that outlives its batch, which is as close to create and drop as a "
        "cursor gets, and it means the DEALLOCATE is a real drop rather than a "
        "formality. The CURSOR_STATUS guard before it clears the name if a "
        "previous run died between OPEN and DEALLOCATE, which is what keeps this "
        "section re-runnable.")
    code(grab("IF CURSOR_STATUS('global', 'curLevelDifficulty')"))
    code(grab("DECLARE curLevelDifficulty CURSOR GLOBAL"))
    p.figure(SHOT + "fig10_cursor.png",
             "The level difficulty report the cursor prints. Level 5 is flagged "
             "as a churn risk: one win in four attempts. Only the levels "
             "that were actually played appear, which is six of the ten.")

    # --------------------------------------------------------- 8. tests
    p.h1("Requirement 8: Tests")
    p.body(
        "The submission announcement asks that the script also carry the queries "
        "that test the code. Thirteen tests run at the end of the script and each "
        "reports PASS or FAIL in a column called Result, so a run can be checked "
        "by reading one column rather than by comparing numbers by eye.")
    p.body(
        "What they check matters more than that they pass. Three confirm the "
        "objects exist by reading the catalog views rather than inferring it from "
        "the absence of an error message. One checks row counts. One checks that "
        "no foreign key has an orphan row. Three check the views — and for the "
        "third the test is not that it returns rows but that it returns fewer "
        "than the unrestricted table, which is what proves the WHERE clause is "
        "doing work. One checks the trigger caught all three operations. One "
        "checks the function against a distance that can be verified "
        "independently. And two check the procedure, one that it returns the "
        "months it should and one that it rejects an argument it cannot answer "
        "with error 50001 instead of coming back empty.")
    p.figure(SHOT + "fig11_tests.png",
             "All thirteen tests reporting PASS, with the summary line the figure "
             "is checked against.")

    p.h1("Running It More Than Once")
    p.body(
        "Re-runnability is the requirement most likely to fail silently, so it "
        "was tested the only way that means anything, by running the file three "
        "times in a row and checking what was left behind. Every run completes "
        "with no errors and thirteen passes, and the object counts afterwards are "
        "the same ten tables, three views, one procedure, one function and one "
        "trigger the first run created.")
    p.figure(SHOT + "fig12_rerun.png",
             "Three consecutive runs of the submitted script, each completing "
             "with no errors and thirteen passes, and the object counts read back "
             "out of the catalog afterwards.")

    p.h1("Documentation Standards")
    p.body(
        "The required header block is at the top of the submitted file "
        "and is visible in all eleven terminal screenshots in this document, "
        "which is what the "
        "announcement asks for. Below it, a file banner states what the script "
        "does, lists the sections in the order they run, and explains the "
        "mechanism that makes it re-runnable.")
    p.body(
        "Inside the script, each of the nine sections opens with a banner "
        "carrying the requirement it satisfies and the reasoning behind the "
        "approach, each table and each object has a block comment explaining why "
        "it is shaped the way it is, and individual lines are commented only "
        "where they are not obvious. Every hand-written line stays at or under 78 "
        "characters so it reproduces as a Courier New 9 pt listing without "
        "wrapping; the generated data rows run to 86, which is what still fits in "
        "a 6.5 inch column at that size.")

    p.save()


if __name__ == "__main__":
    main()
