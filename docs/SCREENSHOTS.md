# Screenshot capture list

The 150-mark Final Project document needs twelve figures. `build.py` reads
them from `screenshots/` by exact filename and will not build until all
twelve exist, so this is the last blocking step before submission.

## Before you start

    cd ~/Documents/IFT_Course
    source .env && ./tools/mssql.sh start
    cd courses/IFT530/FinalProject

Every figure except the ERD comes from one `tools/figs.sh` target, which
prints the header block of the submitted script above its own
output. That is deliberate: the assignment asks for the header to be
visible in the snapshot, and this puts the file and its result in one
frame.

**Capture the whole display, not the window.** The grader is looking for
evidence the script ran on a real server, and a cropped terminal does not
show that. `Shift-Cmd-3` writes a full-display PNG to the Desktop.

**Do not change the terminal or editor theme for a nicer picture.** Capture
in whatever is already set.

## The twelve

| # | File | Command | What has to be legible |
|---|---|---|---|
| 1 | `fig1_env.png` | `./tools/figs.sh env` | The container running and `SELECT @@VERSION` naming SQL Server 2025 |
| 2 | `fig2_create.png` | `./tools/figs.sh create` | Ten tables with their column, FK and check counts |
| 3 | `fig3_erd.png` | VS Code — see below | All ten tables and the relationship lines between them |
| 4 | `fig4_populate.png` | `./tools/figs.sh populate` | 10 in every dimension; 48 / 30 / 23 in the fact tables |
| 5 | `fig5_view1.png` | `./tools/figs.sh view1` | Nine dated rows, DAU moving 1–3, rolling MAU climbing |
| 6 | `fig6_view2.png` | `./tools/figs.sh view2` | Both a free and a paid plan, with revenue per account |
| 7 | `fig7_view3.png` | `./tools/figs.sh view3` | Five flagged payments with the reason column readable |
| 8 | `fig8_audit.png` | `./tools/figs.sh audit` | Three audit rows — INSERT, UPDATE, DELETE — with `ChangedAt` |
| 9 | `fig9_procudf.png` | `./tools/figs.sh procudf` | Two months from the procedure, distances from the UDF, and the 50001 rejection |
| 10 | `fig10_cursor.png` | `./tools/figs.sh cursor` | The level report, level 5 marked CHURN RISK, the flagged count |
| 11 | `fig11_tests.png` | `./tools/figs.sh tests` | `13 PASS, 0 FAIL` |
| 12 | `fig12_rerun.png` | `./tools/figs.sh rerun` | Three runs, zero errors each, object counts unchanged |

Save each one into `screenshots/` under exactly the filename above.

## Figure 3, the ERD

This one is not a terminal capture. It comes from the VS Code MSSQL
extension's schema designer:

1. Connect with **no database pinned** in the connection profile. The
   command only appears on a Database node, and a pinned connection opens
   on a table node instead.
2. Expand the server, right-click **E_D_Group**, choose
   **Visualize and Design Schema…**. It is not in the command palette.
3. Dismiss any Copilot popup, click **Auto Arrange**, then fit to view.
4. Capture the full display and save as `screenshots/fig3_erd.png`.

If the extension will not cooperate, `docs/erd.html` is a complete,
self-contained ERD that prints cleanly — open it, capture it, and the
figure still shows every table and every relationship.

## After all twelve exist

    /usr/local/bin/python3 build.py

Then convert and read every page before submitting:

    /Applications/LibreOffice.app/Contents/MacOS/soffice --headless \
      --convert-to pdf --outdir /tmp/proof IFT530_EDGroup_FinalProject.docx

Check that each caption matches the figure above it and that no figure is
too small to read at print size.
