#!/usr/bin/env bash
# capture.sh - the eleven terminal figures for the final project report.
#
# finish.md treats the captures as a manual step. They do not have to be:
# every one of them is "run ./tools/figs.sh <target> in a terminal and
# photograph the whole display", which is scriptable. Figure 3, the ERD,
# is the one real exception and is not produced here.
#
# Adapted from Assignment_Triggers/tools/capture.sh. Every guard below
# exists because something went wrong without it:
#   - the window is addressed by WORKSPACE name, not file name, because
#     the other half of the title changes whenever a tab is switched
#   - a window holding only a Welcome tab passes "window exists" and would
#     photograph nothing, so the title is checked for a .sql editor
#   - notification toasts hold keyboard focus and swallow typed commands
#   - a sentinel file proves the terminal is a live shell and not a TUI
#     that eats keystrokes
#   - the captures are checked for byte-identical duplicates at the end,
#     which is what catches "the screen never actually changed"
#
# Nothing here zooms the editor, the window or the terminal font, and
# nothing writes a settings file. It opens its own new window (code -n),
# never touches the others, and closes the one it opened on the way out.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="$HERE/screenshots_full"
SHOTS="$HERE/screenshots"
WIN="Final_Project"
FILE="IFT530_EDGroup_FinalProject.sql"
W=2056; H=1329; MENU=39        # this display, this session
mkdir -p "$OUT" "$SHOTS"

die() { echo "ABORT: $*" >&2; exit 1; }

[ -n "${MSSQL_SA_PASSWORD:-}" ] || die "MSSQL_SA_PASSWORD not set. source $ROOT/.env"
docker ps --format '{{.Names}}' | grep -q '^ift530-sql$' \
    || die "the ift530-sql container is not running"
[ -f "$HERE/$FILE" ] || die "missing $FILE"
python3 -c "import Quartz" 2>/dev/null || die "python3 has no Quartz"
command -v code >/dev/null || die "'code' is not on PATH"

park() { python3 "$ROOT/tools/click.py" move 1100 12 >/dev/null; sleep 1.2; }
as() { osascript -e "tell application \"System Events\" to tell process \"Code\"
  $1
end tell"; }
key_do() { as "set frontmost to true
  set w to first window whose name contains \"$WIN\"
  perform action \"AXRaise\" of w
  $1"; }
type_run() { key_do "keystroke \"$1\"
  delay 0.4
  key code 36"; }
win_named() { as "exists (first window whose name contains \"$WIN\")" 2>/dev/null; }
win_title() { as "get name of first window whose name contains \"$WIN\"" 2>/dev/null; }
shoot() { park; screencapture -x "$OUT/$1.png"
          [ -s "$OUT/$1.png" ] || die "screencapture wrote nothing for $1"
          echo "  captured $1"; }

if win_named | grep -q true; then echo "reusing the capture window already open"
else echo "opening a capture window..."; code -n "$HERE" "$HERE/$FILE"; fi

found=""
for _ in $(seq 1 30); do win_named | grep -q true && { found=yes; break; }; sleep 1; done
[ -n "$found" ] || die "no VS Code window has '$WIN' in its title after 30s"
case "$(win_title)" in
    *.sql*) ;;
    *) die "capture window has no .sql open (title: $(win_title)) - the Welcome-tab case" ;;
esac
echo "  window found with a .sql editor open"

key_do "set position of w to {0, $MENU}
  set size of w to {$W, $((H - MENU))}"
sleep 1.5

key_do "key code 53"; sleep 0.6
key_do "keystroke \"p\" using {command down, shift down}
  delay 0.9
  keystroke \"Clear All Notifications\"
  delay 0.9
  key code 36"
sleep 1

appearance_off() {
    local mark
    mark="$(as "get value of attribute \"AXMenuItemMarkChar\" of menu item \"$1\" of menu \"Appearance\" of menu item \"Appearance\" of menu \"View\" of menu bar 1" 2>/dev/null || true)"
    if [ "$mark" = "✓" ]; then
        as "click menu item \"$1\" of menu \"Appearance\" of menu item \"Appearance\" of menu \"View\" of menu bar 1" >/dev/null
        echo "  closed $2"; sleep 1
    fi
}
appearance_off "Secondary Side Bar" "the chat sidebar"
appearance_off "Panel" "the bottom panel"

# A window that restores a previous session comes back with a terminal
# already in it. Adding ours alongside makes VS Code show the terminal
# tab list down the right-hand side, which eats width for no reason, so
# the slate is cleared first.
key_do "keystroke \"p\" using {command down, shift down}
  delay 1
  keystroke \"Terminal: Kill All Terminals\"
  delay 1.2
  key code 36"
sleep 2

as "click menu item \"New Terminal\" of menu \"Terminal\" of menu bar 1" >/dev/null
sleep 4
SENTINEL="$(mktemp -t ift530fin)"; rm -f "$SENTINEL"
type_run "cd '$HERE' && source '$ROOT/.env' && printf ok > '$SENTINEL' && clear"
ok=""
for _ in $(seq 1 30); do [ -s "$SENTINEL" ] && { ok=yes; break; }; sleep 0.5; done
rm -f "$SENTINEL"
[ -n "$ok" ] || die "the terminal never ran what it was sent - not a live shell"
echo "  terminal confirmed to be a live shell"

key_do "keystroke \"p\" using {command down, shift down}
  delay 1
  keystroke \"Toggle Maximized Panel\"
  delay 1.5
  key code 36"
sleep 2

# Figure number -> figs.sh target. 3 is the ERD and is not a terminal
# figure, so it is absent here on purpose.
TARGETS=(
  "1:env"      "2:create"  "4:populate" "5:view1"  "6:view2"
  "7:view3"    "8:audit"   "9:procudf"  "10:cursor" "11:tests"
  "12:rerun"
)
for spec in "${TARGETS[@]}"; do
    IFS=: read -r num target <<<"$spec"
    type_run "clear"            # its own command, so the figure starts at the prompt
    sleep 1.5
    type_run "./tools/figs.sh $target"
    case "$target" in
        rerun)        sleep 25 ;;   # this one runs the whole script three times
        cursor|tests) sleep 18 ;;   # these each run the whole script once
        *)            sleep 12 ;;
    esac
    shoot "fig${num}_${target}"
done

cd "$OUT"
count=$(ls fig*.png 2>/dev/null | grep -cv '^fig3_' || true)
[ "$count" -eq 11 ] || die "expected 11 terminal captures, found $count"
dupes=$(md5 -q $(ls fig*.png | grep -v '^fig3_') | sort | uniq -d | wc -l | tr -d ' ')
[ "$dupes" -eq 0 ] || die "$dupes captures are byte-identical to another - the screen did not change"
echo "  11 distinct terminal captures verified"
echo
echo "captured 11 figures into screenshots_full/"
echo "figure 3 (the ERD) is still yours: see finish.md"

# Close the window this script opened and put his own IFT_Course window
# back in front. A visible VS Code is the "done" signal, and a leftover
# capture window defeats it. Only the capture window is closed; VS Code
# itself is never quit and no other window is touched.
as "set frontmost to true
  repeat with w in (every window whose name contains \"$WIN\")
    perform action \"AXRaise\" of w
    delay 0.5
    keystroke \"w\" using {command down, shift down}
    delay 1.5
  end repeat" >/dev/null 2>&1 || true
sleep 1
as "set frontmost to true
  set m to first window whose name contains \"IFT_Course\"
  perform action \"AXRaise\" of m" >/dev/null 2>&1 || true
echo "capture window closed; your IFT_Course window is back in front"
