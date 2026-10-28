#!/usr/bin/env bash
# Creates a verified test admin in the Auth EMULATOR (never production).
# Emulator-only login: admin@clinic.test / admin-pass-2026 (matches functions/.env.local ADMIN_EMAILS).
set -euo pipefail
B=http://127.0.0.1:9197/identitytoolkit.googleapis.com/v1
P=clinic-schedule-homilabs
R=$(curl -s -X POST "$B/accounts:signUp?key=fake" -H 'content-type: application/json' \
  -d '{"email":"admin@clinic.test","password":"admin-pass-2026","returnSecureToken":true}')
ID=$(echo "$R" | python3 -c "import json,sys;print(json.load(sys.stdin).get('localId',''))")
if [ -z "$ID" ]; then
  R=$(curl -s -X POST "$B/accounts:signInWithPassword?key=fake" -H 'content-type: application/json' \
    -d '{"email":"admin@clinic.test","password":"admin-pass-2026","returnSecureToken":true}')
  ID=$(echo "$R" | python3 -c "import json,sys;print(json.load(sys.stdin)['localId'])")
fi
curl -s -X POST "$B/projects/$P/accounts:update" -H 'Authorization: Bearer owner' -H 'content-type: application/json' \
  -d "{\"localId\":\"$ID\",\"emailVerified\":true}" >/dev/null
echo "Test admin ready in the emulator (see this script for the login)."
