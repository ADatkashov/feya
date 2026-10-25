#!/usr/bin/env bash
# Regenerates docs/openapi.json from a running backend (default http://localhost:8080).
set -euo pipefail
BASE="${1:-http://localhost:8080}"
curl -fsS "$BASE/v3/api-docs" | python3 -m json.tool > "$(dirname "$0")/../docs/openapi.json"
echo "docs/openapi.json updated"
