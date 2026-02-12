#!/bin/bash
# SaasCode Kit — Full Audit Script
# Runs ALL security, quality, and pattern checks in one go
#
# Usage: ./scripts/full-audit.sh [backend-path] [frontend-path]
# Example: ./scripts/full-audit.sh apps/api apps/portal

BACKEND="${1:-apps/api}"
FRONTEND="${2:-apps/portal}"
API_CLIENT="${FRONTEND}/src/lib/api"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CRITICAL=0
WARNINGS=0
PASS=0

echo "═══════════════════════════════════════════════"
echo "  SaasCode Full Audit"
echo "  Backend: $BACKEND | Frontend: $FRONTEND"
echo "═══════════════════════════════════════════════"

# ─── Helper ───
check() {
  local LABEL="$1"
  local RESULT="$2"
  local SEVERITY="$3" # critical, warning, info

  if [ -n "$RESULT" ]; then
    if [ "$SEVERITY" = "critical" ]; then
      echo "\n${RED}[CRITICAL] $LABEL${NC}"
      CRITICAL=$((CRITICAL + 1))
    else
      echo "\n${YELLOW}[WARNING] $LABEL${NC}"
      WARNINGS=$((WARNINGS + 1))
    fi
    echo "$RESULT"
  else
    echo "${GREEN}[PASS] $LABEL${NC}"
    PASS=$((PASS + 1))
  fi
}

# ═══════════════════════════════════════
# SECURITY CHECKS
# ═══════════════════════════════════════
echo "\n${CYAN}── Security ──${NC}"

# 1. Auth Guard: @Roles without RolesGuard
ROLES_ISSUES=$(grep -rn "@Roles(" --include="*.ts" "$BACKEND/src/modules/" 2>/dev/null | while read LINE; do
  FILE=$(echo "$LINE" | cut -d: -f1)
  if ! grep -q "RolesGuard" "$FILE" 2>/dev/null; then
    echo "  $LINE"
  fi
done)
check "@Roles without RolesGuard (roles silently ignored)" "$ROLES_ISSUES" "critical"

# 2. Unscoped findMany
UNSCOPED=$(grep -rn "findMany()" --include="*.service.ts" "$BACKEND/src/modules/" 2>/dev/null)
check "Unscoped findMany() (returns all tenants' data)" "$UNSCOPED" "critical"

# 3. XSS: dangerouslySetInnerHTML
XSS=$(grep -rn "dangerouslySetInnerHTML" --include="*.tsx" --include="*.jsx" "$FRONTEND/src/" 2>/dev/null)
check "dangerouslySetInnerHTML usage" "$XSS" "critical"

# 4. SQL Injection: Raw queries with interpolation
SQLI=$(grep -rn "\$queryRaw\`\|\$executeRaw\`" --include="*.ts" "$BACKEND/src/" 2>/dev/null | grep -v "Prisma.sql")
check "Raw SQL with string interpolation" "$SQLI" "critical"

# 5. Hardcoded secrets
SECRETS=$(grep -rn 'password\s*=\|secret\s*=\|api[_-]\?key\s*=' --include="*.ts" "$BACKEND/src/" "$FRONTEND/src/" 2>/dev/null | grep -v 'process.env\|@Is\|interface\|type \|\.d\.ts\|\.test\.\|\.spec\.')
check "Hardcoded secrets" "$SECRETS" "critical"

# 6. Sensitive data in logs
LOGGING=$(grep -rn 'console\.log.*\(token\|secret\|password\|apiKey\|auth\)' --include="*.ts" "$BACKEND/src/" 2>/dev/null)
check "Sensitive data in console.log" "$LOGGING" "warning"

# 7. .env files tracked
ENV_TRACKED=$(git ls-files 2>/dev/null | grep -E '\.env($|\.local|\.prod|\.staging)')
check ".env files in git" "$ENV_TRACKED" "critical"

# ═══════════════════════════════════════
# QUALITY CHECKS
# ═══════════════════════════════════════
echo "\n${CYAN}── Quality ──${NC}"

# 8. DTOs without validation
if [ -d "$BACKEND/src/modules" ]; then
  UNVALIDATED_DTOS=$(find "$BACKEND/src/modules" -name "*.dto.ts" -exec sh -c 'grep -L "@Is" "$1" 2>/dev/null' _ {} \;)
  check "DTOs without validation decorators" "$UNVALIDATED_DTOS" "warning"
fi

# 9. Console.log in services
CONSOLE_LOGS=$(grep -rn "console\.log" --include="*.service.ts" --include="*.controller.ts" "$BACKEND/src/" 2>/dev/null | grep -v "\.test\.\|\.spec\.")
check "console.log in backend services/controllers" "$CONSOLE_LOGS" "warning"

# 10. Empty catch blocks
EMPTY_CATCH=$(grep -rn "catch.*{" --include="*.ts" --include="*.tsx" "$BACKEND/src/" "$FRONTEND/src/" 2>/dev/null | grep -A1 "catch" | grep -B1 "}" | grep "catch" | head -5)
check "Potentially empty catch blocks" "$EMPTY_CATCH" "warning"

# ═══════════════════════════════════════
# PATTERN CHECKS
# ═══════════════════════════════════════
echo "\n${CYAN}── Patterns ──${NC}"

# 11. Endpoint parity count
if [ -d "$API_CLIENT" ]; then
  FE_COUNT=$(grep -rcoE "apiClient\.(get|post|put|patch|delete)" "$API_CLIENT"/*.ts 2>/dev/null | awk -F: '{sum+=$2} END{print sum}')
  BE_COUNT=$(grep -rcoE "@(Get|Post|Put|Patch|Delete)" "$BACKEND"/src/modules/*/*.controller.ts 2>/dev/null | awk -F: '{sum+=$2} END{print sum}')
  FE_COUNT=${FE_COUNT:-0}
  BE_COUNT=${BE_COUNT:-0}
  if [ "$FE_COUNT" -gt "$BE_COUNT" ] 2>/dev/null; then
    check "Endpoint parity (Frontend: $FE_COUNT, Backend: $BE_COUNT)" "Frontend has more API calls than backend endpoints" "warning"
  else
    check "Endpoint parity (Frontend: $FE_COUNT, Backend: $BE_COUNT)" "" "info"
  fi
fi

# 12. Controllers without guard decorators
if [ -d "$BACKEND/src/modules" ]; then
  UNGUARDED=$(find "$BACKEND/src/modules" -name "*.controller.ts" -exec sh -c 'grep -L "UseGuards" "$1" 2>/dev/null' _ {} \;)
  check "Controllers without @UseGuards" "$UNGUARDED" "warning"
fi

# 13. npm audit
echo ""
AUDIT_RESULT=$(npm audit --audit-level=high 2>&1)
AUDIT_EXIT=$?
if [ $AUDIT_EXIT -ne 0 ]; then
  check "npm audit (high+ vulnerabilities)" "$(echo "$AUDIT_RESULT" | tail -5)" "warning"
else
  check "npm audit" "" "info"
fi

# ═══════════════════════════════════════
# REPORT
# ═══════════════════════════════════════
echo "\n═══════════════════════════════════════════════"
echo "  Audit Summary"
echo "═══════════════════════════════════════════════"
echo "  ${RED}Critical: $CRITICAL${NC}"
echo "  ${YELLOW}Warnings: $WARNINGS${NC}"
echo "  ${GREEN}Passed:   $PASS${NC}"
TOTAL=$((CRITICAL + WARNINGS + PASS))
echo "  Total checks: $TOTAL"

if [ $CRITICAL -gt 0 ]; then
  echo "\n${RED}STATUS: FAIL — $CRITICAL critical issue(s) must be fixed${NC}"
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  echo "\n${YELLOW}STATUS: WARN — $WARNINGS warning(s) should be reviewed${NC}"
  exit 0
else
  echo "\n${GREEN}STATUS: PASS — All checks clean${NC}"
  exit 0
fi
