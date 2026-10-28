# Finish the IFT 530 Final Project

Everything left to do, in order, with the exact command for each step.

**Status: everything below is done except the Canvas submission in step 5.**
Eleven of the twelve captures turned out to be scriptable after all, and
`tools/capture.sh` takes them unattended; the ERD is the only one somebody
has to compose. The whole sequence is **check → capture → check → build →
proof → publish → submit**.

**Where you are right now**

| | Item | Status |
|---|---|---|
| ✅ | SQL script — 10 tables, 3 views, audit trigger, proc, UDF, cursor | done, 13 PASS / 0 FAIL on three consecutive runs |
| ✅ | `.txt` twin, byte-identical | done |
| ✅ | Summary document (50 marks) | done, 14 pages |
| ✅ | Interactive ERD + design spec, published | done |
| ✅ | Database built, backed up, data dictionary generated | done |
| ✅ | Public repo, GitHub Pages | done |
| ✅ | Twelve screenshots | done, `tools/capture.sh` + the ERD |
| ✅ | Final Project Word document (ERD, 5 marks + snapshots) | done, 24 pages, proofed page by page |
| ⬜ | **Submit to Canvas** | **the last step, and the only one left** |

---

## Step 0 — Open a terminal and set up

Run these four lines every time you start a session. Nothing else works
without them.

```bash
cd ~/Documents/School/IFT_Course
source .env
./tools/mssql.sh start
cd courses/IFT530/Final_Project
```

Then see exactly what is missing:

```bash
./tools/finish.sh check
```

Green `ok` lines are done, red `--` lines are not. It also prints the
command that produces each missing figure, so you never have to guess.

---

## Step 1 — Capture the twelve screenshots

Eleven of them are a terminal running `tools/figs.sh`, and those are taken
unattended:

```bash
./tools/finish.sh capture
```

That opens its own VS Code window, clears the notification toasts and any
terminal left over from a previous session, runs each target, captures the
whole display, refuses to finish if two captures came out byte-identical,
closes the window it opened, and then crops the empty black off the bottom
of each one into `screenshots/`. `screenshots_full/` keeps the untouched
originals. Leave the machine alone while it runs — it is driving the
keyboard.

Only figure 3, the ERD, is left after that; it is covered below.

If you would rather do it by hand:

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

This is the 5-mark requirement, so it is worth getting right. **What was
submitted** is a full-display capture of `docs/erd.html`:

```bash
(cd docs && /usr/local/bin/python3 -m http.server 8731 --bind 127.0.0.1 &)
open -na "Google Chrome" --args --user-data-dir=/tmp/erdshot \
     --no-first-run --window-position=0,39 --window-size=2056,1290 \
     http://127.0.0.1:8731/erd.html
# capture the whole display, save as screenshots/fig3_erd.png
```

Two things in there are deliberate. Serving it over `127.0.0.1` avoids a
`file://` URL, which makes Chrome raise a Documents-folder permission
prompt that lands in the middle of the picture. The throwaway
`--user-data-dir` gives a clean window, so no bookmarks bar or personal
tab ends up in a graded document.

`docs/erd.html` is drawn by `tools/erd_html.py` from the schema in
`parts/30_tables.sql` rather than read out of the server, so **check it
against the live catalog before you capture it** — every table, column,
type, nullability and foreign key against `sys.tables`, `sys.columns` and
`sys.foreign_keys`. All ten tables and all fifteen foreign keys agreed when
this was built. The document says so, so it has to stay true.

**The other legitimate source** is the VS Code MSSQL extension's schema
designer: connect with **no database pinned** (the command only appears on
a Database node), expand the server, right-click **E_D_Group**, choose
**Visualize and Design Schema…**, dismiss any Copilot popup, click **Auto
Arrange** and fit to view. There was no saved connection profile on this
machine, which is why the `erd.html` route was taken. The printable
`docs/EDGroup_ERD.pdf` is a third option.

**Capture it in the light theme.** The published pages now carry a
sun/moon switch and remember the choice, and they follow the operating
system until you make one. A dark screenshot is unreadable once it is
printed, so set the page to light before capturing: click the sun/moon in
the header, or seed the choice before the window opens —

```bash
# a one-line page that sets the theme, then hands off to the ERD
printf '%s' '<script>localStorage.setItem("edg-theme","light");\
location.replace("erd.html");</script>' > docs/_light.html
```

Delete `docs/_light.html` afterwards; it is a capture aid, not part of
the site.

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

If this directory is itself a clone of the public repo — which is how it is
checked out now — `sync_repo.sh` notices and commits in place instead of
mirroring. Keep `courses/IFT530/Final_Project` out of the course repo's
index while that is true; a repo inside a repo only half works.

- Repo — <https://github.com/dw425/e-d-group-ift530-final>
- Site — <https://dw425.github.io/e-d-group-ift530-final/>
- ERD — <https://dw425.github.io/e-d-group-ift530-final/erd.html>
- Dashboard — <https://dw425.github.io/e-d-group-ift530-final/dashboard.html>

The four published pages carry the same navigation bar, so any one of them
reaches the other three. The dashboard is rebuilt from the live database
with `/usr/local/bin/python3 tools/dashboard_html.py`; it is not part of
the graded submission, so it never blocks a step above.

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

**The old database is already gone.** `DWarrenGroup`, from before the
group rename, is not on this machine — the server carries `E_D_Group`,
`IFT530_Assignment`, `AP` and `MyGuitarShop` and nothing else. If you are
on a machine that still has it, nothing points at it:

```bash
sqlcmd -S localhost,1433 -U sa -C -Q "DROP DATABASE DWarrenGroup;"
```

**Do not add this folder to the course repo while it is a clone.**
`courses/IFT530/Final_Project` holds its own `.git`, so `git add` from the
course repo would record a gitlink nothing can clone. The work lives in the
public repo, which is the point of it. If you want it inside the course
repo instead, delete the nested `.git` first, or add the path to the course
repo's `.gitignore` and leave it where it is.

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
cd ~/Documents/School/IFT_Course && ./tools/mssql.sh start
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
