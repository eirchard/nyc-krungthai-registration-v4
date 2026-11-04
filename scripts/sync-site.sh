#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-check}" in
  check)
    diff -qr "$root/site" "$root/docs" || { echo 'ERROR: site/ and docs/ differ. Run scripts/sync-site.sh sync'; exit 1; }
    echo 'PASS: site/ and docs/ are identical' ;;
  sync)
    for file in admin.html admin.js app.js config.js index.html style.css xlsx-lite.js; do cp "$root/site/$file" "$root/docs/$file"; done
    echo 'Synced site/ -> docs/' ;;
  *) echo 'Usage: bash scripts/sync-site.sh [check|sync]' >&2; exit 2 ;;
esac
