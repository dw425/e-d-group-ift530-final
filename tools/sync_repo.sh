#!/usr/bin/env bash
# Publish the project to the public group repo.
#
# Two layouts are supported, because both have been used:
#
#   1. This directory IS a checkout of the public repo - cloned straight
#      into the course repo. Then there is nothing to mirror: commit and
#      push in place. (Note that the course repo then sees a repo inside
#      a repo; keep courses/IFT530/Final_Project out of its index.)
#   2. This directory is the working copy and the public repo is a
#      separate checkout, by default on the Desktop. Then the tracked set
#      is copied across so the mirror cannot drift from what was built
#      here.
#
#   ./tools/sync_repo.sh ["commit message"]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRROR="${MIRROR:-$HOME/Desktop/e-d-group-ift530-final}"
MSG="${1:-Sync from the course repo}"

push_from() {
  cd "$1"
  if [ -z "$(git status --porcelain)" ]; then
    echo "nothing changed"
    exit 0
  fi
  git add -A
  git commit -q -m "$MSG"
  git push -q origin main
  echo "pushed: $(git log --oneline -1)"
  exit 0
}

# Layout 1: we are already standing in the public repo.
if [ -d "$HERE/.git" ] &&
   git -C "$HERE" remote get-url origin 2>/dev/null |
       grep -q 'e-d-group-ift530-final'; then
  echo "this checkout is the public repo - committing in place"
  push_from "$HERE"
fi

# Layout 2: mirror into a separate checkout.
[ -d "$MIRROR/.git" ] || { echo "no repo at $MIRROR" >&2; exit 1; }

# Deliverables and the machinery that produces them. Screenshots are
# included only once they exist; .env never is, and lives nowhere here.
mkdir -p "$MIRROR/parts" "$MIRROR/tools" "$MIRROR/docs"
cp "$HERE"/IFT530_EDGroup_FinalProject.sql \
   "$HERE"/IFT530_EDGroup_FinalProject.txt \
   "$HERE"/IFT530_EDGroup_FinalProjectSummary.docx \
   "$HERE"/IFT530_EDGroup_FinalProjectSummary.pdf \
   "$HERE"/build.py "$HERE"/build_summary.py "$HERE"/README.md \
   "$HERE"/finish.md "$MIRROR/"
cp "$HERE"/parts/*.sql "$MIRROR/parts/"
cp "$HERE"/tools/*.py "$HERE"/tools/*.sh "$MIRROR/tools/"
# docbuild.py and the APA template are vendored so the mirror can build on
# its own. Both live in the course repo root, which is not part of this
# repo - but only copy docbuild from there if this project has no copy of
# its own, because the local one is the newer of the two.
[ -f "$HERE/tools/docbuild.py" ] ||
    cp "$HERE/../../../tools/docbuild.py" "$MIRROR/tools/docbuild.py"
mkdir -p "$MIRROR/templates"
cp "$HERE"/templates/* "$MIRROR/templates/"
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

push_from "$MIRROR"
