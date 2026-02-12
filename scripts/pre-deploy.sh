#!/bin/bash
# SaasCode Kit — Pre-Deploy Verification
# Run this before any deployment to verify release readiness
#
# Usage: ./scripts/pre-deploy.sh [backend-path] [frontend-path] [api-url]
# Example: ./scripts/pre-deploy.sh apps/api apps/portal http://localhost:4000

BACKEND="${1:-apps/api}"
FRONTEND="${2:-apps/portal}"
API_URL="${3:-http://localhost:4000}"

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
echo "═══════════════════════════════════════════════"

gate() {
  local NAME="$1"
  local STATUS="$2" # pass, fail, warn
  if [ "$STATUS" = "pass" ]; then
    echo "  ${GREEN}✓ $NAME${NC}"
    GATES_PASSED=$((GATES_PASSED + 1))
  elif [ "$STATUS" = "warn" ]; then
    echo "  ${YELLOW}⚠ $NAME${NC}"
    GATES_WARNED=$((GATES_WARNED + 1))
  else
    echo "  ${RED}✗ $NAME${NC}"
    GATES_FAILED=$((GATES_FAILED + 1))
  fi
}

# ─── 1. TypeScript ───
echo "\n${CYAN}[1/7] TypeScript Check${NC}"
if npm run typecheck > /dev/null 2>&1; then
  gate "TypeScript compilation" "pass"
else
  gate "TypeScript compilation" "fail"
fi

# ─── 2. Backend Build ───
echo "\n${CYAN}[2/7] Backend Build${NC}"
if npm --prefix "$BACKEND" run build > /dev/null 2>&1; then
  gate "Backend build" "pass"
else
  gate "Backend build" "fail"
fi

# ─── 3. Frontend Build ───
echo "\n${CYAN}[3/7] Frontend Build${NC}"
if npm --prefix "$FRONTEND" run build > /dev/null 2>&1; then
  gate "Frontend build" "pass"
else
  gate "Frontend build" "fail"
fi

# ─── 4. Tests ───
echo "\n${CYAN}[4/7] Tests${NC}"
if npm --prefix "$BACKEND" run test > /dev/null 2>&1; then
  gate "Backend tests" "pass"
else
  gate "Backend tests" "fail"
fi

# ─── 5. Security Audit ───
echo "\n${CYAN}[5/7] Security Audit${NC}"
AUDIT_OUTPUT=$(npm audit --audit-level=critical 2>&1)
AUDIT_EXIT=$?
if [ $AUDIT_EXIT -eq 0 ]; then
  gate "No critical vulnerabilities" "pass"
else
  CRITICAL_COUNT=$(echo "$AUDIT_OUTPUT" | grep -ic "critical" 2>/dev/null || echo "0")
  if [ "$CRITICAL_COUNT" -gt 0 ]; then
    gate "Critical vulnerabilities found" "fail"
  else
    gate "Non-critical vulnerabilities" "warn"
  fi
fi

# ─── 6. Secrets Check ───
echo "\n${CYAN}[6/7] Secrets Check${NC}"
SECRETS=$(grep -rn 'password\s*=\|secret\s*=\|api[_-]\?key\s*=' --include="*.ts" "$BACKEND/src/" "$FRONTEND/src/" 2>/dev/null | grep -v 'process.env\|@Is\|interface\|type \|\.d\.ts\|\.test\.\|\.spec\.')
if [ -z "$SECRETS" ]; then
  gate "No hardcoded secrets" "pass"
else
  gate "Possible hardcoded secrets" "fail"
  echo "$SECRETS" | head -5
fi

# ─── 7. Health Check (if server running) ───
echo "\n${CYAN}[7/7] Health Check${NC}"
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" 2>/dev/null)
if [ "$HEALTH" = "200" ]; then
  gate "API health endpoint" "pass"
elif [ "$HEALTH" = "000" ]; then
  gate "API not running (skipped)" "warn"
else
  gate "API health returned $HEALTH" "fail"
fi

# ─── Migration Status ───
if [ -f "$BACKEND/prisma/schema.prisma" ]; then
  echo "\n${CYAN}Migration Status:${NC}"
  cd "$BACKEND" && npx prisma migrate status 2>/dev/null || echo "  Could not check migration status"
  cd - > /dev/null
fi

# ─── Report ───
TOTAL=$((GATES_PASSED + GATES_FAILED + GATES_WARNED))
echo "\n═══════════════════════════════════════════════"
echo "  Deployment Readiness"
echo "═══════════════════════════════════════════════"
echo "  ${GREEN}Passed:   $GATES_PASSED / $TOTAL${NC}"
echo "  ${YELLOW}Warnings: $GATES_WARNED${NC}"
echo "  ${RED}Failed:   $GATES_FAILED${NC}"

if [ $GATES_FAILED -gt 0 ]; then
  echo "\n${RED}  DEPLOY: BLOCKED${NC}"
  echo "  Fix $GATES_FAILED failing gate(s) before deploying."
  exit 1
elif [ $GATES_WARNED -gt 0 ]; then
  echo "\n${YELLOW}  DEPLOY: PROCEED WITH CAUTION${NC}"
  echo "  $GATES_WARNED warning(s) should be reviewed."
  exit 0
else
  echo "\n${GREEN}  DEPLOY: APPROVED${NC}"
  exit 0
fi
