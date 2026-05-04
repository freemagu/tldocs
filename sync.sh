#!/bin/bash
# Mirror tradelens/docs/ to ~/tldocs/ and push to GitHub.
# Source of truth: /app/syb/tradesuite/tradelens/docs/
# AUDIT_TRACKER.md is copied separately from the tradelens repo root.

set -e

SRC=/app/syb/tradesuite/tradelens/docs
DST=$HOME/tldocs
TRACKER_SRC=/app/syb/tradesuite/tradelens/AUDIT_TRACKER.md
TRACKER_REL=30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md

if [ ! -d "$SRC" ]; then
    echo "ERROR: source docs dir not found: $SRC" >&2
    exit 1
fi
if [ ! -f "$TRACKER_SRC" ]; then
    echo "ERROR: AUDIT_TRACKER.md not found: $TRACKER_SRC" >&2
    exit 1
fi
if [ ! -d "$DST/.git" ]; then
    echo "ERROR: $DST is not a git repo" >&2
    exit 1
fi

echo ">>> Mirroring $SRC/ -> $DST/"
rsync -a --delete \
    --exclude='.git/' \
    --exclude='.gitignore' \
    --exclude='sync.sh' \
    --exclude="$TRACKER_REL" \
    "$SRC/" "$DST/"

echo ">>> Copying AUDIT_TRACKER.md"
cp "$TRACKER_SRC" "$DST/$TRACKER_REL"

cd "$DST"
git add -A

if git diff --cached --quiet; then
    echo ">>> No changes to sync."
    exit 0
fi

echo ">>> Changes:"
git status --short

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
git commit -m "Sync from tradesuite docs $TS"
git push
echo ">>> Pushed to origin/main."
