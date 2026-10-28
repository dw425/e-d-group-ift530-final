# Finish the IFT 530 Final Project

Everything left to do, in order, with the exact command for each step.

Only one thing here cannot be automated: the twelve screen captures, which
are pictures of your display. Everything on either side of them is wrapped
in `tools/finish.sh`, so the whole sequence is **check → capture → check →
build → publish → submit**.

**Where you are right now**

| | Item | Status |
|---|---|---|
| ✅ | SQL script — 10 tables, 3 views, audit trigger, proc, UDF, cursor | done, 13 PASS / 0 FAIL on three consecutive runs |
| ✅ | `.txt` twin, byte-identical | done |
| ✅ | Summary document (50 marks) | done, 14 pages |
| ✅ | Interactive ERD + design spec, published | done |
| ✅ | Database built, backed up, data dictionary generated | done |
| ✅ | Public repo, GitHub Pages | done |
| ⬜ | **Twelve screenshots** | **outstanding — yours to capture** |
| ⬜ | Final Project Word document (ERD, 5 marks + snapshots) | blocked on the screenshots |
| ⬜ | Submit to Canvas | last step |

---

## Step 0 — Open a terminal and set up

Run these four lines every time you start a session. Nothing else works
without them.

```bash
cd ~/Documents/IFT_Course
source .env
./tools/mssql.sh start
cd courses/IFT530/FinalProject
```

Then see exactly what is missing:

```bash
./tools/finish.sh check
```

Green `ok` lines are done, red `--` lines are not. It also prints the
command that produces each missing figure, so you never have to guess.

---

## Step 1 — Capture the twelve screenshots

```bash
./tools/finish.sh shots
```

That prints, for each gap, the command to run before you press the capture
key. The rules that matter:

- **Capture the whole display**, not just the window — `Shift-Cmd-3`. The
  grader is looking for evidence the script ran on a real server, and a
  cropped terminal does not show that.
- **Do not change your terminal or editor theme** to make a nicer picture.
  Capture in whatever is already set.
- Each capture lands on your Desktop. Move it into `screenshots/` under the
  exact filename below — `build.py` looks for these names and nothing else.

### The twelve

| # | Save as | Run this first | What has to be legible |
|---|---|---|---|
| 1 | `fig1_env.png` | `./tools/figs.sh env` | The container running, and `SELECT @@VERSION` naming SQL Server 2025 |
| 2 | `fig2_create.png` | `./tools/figs.sh create` | Ten tables with their column, FK and check counts |
| 3 | `fig3_erd.png` | *see below* | All ten tables and the relationship lines between them |
| 4 | `fig4_populate.png` | `./tools/figs.sh populate` | 10 in every dimension; 48 / 30 / 23 in the fact tables |
| 5 | `fig5_view1.png` | `./tools/figs.sh view1` | Nine dated rows, DAU moving 1–3, rolling MAU climbing |
| 6 | `fig6_view2.png` | `./tools/figs.sh view2` | Both a free and a paid plan, with revenue per account |
| 7 | `fig7_view3.png` | `./tools/figs.sh view3` | Five flagged payments, reason column readable |
| 8 | `fig8_audit.png` | `./tools/figs.sh audit` | Three audit rows — INSERT, UPDATE, DELETE — with `ChangedAt` |
| 9 | `fig9_procudf.png` | `./tools/figs.sh procudf` | Two months from the procedure, distances from the UDF, and the 50001 rejection |
| 10 | `fig10_cursor.png` | `./tools/figs.sh cursor` | The level report, level 5 marked CHURN RISK, the flagged count |
| 11 | `fig11_tests.png` | `./tools/figs.sh tests` | `13 PASS, 0 FAIL` |
| 12 | `fig12_rerun.png` | `./tools/figs.sh rerun` | Three runs, zero errors each, object counts unchanged |

Eleven of the twelve print the submitted script's ten-line header above
their own output. That is deliberate — the assignment asks for the header
to be visible in the snapshot, and this puts the file and its result in one
frame.

### Figure 3, the ERD — the one that is not a terminal capture

This is the 5-mark requirement, so it is worth getting right.

1. In VS Code, connect with **no database pinned** in the connection
   profile. The command only appears on a Database node; a pinned
   connection opens on a table node instead.
2. Expand the server, right-click **E_D_Group**, choose
   **Visualize and Design Schema…**. It is not in the command palette.
3. Dismiss any Copilot popup, click **Auto Arrange**, fit to view.
4. Capture the full display, save as `screenshots/fig3_erd.png`.

**If the extension will not cooperate**, use the fallback — it is complete
and shows every table and every relationship:

```bash
open docs/erd.html
```

Or the printable version: `docs/EDGroup_ERD.pdf`. Either is a legitimate
ERD for this requirement.

### Confirm before moving on

```bash
./tools/finish.sh check
```

Keep going until all twelve lines are green.

---

## Step 2 — Build the Word document

```bash
./tools/finish.sh build
```

This runs `build.py` (which refuses to start if any figure is missing),
writes `IFT530_EDGroup_FinalProject.docx`, converts it to PDF and prints
the page count.

---

## Step 3 — Proof the PDF, every page

Do not skip this. It is where illegible figures and captions that do not
match their figure get caught.

```bash
open /tmp/proof/IFT530_EDGroup_FinalProject.pdf
```

Read every page and check:

- [ ] Title page carries **E & D Group** and **Ethan Oxley, Daniel Warren**
- [ ] Every caption matches the figure directly above it
- [ ] No figure is too small to read at print size — especially the ERD
- [ ] Each figure is paired with the SQL listing it ran
- [ ] The ten-line header is visible in the terminal figures

If something is wrong, fix it and run `./tools/finish.sh build` again.

---

## Step 4 — Publish to the repo

```bash
./tools/finish.sh publish
```

Pushes the new document and the screenshots as **Dan Warren
&lt;danwarren425@gmail.com&gt;**. No other identity ever appears in this
history.

- Repo — <https://github.com/dw425/e-d-group-ift530-final>
- Site — <https://dw425.github.io/e-d-group-ift530-final/>

---

## Step 5 — Submit to Canvas

Two separate submissions. Check which dropbox wants which.

**Final Project Summary — 50 marks**

- `IFT530_EDGroup_FinalProjectSummary.docx`

**Final Project — 150 marks**

- `IFT530_EDGroup_FinalProject.txt` — the script, in text format as the
  assignment requires. Submit the `.txt`, not the `.sql`.
- `IFT530_EDGroup_FinalProject.docx` — the ERD and the execution snapshots.

---

## Shortcut

Once all twelve screenshots are in place, steps 2 and 4 collapse into one:

```bash
./tools/finish.sh all
```

Still read the PDF before you submit.

---

## Optional cleanup

Neither of these affects your grade.

**Drop the old database.** `DWarrenGroup` is still on the server from
before the group rename. Nothing points at it.

```bash
sqlcmd -S localhost,1433 -U sa -C -Q "DROP DATABASE DWarrenGroup;"
```

**Commit the project to your course repo.** `courses/IFT530/FinalProject/`
is currently untracked, so this work only exists on your desktop and in the
public repo.

```bash
cd ~/Documents/IFT_Course
git add courses/IFT530/FinalProject
git commit -m "IFT 530 Final Project: schema, script, summary and ERD"
```

**The two old GitHub repos** — `dwarrengroup-erd` and `e-d-group-ift530` —
are archived, read-only, and carry a banner saying so. If you would rather
delete them outright, that needs a token with `delete_repo` scope; the
settings page for each repo does it without one.

---

## Troubleshooting

**`source .env first`** — you skipped Step 0. Run all four lines.

**`./tools/figs.sh` prints nothing or errors** — the container is not
running:

```bash
cd ~/Documents/IFT_Course && ./tools/mssql.sh start
```

**The data looks wrong in a figure** — rebuild the database from the
script, then re-capture:

```bash
sqlcmd -S localhost,1433 -U sa -C -i IFT530_EDGroup_FinalProject.sql
```

It is re-runnable by design; running it again is always safe.

**`build.py` fails on a missing module** — you are on the wrong Python.
`finish.sh` uses `/usr/local/bin/python3` on purpose; Homebrew's 3.14 does
not have `python-docx`.
