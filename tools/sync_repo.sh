#!/usr/bin/env bash
# Mirror the project into the public group repo and push.
#
# The repo is a separate checkout rather than a nested .git inside the
# course repo, because a repo inside a repo is a trap. This copies the
# tracked set across, so the mirror cannot drift from what was built here.
#
#   ./tools/sync_repo.sh ["commit message"]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRROR="${MIRROR:-$HOME/Desktop/e-d-group-ift530-final}"
MSG="${1:-Sync from the course repo}"

[ -d "$MIRROR/.git" ] || { echo "no repo at $MIRROR" >&2; exit 1; }

# Deliverables and the machinery that produces them. Screenshots are
# included only once they exist; .env never is, and lives nowhere here.
mkdir -p "$MIRROR/parts" "$MIRROR/tools" "$MIRROR/docs"
cp "$HERE"/IFT530_EDGroup_FinalProject.sql \
   "$HERE"/IFT530_EDGroup_FinalProject.txt \
   "$HERE"/IFT530_EDGroup_FinalProjectSummary.docx \
   "$HERE"/IFT530_EDGroup_FinalProjectSummary.pdf \
   "$HERE"/build.py "$HERE"/build_summary.py "$HERE"/README.md "$MIRROR/"
cp "$HERE"/parts/*.sql "$MIRROR/parts/"
cp "$HERE"/tools/*.py "$HERE"/tools/*.sh "$MIRROR/tools/"
# vendored so the mirror can build on its own; it lives in the course
# repo root, which is not part of this repo.
cp "$HERE/../../../tools/docbuild.py" "$MIRROR/tools/docbuild.py"
cp "$HERE"/docs/*.html "$HERE"/docs/*.pdf "$HERE"/docs/*.md "$MIRROR/docs/"
cp "$HERE"/parts/README.md "$MIRROR/parts/"
# the built database itself: a restorable backup and the dictionary
# generated from the live catalog.
mkdir -p "$MIRROR/database"
cp "$HERE"/database/* "$MIRROR/database/"
if [ -f "$HERE"/IFT530_EDGroup_FinalProject.docx ]; then
  cp "$HERE"/IFT530_EDGroup_FinalProject.docx "$MIRROR/"
fi
if [ -d "$HERE"/screenshots ]; then
  mkdir -p "$MIRROR/screenshots"
  cp "$HERE"/screenshots/*.png "$MIRROR/screenshots/"
fi

# The ERD is the published page; docs/ is what GitHub Pages serves.
cp "$HERE"/docs/erd.html "$MIRROR/docs/erd.html"

cd "$MIRROR"
if [ -z "$(git status --porcelain)" ]; then
  echo "nothing changed"
  exit 0
fi
git add -A
git commit -q -m "$MSG"
git push -q origin main
echo "pushed: $(git log --oneline -1)"
