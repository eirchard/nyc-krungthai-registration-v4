#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/sync-site.sh check
node --check site/app.js
node --check site/admin.js
node --check site/xlsx-lite.js
node --check worker/index.js
node --check < apps-script/Code.gs
bash -n install.sh
node tests/backend.test.cjs
node tests/regression.test.cjs
node tests/worker.test.mjs
printf 'PASS: all offline Node syntax and mock tests. No live service was contacted.\n'
