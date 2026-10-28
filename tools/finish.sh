#!/usr/bin/env bash
# Drive everything that is left on the final project.
#
# Eleven of the twelve captures are a terminal running tools/figs.sh and
# are taken unattended by tools/capture.sh. Only the ERD is a picture
# somebody has to compose, so the sequence is: check, capture, fetch the
# ERD, check again, build, publish.
#
#   ./tools/finish.sh check     what is missing right now
#   ./tools/finish.sh capture   take the eleven terminal figures and crop
#   ./tools/finish.sh shots     print the manual capture command for each gap
#   ./tools/finish.sh build     build the Word doc and proof the PDF
#   ./tools/finish.sh publish   mirror to the public repo and push
#   ./tools/finish.sh all       check -> build -> publish
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
PY=/usr/local/bin/python3          # python.org 3.13; it has python-docx
SOFFICE=/Applications/LibreOffice.app/Contents/MacOS/soffice
DOCX="$HERE/IFT530_EDGroup_FinalProject.docx"
SHOTS="$HERE/screenshots"

# Figure number -> the figs.sh target that produces it. Figure 3 is the
# ERD and has no target; it is handled separately everywhere below.
FIGS=(
  "1:fig1_env.png:env"
  "2:fig2_create.png:create"
  "3:fig3_erd.png:ERD"
  "4:fig4_populate.png:populate"
  "5:fig5_view1.png:view1"
  "6:fig6_view2.png:view2"
  "7:fig7_view3.png:view3"
  "8:fig8_audit.png:audit"
  "9:fig9_procudf.png:procudf"
  "10:fig10_cursor.png:cursor"
  "11:fig11_tests.png:tests"
  "12:fig12_rerun.png:rerun"
)

green() { printf '  \033[32m%s\033[0m %s\n' "ok" "$1"; }
red()   { printf '  \033[31m%s\033[0m %s\n' "--" "$1"; }

missing_count() {
  local n=0 spec file
  for spec in "${FIGS[@]}"; do
    IFS=: read -r _ file _ <<<"$spec"
    [ -f "$SHOTS/$file" ] || n=$((n + 1))
  done
  echo "$n"
}

preflight() {
  echo "Environment"
  if docker ps --format '{{.Names}}' | grep -q '^ift530-sql$'; then
    green "SQL Server container is up"
  else
    red "container is down - run: cd $REPO && ./tools/mssql.sh start"
  fi
  if [ -n "${MSSQL_SA_PASSWORD:-}" ]; then
    green "MSSQL_SA_PASSWORD is in the environment"
  else
    red "no password - run: cd $REPO && source .env"
  fi
  [ -x "$PY" ] && green "python at $PY" || red "missing $PY"
  [ -x "$SOFFICE" ] && green "LibreOffice present" || red "missing $SOFFICE"
}

check() {
  preflight
  echo
  echo "Screenshots ($SHOTS)"
  local spec num file target
  for spec in "${FIGS[@]}"; do
    IFS=: read -r num file target <<<"$spec"
    if [ -f "$SHOTS/$file" ]; then
      green "$(printf '%-2s %s' "$num" "$file")"
    elif [ "$target" = ERD ]; then
      red "$(printf '%-2s %s  <- capture docs/erd.html; see docs/SCREENSHOTS.md' "$num" "$file")"
    else
      red "$(printf '%-2s %s  <- ./tools/figs.sh %s' "$num" "$file" "$target")"
    fi
  done
  echo
  echo "Documents"
  for f in IFT530_EDGroup_FinalProjectSummary.docx \
           IFT530_EDGroup_FinalProject.sql \
           IFT530_EDGroup_FinalProject.txt; do
    [ -f "$HERE/$f" ] && green "$f" || red "$f"
  done
  [ -f "$DOCX" ] && green "$(basename "$DOCX")" \
                 || red "$(basename "$DOCX")  <- ./tools/finish.sh build"
  echo
  local n
  n=$(missing_count)
  if [ "$n" -eq 0 ]; then
    echo "All twelve figures are present. Next: ./tools/finish.sh build"
  else
    echo "$n figure(s) still to capture. Next: ./tools/finish.sh shots"
  fi
}

# Print, for each gap, the exact command to run before pressing
# Shift-Cmd-3. Nothing is captured here - that is yours to do.
shots() {
  local spec num file target n
  n=$(missing_count)
  if [ "$n" -eq 0 ]; then echo "nothing to capture"; return 0; fi
  mkdir -p "$SHOTS"
  echo "Capture the WHOLE display (Shift-Cmd-3), then move the file from"
  echo "the Desktop into $SHOTS under the name shown."
  echo "Do not change the terminal or editor theme for a nicer picture."
  echo
  for spec in "${FIGS[@]}"; do
    IFS=: read -r num file target <<<"$spec"
    [ -f "$SHOTS/$file" ] && continue
    if [ "$target" = ERD ]; then
      printf 'Figure %-2s  %s\n' "$num" "$file"
      printf '           serve and capture docs/erd.html - the recipe, and the\n'
      printf '           catalog check that has to go with it, are in\n'
      printf '           %s/docs/SCREENSHOTS.md\n\n' "$HERE"
    else
      printf 'Figure %-2s  %s\n' "$num" "$file"
      printf '           ./tools/figs.sh %s\n\n' "$target"
    fi
  done
}

# The eleven terminal figures, unattended, then the crop into screenshots/.
capture() {
  "$HERE/tools/capture.sh"
  echo
  "$PY" "$HERE/tools/crop.py"
}

build() {
  local n
  n=$(missing_count)
  if [ "$n" -ne 0 ]; then
    echo "$n figure(s) missing - build.py cannot run yet." >&2
    echo "Run ./tools/finish.sh check to see which." >&2
    exit 1
  fi
  echo "==> building the Word document"
  (cd "$HERE" && "$PY" build.py)
  echo
  echo "==> converting to PDF for proofing"
  rm -rf /tmp/proof && mkdir -p /tmp/proof
  "$SOFFICE" --headless --convert-to pdf --outdir /tmp/proof "$DOCX" >/dev/null 2>&1
  local pdf="/tmp/proof/$(basename "${DOCX%.docx}").pdf"
  echo "    $pdf"
  /opt/homebrew/bin/pdfinfo "$pdf" | grep -iE '^(Pages|Page size)'
  echo
  echo "Now READ every page before submitting. Open it with:"
  echo "    open $pdf"
  echo "Check each caption matches the figure above it and that no figure"
  echo "is too small to read at print size."
}

publish() {
  echo "==> mirroring to the public repo and pushing"
  "$HERE/tools/sync_repo.sh" "Add the final project Word document and screenshots"
  echo
  echo "    https://github.com/dw425/e-d-group-ift530-final"
  echo "    https://dw425.github.io/e-d-group-ift530-final/"
}

case "${1:-check}" in
  check)   check ;;
  capture) capture ;;
  shots)   shots ;;
  build)   build ;;
  publish) publish ;;
  all)     check; echo; build; echo; publish ;;
  *)       sed -n '2,14p' "$0"; exit 1 ;;
esac
