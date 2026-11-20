#!/usr/bin/env bash
# One time setup: replaces the default admin password and creates a scanner token.
# Both secrets go into .env (ignored by git) and are never printed.
set -euo pipefail
cd "$(dirname "$0")/.."
URL=http://127.0.0.1:9000
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if grep -q '^SONAR_ADMIN_PASSWORD=' .env; then
  echo "already bootstrapped, nothing to do"
  exit 0
fi

NEWPW="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)Aa1-"
code=$(curl -s -o "$tmp" -w '%{http_code}' -u admin:admin -X POST "$URL/api/users/change_password" \
  --data-urlencode "login=admin" --data-urlencode "previousPassword=admin" --data-urlencode "password=$NEWPW")
if [ "$code" != "204" ]; then
  echo "change_password failed: HTTP $code (nothing was changed)"
  cat "$tmp"; echo
  exit 1
fi
printf 'SONAR_ADMIN_PASSWORD=%s\n' "$NEWPW" >> .env

TOKEN=$(curl -s -u "admin:$NEWPW" -X POST "$URL/api/user_tokens/generate" \
  --data-urlencode "name=lab-cli-scanner" --data-urlencode "type=GLOBAL_ANALYSIS_TOKEN" \
  | python3 -c 'import sys, json; d = json.load(sys.stdin); print(d.get("token") or "")')
if [ -z "$TOKEN" ]; then
  echo "token generation failed, the admin password was changed and is saved in .env"
  exit 1
fi
printf 'SONAR_TOKEN=%s\n' "$TOKEN" >> .env
chmod 600 .env
echo "bootstrap ok: admin password changed, scanner token created, both saved in .env"
