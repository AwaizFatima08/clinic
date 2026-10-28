#!/usr/bin/env bash
# Upload web/dist to clinic-schedule.homilabs.org (Hostinger) over SSH/rsync.
#
#   npm run build                       # creates web/dist
#   bash scripts/deploy-web.sh          # or: npm run deploy:web (builds first)
#
# Needs SSH enabled in hPanel (Websites → homilabs.org → Advanced → SSH Access) and
# this machine's public key added there. Never put the SSH password in this file.
set -euo pipefail
cd "$(dirname "$0")/.."

HOSTINGER_SSH="${HOSTINGER_SSH:-u809141334@145.79.26.208}"
HOSTINGER_PORT="${HOSTINGER_PORT:-65002}"
HOSTINGER_DIR="${HOSTINGER_DIR:-domains/homilabs.org/public_html/clinic-schedule}"

[ -f web/dist/index.html ] || { echo "web/dist missing — run: npm run build"; exit 1; }
grep -q "connectFunctionsEmulator" web/src/fb.js || true # emulator wiring only activates on localhost

rsync -avz --delete -e "ssh -p ${HOSTINGER_PORT}" web/dist/ "${HOSTINGER_SSH}:${HOSTINGER_DIR}/"
echo "Deployed. Check https://clinic-schedule.homilabs.org/ and https://clinic-schedule.homilabs.org/admin.html"
