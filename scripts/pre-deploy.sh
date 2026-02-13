#!/bin/bash
# SaasCode Kit — Pre-Deploy Verification
# Run this before any deployment to verify release readiness
#
# Usage: ./scripts/pre-deploy.sh [backend-path] [frontend-path] [api-url]
# Example: ./scripts/pre-deploy.sh apps/api apps/portal http://localhost:4000

# Source shared library for detection helpers
_LIB="$(dirname "$0")/lib.sh"
[ -f "$_LIB" ] || _LIB="$(cd "$(dirname "$0")/../.." && pwd)/saascode-kit/scripts/lib.sh"
if [ -f "$_LIB" ]; then
  source "$_LIB"
  ROOT="$(find_root)"
  export _LIB_ROOT="$ROOT"

  # Find and load manifest
  MANIFEST=""
  for CANDIDATE in "$ROOT/saascode-kit/manifest.yaml" "$ROOT/.saascode/manifest.yaml" "$ROOT/manifest.yaml" "$ROOT/saascode-kit.yaml"; do
    [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
  done
  [ -n "$MANIFEST" ] && load_manifest_vars "$MANIFEST"
fi

BACKEND="${1:-${BACKEND_PATH:-apps/api}}"
FRONTEND="${2:-${FRONTEND_PATH:-apps/portal}}"
API_URL="${3:-http://localhost:4000}"
LANG="${LANGUAGE:-typescript}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

GATES_PASSED=0
GATES_FAILED=0
GATES_WARNED=0

echo "═══════════════════════════════════════════════"
echo "  Pre-Deploy Verification"
echo "  Stack: $LANG | Backend: $BACKEND | Frontend: $FRONTEND"
echo "═══════════════════════════════════════════════"

gate() {
  local NAME="$1"
  local STATUS="$2" # pass, fail, warn, skip
  if [ "$STATUS" = "pass" ]; then
    echo -e "  ${GREEN}✓ $NAME${NC}"
    GATES_PASSED=$((GATES_PASSED + 1))
  elif [ "$STATUS" = "warn" ]; then
    echo -e "  ${YELLOW}⚠ $NAME${NC}"
    GATES_WARNED=$((GATES_WARNED + 1))
    log_issue "pre-deploy" "warning" "$NAME" "Gate warning: $NAME" "" "" ""
  elif [ "$STATUS" = "skip" ]; then
    echo -e "  ${YELLOW}— $NAME${NC}"
  else
    echo -e "  ${RED}✗ $NAME${NC}"
    GATES_FAILED=$((GATES_FAILED + 1))
    log_issue "pre-deploy" "critical" "$NAME" "Gate failed: $NAME" "" "" ""
  fi
}

# ─── 1. Type / Static Analysis Check ───
printf "\n${CYAN}[1/8] Type / Static Analysis Check${NC}\n"
TYPECHECK_CMD="$(detect_typecheck_cmd 2>/dev/null || echo "")"

if [ -n "$TYPECHECK_CMD" ]; then
  if eval "$TYPECHECK_CMD" > /dev/null 2>&1; then
    gate "Type/static analysis" "pass"
  else
    gate "Type/static analysis ($TYPECHECK_CMD)" "fail"
  fi
else
  gate "Type check (not applicable for $LANG)" "skip"
fi

# ─── 2. Backend Build ───
printf "\n${CYAN}[2/8] Backend Build${NC}\n"
BUILD_CMD="$(detect_build_cmd "$BACKEND" 2>/dev/null || echo "")"

if [ -n "$BUILD_CMD" ]; then
  if eval "$BUILD_CMD" > /dev/null 2>&1; then
    gate "Backend build" "pass"
  else
    gate "Backend build" "fail"
  fi
else
  gate "Backend build (no build step for $LANG)" "skip"
fi

# ─── 3. Frontend Build ───
printf "\n${CYAN}[3/8] Frontend Build${NC}\n"
FE_BUILD_CMD="$(detect_build_cmd "$FRONTEND" 2>/dev/null || echo "")"

if [ -n "$FE_BUILD_CMD" ] && [ -n "${FRONTEND_FRAMEWORK:-}" ]; then
  if eval "$FE_BUILD_CMD" > /dev/null 2>&1; then
    gate "Frontend build" "pass"
  else
    gate "Frontend build" "fail"
  fi
else
  gate "Frontend build (no frontend detected)" "skip"
fi

# ─── 4. Tests ───
printf "\n${CYAN}[4/8] Tests${NC}\n"
TEST_CMD="$(detect_test_cmd "$BACKEND" 2>/dev/null || echo "")"

if [ -n "$TEST_CMD" ]; then
  if eval "$TEST_CMD" > /dev/null 2>&1; then
    gate "Backend tests" "pass"
  else
    gate "Backend tests" "fail"
  fi
else
  gate "Backend tests (no test command detected)" "skip"
fi

# ─── 5. Security Audit ───
printf "\n${CYAN}[5/8] Security Audit${NC}\n"
AUDIT_CMD="$(detect_audit_cmd 2>/dev/null || echo "")"

if [ -n "$AUDIT_CMD" ]; then
  AUDIT_OUTPUT=$(eval "$AUDIT_CMD" 2>&1)
  AUDIT_EXIT=$?
  if [ $AUDIT_EXIT -eq 0 ]; then
    gate "No critical vulnerabilities" "pass"
  else
    CRITICAL_COUNT=$(echo "$AUDIT_OUTPUT" | grep -ic "critical" 2>/dev/null) || true
    CRITICAL_COUNT="${CRITICAL_COUNT:-0}"
    if [ "$CRITICAL_COUNT" -gt 0 ]; then
      gate "Critical vulnerabilities found" "fail"
    else
      gate "Non-critical vulnerabilities" "warn"
    fi
  fi
else
  gate "Security audit (no audit tool for $LANG)" "skip"
fi

# ─── 6. Secrets Check ───
printf "\n${CYAN}[6/8] Secrets Check${NC}\n"

# Build include flags based on language
case "$LANG" in
  typescript)       SECRET_INCLUDES='--include="*.ts" --include="*.tsx"' ;;
  javascript)       SECRET_INCLUDES='--include="*.js" --include="*.jsx"' ;;
  python)           SECRET_INCLUDES='--include="*.py"' ;;
  ruby)             SECRET_INCLUDES='--include="*.rb"' ;;
  go)               SECRET_INCLUDES='--include="*.go"' ;;
  java)             SECRET_INCLUDES='--include="*.java" --include="*.kt"' ;;
  php)              SECRET_INCLUDES='--include="*.php"' ;;
  rust)             SECRET_INCLUDES='--include="*.rs"' ;;
  *)                SECRET_INCLUDES='--include="*.ts" --include="*.tsx"' ;;
esac

SECRETS=""
[ -d "$BACKEND/src" ] && SECRETS=$(eval "grep -rn 'password\s*=\|secret\s*=\|api[_-]\?key\s*=' $SECRET_INCLUDES '$BACKEND/src/' 2>/dev/null" | grep -v 'process\.env\|os\.environ\|ENV\[\|@Is\|interface\|type \|\.d\.ts\|\.test\.\|\.spec\.\|_test\.')
[ -z "$SECRETS" ] && [ -d "$FRONTEND/src" ] && SECRETS=$(eval "grep -rn 'password\s*=\|secret\s*=\|api[_-]\?key\s*=' $SECRET_INCLUDES '$FRONTEND/src/' 2>/dev/null" | grep -v 'process\.env\|os\.environ\|ENV\[\|@Is\|interface\|type \|\.d\.ts\|\.test\.\|\.spec\.\|_test\.')

if [ -z "$SECRETS" ]; then
  gate "No hardcoded secrets" "pass"
else
  gate "Possible hardcoded secrets" "fail"
  echo "$SECRETS" | head -5
fi

# ─── 7. Health Check (if server running) ───
printf "\n${CYAN}[7/8] Health Check${NC}\n"
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" 2>/dev/null)
if [ "$HEALTH" = "200" ]; then
  gate "API health endpoint" "pass"
elif [ "$HEALTH" = "000" ]; then
  gate "API not running (skipped)" "warn"
else
  gate "API health returned $HEALTH" "fail"
fi

# ─── 8. Migration Status ───
printf "\n${CYAN}[8/8] Migration Status${NC}\n"
MIGRATION_CMD="$(get_migration_check_cmd 2>/dev/null || echo "")"

if [ -n "$MIGRATION_CMD" ]; then
  if eval "$MIGRATION_CMD" > /dev/null 2>&1; then
    gate "Migrations up to date" "pass"
  else
    gate "Migration status check" "warn"
  fi
else
  gate "Migration check (not applicable)" "skip"
fi

# ─── Report ───
TOTAL=$((GATES_PASSED + GATES_FAILED + GATES_WARNED))
printf "\n═══════════════════════════════════════════════\n"
echo "  Deployment Readiness"
echo "═══════════════════════════════════════════════"
echo -e "  ${GREEN}Passed:   $GATES_PASSED / $TOTAL${NC}"
echo -e "  ${YELLOW}Warnings: $GATES_WARNED${NC}"
echo -e "  ${RED}Failed:   $GATES_FAILED${NC}"

if [ $GATES_FAILED -gt 0 ]; then
  printf "\n${RED}  DEPLOY: BLOCKED${NC}\n"
  echo "  Fix $GATES_FAILED failing gate(s) before deploying."
  exit 1
elif [ $GATES_WARNED -gt 0 ]; then
  printf "\n${YELLOW}  DEPLOY: PROCEED WITH CAUTION${NC}\n"
  echo "  $GATES_WARNED warning(s) should be reviewed."
  exit 0
else
  printf "\n${GREEN}  DEPLOY: APPROVED${NC}\n"
  exit 0
fi
