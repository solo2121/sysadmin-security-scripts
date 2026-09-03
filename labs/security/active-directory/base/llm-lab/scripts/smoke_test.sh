#!/usr/bin/env bash
# Smoke test for the llm01 OWASP LLM Top 10 lab.
# Run from the host (or from kali, inside the lab network) once the VM is up:
#   ./scripts/smoke_test.sh
#   LLM01_HOST=172.28.128.60 ./scripts/smoke_test.sh
set -euo pipefail

HOST="${LLM01_HOST:-172.28.128.60}"
PORT="${LLM01_PORT:-8000}"
BASE="http://${HOST}:${PORT}"
FAILED=0

check() {
  local description="$1"
  local expected_status="$2"
  shift 2
  local actual_status
  actual_status="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@")" || actual_status="000"
  if [[ "$actual_status" == "$expected_status" ]]; then
    echo "[PASS] $description ($actual_status)"
  else
    echo "[FAIL] $description (expected $expected_status, got $actual_status)"
    FAILED=1
  fi
}

echo "=================================================="
echo "llm01 smoke test — target: ${BASE}"
echo "=================================================="

check "health endpoint"            200 "${BASE}/health"
check "root endpoint"              200 "${BASE}/"
check "OpenAPI schema"             200 "${BASE}/openapi.json"
check "Swagger UI"                 200 "${BASE}/docs"
check "OWASP category list"        200 "${BASE}/owasp/categories"
check "LLM03 supply-chain manifest" 200 "${BASE}/llm03/manifest"
check "LLM02 debug (synthetic only)" 200 "${BASE}/llm02/debug"

echo "--------------------------------------------------"
if [[ "$FAILED" -eq 0 ]]; then
  echo "All smoke tests passed."
else
  echo "One or more smoke tests failed. Check 'systemctl status llm-owasp-lab' on llm01."
fi
echo "=================================================="
exit "$FAILED"
