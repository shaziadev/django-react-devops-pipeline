#!/usr/bin/env bash
# Poll the health endpoint until it returns 200 or we give up.
#   ./scripts/healthcheck.sh https://app.example.com/api/health/ [attempts]
set -euo pipefail

URL="${1:?usage: healthcheck.sh <url> [attempts]}"
ATTEMPTS="${2:-12}"

for i in $(seq 1 "$ATTEMPTS"); do
  if curl --fail --silent --show-error --max-time 5 "$URL"; then
    echo
    echo "Healthy after $i attempt(s)."
    exit 0
  fi
  echo "Attempt $i/$ATTEMPTS failed, retrying in 10s..."
  sleep 10
done

echo "Service did not become healthy: $URL" >&2
exit 1
