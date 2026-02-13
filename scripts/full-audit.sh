#!/bin/bash
# SaasCode Kit — Full Audit Script
# Runs ALL security, quality, and pattern checks in one go
#
# Usage: ./scripts/full-audit.sh [backend-path] [frontend-path]
# Example: ./scripts/full-audit.sh apps/api apps/portal

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
API_CLIENT="${API_CLIENT_PATH:-$FRONTEND/src/lib/api}"
BE_FW="${BACKEND_FRAMEWORK:-nestjs}"
FE_FW="${FRONTEND_FRAMEWORK:-nextjs}"
ORM_NAME="${ORM:-prisma}"
LANG="${LANGUAGE:-typescript}"
SRC_EXT="$(get_source_extensions 2>/dev/null || echo 'ts|tsx')"
TENANCY_ENABLED="${TMPL_tenancy_enabled:-true}"

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
echo "  Stack: $LANG / $BE_FW / $FE_FW / $ORM_NAME"
echo "═══════════════════════════════════════════════"

# ─── Helper ───
check() {
  local LABEL="$1"
  local RESULT="$2"
  local SEVERITY="$3" # critical, warning, info

  if [ -n "$RESULT" ]; then
    if [ "$SEVERITY" = "critical" ]; then
      printf "\n${RED}[CRITICAL] %s${NC}\n" "$LABEL"
      CRITICAL=$((CRITICAL + 1))
      log_issue "full-audit" "critical" "$LABEL" "$RESULT" "" "" ""
    else
      printf "\n${YELLOW}[WARNING] %s${NC}\n" "$LABEL"
      WARNINGS=$((WARNINGS + 1))
      log_issue "full-audit" "warning" "$LABEL" "$RESULT" "" "" ""
    fi
    echo "$RESULT"
  else
    printf "${GREEN}[PASS] %s${NC}\n" "$LABEL"
    PASS=$((PASS + 1))
  fi
}

# ═══════════════════════════════════════
# SECURITY CHECKS
# ═══════════════════════════════════════
printf "\n${CYAN}── Security ──${NC}\n"

# 1. Auth Guard — framework-aware
case "$BE_FW" in
  nestjs)
    ROLES_ISSUES=$(grep -rn "@Roles(" --include="*.ts" "$BACKEND/src/modules/" 2>/dev/null | while read LINE; do
      FILE=$(echo "$LINE" | cut -d: -f1)
      if ! grep -q "RolesGuard" "$FILE" 2>/dev/null; then
        echo "  $LINE"
      fi
    done)
    check "@Roles without RolesGuard (roles silently ignored)" "$ROLES_ISSUES" "critical"
    ;;
  express|fastify|hono)
    UNPROTECTED=$(grep -rn 'router\.\(get\|post\|put\|patch\|delete\)' --include="*.ts" --include="*.js" "$BACKEND/src/" 2>/dev/null | while read LINE; do
      FILE=$(echo "$LINE" | cut -d: -f1)
      if ! grep -q 'auth\|authenticate\|isAuthenticated\|requireAuth\|protect' "$FILE" 2>/dev/null; then
        echo "  $LINE"
      fi
    done)
    check "Routes without auth middleware" "$UNPROTECTED" "critical"
    ;;
  django)
    UNPROTECTED=$(grep -rn 'def \(get\|post\|put\|delete\|list\|create\|update\|destroy\)' --include="*.py" "$BACKEND/" 2>/dev/null | while read LINE; do
      FILE=$(echo "$LINE" | cut -d: -f1)
      if ! grep -q '@login_required\|permission_classes\|IsAuthenticated\|LoginRequiredMixin' "$FILE" 2>/dev/null; then
        echo "  $LINE"
      fi
    done)
    check "Views without authentication" "$UNPROTECTED" "critical"
    ;;
  flask)
    UNPROTECTED=$(grep -rn '@.*\.route(' --include="*.py" "$BACKEND/" 2>/dev/null | while read LINE; do
      FILE=$(echo "$LINE" | cut -d: -f1)
      if ! grep -q '@login_required\|@jwt_required\|@auth_required' "$FILE" 2>/dev/null; then
        echo "  $LINE"
      fi
    done)
    check "Routes without auth decorator" "$UNPROTECTED" "critical"
    ;;
  rails)
    UNPROTECTED=$(find "$BACKEND/app/controllers" -name "*_controller.rb" 2>/dev/null | while read FILE; do
      if ! grep -q 'before_action.*authenticate\|authenticate_user!' "$FILE" 2>/dev/null; then
        echo "  $FILE"
      fi
    done)
    check "Controllers without authentication" "$UNPROTECTED" "critical"
    ;;
  spring)
    UNPROTECTED=$(grep -rn '@RequestMapping\|@GetMapping\|@PostMapping' --include="*.java" --include="*.kt" "$BACKEND/src/" 2>/dev/null | while read LINE; do
      FILE=$(echo "$LINE" | cut -d: -f1)
      if ! grep -q '@PreAuthorize\|@Secured\|@RolesAllowed' "$FILE" 2>/dev/null; then
        echo "  $LINE"
      fi
    done)
    check "Endpoints without authorization" "$UNPROTECTED" "critical"
    ;;
  laravel)
    UNPROTECTED=$(find "$BACKEND/app/Http/Controllers" -name "*Controller.php" 2>/dev/null | while read FILE; do
      if ! grep -q 'middleware\|->middleware(' "$FILE" 2>/dev/null; then
        echo "  $FILE"
      fi
    done)
    check "Controllers without middleware" "$UNPROTECTED" "critical"
    ;;
  *)
    check "Auth guard check (skipped — unknown framework: $BE_FW)" "" "info"
    ;;
esac

# 2. Unscoped queries — ORM-aware (only if tenancy enabled)
if [ "$TENANCY_ENABLED" = "true" ]; then
  case "$ORM_NAME" in
    prisma)
      UNSCOPED=$(grep -rn "findMany()" --include="*.service.ts" "$BACKEND/src/modules/" 2>/dev/null)
      check "Unscoped findMany() (returns all tenants' data)" "$UNSCOPED" "critical"
      ;;
    typeorm)
      UNSCOPED=$(grep -rn '\.find(\s*{}\|\.find()' --include="*.service.ts" --include="*.repository.ts" "$BACKEND/src/" 2>/dev/null)
      check "Unscoped .find() (returns all tenants' data)" "$UNSCOPED" "critical"
      ;;
    sequelize)
      UNSCOPED=$(grep -rn '\.findAll()' --include="*.service.ts" --include="*.service.js" "$BACKEND/src/" 2>/dev/null)
      check "Unscoped .findAll() (returns all tenants' data)" "$UNSCOPED" "critical"
      ;;
    django)
      UNSCOPED=$(grep -rn '\.objects\.all()' --include="*.py" "$BACKEND/" 2>/dev/null | grep -v 'test_\|_test\.py\|migration')
      check "Unscoped .objects.all() (returns all tenants' data)" "$UNSCOPED" "critical"
      ;;
    sqlalchemy)
      UNSCOPED=$(grep -rn 'session\.query(' --include="*.py" "$BACKEND/" 2>/dev/null | grep -v 'test_\|_test\.py' | while read LINE; do
        LINENUM=$(echo "$LINE" | cut -d: -f2)
        FILE=$(echo "$LINE" | cut -d: -f1)
        CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 5))p" "$FILE" 2>/dev/null)
        if ! echo "$CONTEXT" | grep -q 'tenant'; then
          echo "  $LINE"
        fi
      done)
      check "Unscoped .query() (may return all tenants' data)" "$UNSCOPED" "critical"
      ;;
    *)
      check "Unscoped query check (skipped — ORM: $ORM_NAME)" "" "info"
      ;;
  esac
else
  check "Tenant scoping (skipped — tenancy disabled)" "" "info"
fi

# 3. XSS — framework-aware
case "$FE_FW" in
  nextjs|react)
    XSS=$(grep -rn "dangerouslySetInnerHTML" --include="*.tsx" --include="*.jsx" "$FRONTEND/src/" 2>/dev/null)
    check "dangerouslySetInnerHTML usage" "$XSS" "critical"
    ;;
  vue)
    XSS=$(grep -rn "v-html" --include="*.vue" "$FRONTEND/src/" 2>/dev/null)
    check "v-html usage (XSS risk)" "$XSS" "critical"
    ;;
  svelte)
    XSS=$(grep -rn '{@html' --include="*.svelte" "$FRONTEND/src/" 2>/dev/null)
    check "{@html} usage (XSS risk)" "$XSS" "critical"
    ;;
  angular)
    XSS=$(grep -rn '\[innerHTML\]' --include="*.html" --include="*.ts" "$FRONTEND/src/" 2>/dev/null)
    check "[innerHTML] binding (XSS risk)" "$XSS" "critical"
    ;;
  "")
    check "XSS check (skipped — no frontend)" "" "info"
    ;;
  *)
    check "XSS check (skipped — unknown framework: $FE_FW)" "" "info"
    ;;
esac

# 4. SQL Injection — ORM-aware
case "$ORM_NAME" in
  prisma)
    SQLI=$(grep -rn "\$queryRaw\`\|\$executeRaw\`" --include="*.ts" "$BACKEND/src/" 2>/dev/null | grep -v "Prisma.sql")
    check "Raw SQL with string interpolation" "$SQLI" "critical"
    ;;
  typeorm|sequelize|drizzle)
    SQLI=$(grep -rn '\.query\s*(\s*`\|sql\.raw\s*`' --include="*.ts" --include="*.js" "$BACKEND/src/" 2>/dev/null)
    check "Raw SQL with string interpolation" "$SQLI" "critical"
    ;;
  django|sqlalchemy)
    SQLI=$(grep -rn 'cursor\.execute\s*(\s*f"\|\.raw\s*(\s*f"\|text\s*(\s*f"' --include="*.py" "$BACKEND/" 2>/dev/null | grep -v 'test_\|_test\.py')
    check "Raw SQL with f-string interpolation" "$SQLI" "critical"
    ;;
  *)
    # Language-based fallback
    case "$LANG" in
      go)
        SQLI=$(grep -rn 'db\.Query\s*(\s*".*+\|db\.Exec\s*(\s*".*+' --include="*.go" "$BACKEND/" 2>/dev/null | grep -v '_test\.go')
        check "Raw SQL with string concatenation" "$SQLI" "critical"
        ;;
      java)
        SQLI=$(grep -rn 'Statement.*execute\s*(\s*"\|createQuery\s*(\s*".*+' --include="*.java" "$BACKEND/src/" 2>/dev/null | grep -v 'Test\.java')
        check "Raw SQL with string concatenation" "$SQLI" "critical"
        ;;
      ruby)
        SQLI=$(grep -rn '\.where\s*(\s*".*#{' --include="*.rb" "$BACKEND/" 2>/dev/null | grep -v '_spec\.rb\|_test\.rb')
        check "Raw SQL with string interpolation" "$SQLI" "critical"
        ;;
      php)
        SQLI=$(grep -rn '->query\s*(\s*"\|mysql_query\s*(' --include="*.php" "$BACKEND/" 2>/dev/null | grep -v 'Test\.php')
        check "Raw SQL with string interpolation" "$SQLI" "critical"
        ;;
      *)
        check "SQL injection check (skipped)" "" "info"
        ;;
    esac
    ;;
esac

# 5. Hardcoded secrets — language-aware extensions
_build_include_flags() {
  case "$LANG" in
    typescript)       echo '--include="*.ts" --include="*.tsx"' ;;
    javascript)       echo '--include="*.js" --include="*.jsx"' ;;
    python)           echo '--include="*.py"' ;;
    ruby)             echo '--include="*.rb"' ;;
    go)               echo '--include="*.go"' ;;
    java)             echo '--include="*.java" --include="*.kt"' ;;
    php)              echo '--include="*.php"' ;;
    rust)             echo '--include="*.rs"' ;;
    *)                echo '--include="*.ts" --include="*.tsx"' ;;
  esac
}

SRC_INCLUDES=$(_build_include_flags)
SECRETS=$(eval "grep -rn 'password\s*=\|secret\s*=\|api[_-]\?key\s*=' $SRC_INCLUDES '$BACKEND/src/' '$FRONTEND/src/' 2>/dev/null" | grep -v 'process\.env\|os\.environ\|ENV\[\|@Is\|interface\|type \|\.d\.ts\|\.test\.\|\.spec\.\|_test\.')
check "Hardcoded secrets" "$SECRETS" "critical"

# 6. Sensitive data in logs — language-aware
case "$LANG" in
  typescript|javascript)
    LOGGING=$(grep -rn 'console\.log.*\(token\|secret\|password\|apiKey\|auth\)' --include="*.ts" --include="*.js" "$BACKEND/src/" 2>/dev/null)
    ;;
  python)
    LOGGING=$(grep -rn 'print\|logging\.\(info\|debug\|warning\)' --include="*.py" "$BACKEND/" 2>/dev/null | grep -i 'token\|secret\|password\|api_key' | grep -v 'test_\|_test\.py')
    ;;
  go)
    LOGGING=$(grep -rn 'fmt\.Print\|log\.Print' --include="*.go" "$BACKEND/" 2>/dev/null | grep -i 'token\|secret\|password\|apiKey' | grep -v '_test\.go')
    ;;
  java)
    LOGGING=$(grep -rn 'System\.out\.print\|logger\.\(info\|debug\|warn\)' --include="*.java" "$BACKEND/src/" 2>/dev/null | grep -i 'token\|secret\|password\|apiKey' | grep -v 'Test\.java')
    ;;
  *)
    LOGGING=""
    ;;
esac
check "Sensitive data in logs" "$LOGGING" "warning"

# 7. .env files tracked
ENV_TRACKED=$(git ls-files 2>/dev/null | grep -E '\.env($|\.local|\.prod|\.staging)')
check ".env files in git" "$ENV_TRACKED" "critical"

# ═══════════════════════════════════════
# QUALITY CHECKS
# ═══════════════════════════════════════
printf "\n${CYAN}── Quality ──${NC}\n"

# 8. DTOs without validation (NestJS-specific)
case "$BE_FW" in
  nestjs)
    if [ -d "$BACKEND/src/modules" ]; then
      UNVALIDATED_DTOS=$(find "$BACKEND/src/modules" -name "*.dto.ts" -exec sh -c 'grep -L "@Is" "$1" 2>/dev/null' _ {} \;)
      check "DTOs without validation decorators" "$UNVALIDATED_DTOS" "warning"
    fi
    ;;
  *)
    check "DTO validation check (skipped — NestJS only)" "" "info"
    ;;
esac

# 9. Debug statements in services — language-aware
case "$LANG" in
  typescript|javascript)
    CONSOLE_LOGS=$(grep -rn "console\.log" --include="*.service.ts" --include="*.controller.ts" "$BACKEND/src/" 2>/dev/null | grep -v "\.test\.\|\.spec\.")
    check "console.log in backend services/controllers" "$CONSOLE_LOGS" "warning"
    ;;
  python)
    CONSOLE_LOGS=$(grep -rn "print(\|breakpoint()\|pdb\.set_trace()" --include="*.py" "$BACKEND/" 2>/dev/null | grep -v "test_\|_test\.py\|conftest\|migration")
    check "print()/breakpoint() in backend code" "$CONSOLE_LOGS" "warning"
    ;;
  go)
    CONSOLE_LOGS=$(grep -rn "fmt\.Println\|fmt\.Printf" --include="*.go" "$BACKEND/" 2>/dev/null | grep -v "_test\.go")
    check "fmt.Println/Printf in backend code" "$CONSOLE_LOGS" "warning"
    ;;
  java)
    CONSOLE_LOGS=$(grep -rn "System\.out\.print" --include="*.java" "$BACKEND/src/" 2>/dev/null | grep -v "Test\.java")
    check "System.out.println in backend code" "$CONSOLE_LOGS" "warning"
    ;;
  ruby)
    CONSOLE_LOGS=$(grep -rn "puts \|pp \|binding\.pry\|byebug" --include="*.rb" "$BACKEND/" 2>/dev/null | grep -v "_spec\.rb\|_test\.rb")
    check "Debug statements in backend code" "$CONSOLE_LOGS" "warning"
    ;;
  php)
    CONSOLE_LOGS=$(grep -rn "var_dump(\|print_r(\|dd(" --include="*.php" "$BACKEND/" 2>/dev/null | grep -v "Test\.php")
    check "Debug statements in backend code" "$CONSOLE_LOGS" "warning"
    ;;
  *)
    check "Debug statement check (skipped)" "" "info"
    ;;
esac

# 10. Empty catch blocks — language-aware
case "$LANG" in
  typescript|javascript)
    EMPTY_CATCH=$(grep -Pzol 'catch\s*(\([^)]*\))?\s*\{\s*\}' --include="*.ts" --include="*.tsx" -r "$BACKEND/src/" "$FRONTEND/src/" 2>/dev/null | head -5)
    [ -z "$EMPTY_CATCH" ] && EMPTY_CATCH=$(grep -rn 'catch\s*([^)]*)\s*{\s*}' --include="*.ts" --include="*.tsx" "$BACKEND/src/" "$FRONTEND/src/" 2>/dev/null | head -5)
    check "Potentially empty catch blocks" "$EMPTY_CATCH" "warning"
    ;;
  python)
    EMPTY_CATCH=$(grep -rn '^\s*except\s*:' --include="*.py" "$BACKEND/" 2>/dev/null | grep -v 'test_\|_test\.py' | head -5)
    check "Bare except: blocks" "$EMPTY_CATCH" "warning"
    ;;
  java)
    EMPTY_CATCH=$(grep -Pzol 'catch\s*\([^)]*\)\s*\{\s*\}' --include="*.java" -r "$BACKEND/src/" 2>/dev/null | head -5)
    [ -z "$EMPTY_CATCH" ] && EMPTY_CATCH=$(grep -rn 'catch\s*([^)]*)\s*{\s*}' --include="*.java" "$BACKEND/src/" 2>/dev/null | head -5)
    check "Empty catch blocks" "$EMPTY_CATCH" "warning"
    ;;
  go)
    EMPTY_CATCH=$(grep -rn 'if err != nil {\s*}' --include="*.go" "$BACKEND/" 2>/dev/null | grep -v '_test\.go' | head -5)
    check "Empty error handling" "$EMPTY_CATCH" "warning"
    ;;
  *)
    check "Empty catch check (skipped)" "" "info"
    ;;
esac

# ═══════════════════════════════════════
# PATTERN CHECKS
# ═══════════════════════════════════════
printf "\n${CYAN}── Patterns ──${NC}\n"

# 11. Endpoint parity count — framework-aware
_count_be_endpoints() {
  case "$BE_FW" in
    nestjs)
      grep -rcoE "@(Get|Post|Put|Patch|Delete)" "$BACKEND"/src/modules/*/*.controller.ts 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      ;;
    express|fastify|hono)
      grep -rcoE "router\.(get|post|put|patch|delete)" --include="*.ts" --include="*.js" "$BACKEND/src/" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      ;;
    django)
      grep -rcoE "path\(|re_path\(" --include="*.py" "$BACKEND/" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      ;;
    flask)
      grep -rcoE "@.*\.route\(" --include="*.py" "$BACKEND/" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      ;;
    rails)
      grep -coE "(get|post|put|patch|delete|resources|resource) " "$BACKEND/config/routes.rb" 2>/dev/null || echo "0"
      ;;
    spring)
      grep -rcoE "@(Get|Post|Put|Patch|Delete|Request)Mapping" --include="*.java" --include="*.kt" "$BACKEND/src/" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      ;;
    laravel)
      grep -coE "Route::(get|post|put|patch|delete)" "$BACKEND/routes/api.php" 2>/dev/null || echo "0"
      ;;
    *)
      echo "0"
      ;;
  esac
}

_count_fe_calls() {
  case "$FE_FW" in
    nextjs|react)
      if [ -d "$API_CLIENT" ]; then
        grep -rcoE "apiClient\.(get|post|put|patch|delete)" "$API_CLIENT"/*.ts 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      else
        grep -rcoE "(fetch|axios)\.(get|post|put|patch|delete)\|fetch\(" --include="*.ts" --include="*.tsx" "$FRONTEND/src/" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      fi
      ;;
    vue)
      grep -rcoE "(axios|fetch|http)\.(get|post|put|patch|delete)\|fetch\(" --include="*.vue" --include="*.ts" --include="*.js" "$FRONTEND/src/" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      ;;
    angular)
      grep -rcoE "this\.http\.(get|post|put|patch|delete)" --include="*.ts" "$FRONTEND/src/" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      ;;
    svelte)
      grep -rcoE "(fetch|axios)\.(get|post|put|patch|delete)\|fetch\(" --include="*.svelte" --include="*.ts" "$FRONTEND/src/" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}'
      ;;
    *)
      echo "0"
      ;;
  esac
}

BE_COUNT=$(_count_be_endpoints)
FE_COUNT=$(_count_fe_calls)
BE_COUNT=${BE_COUNT:-0}
FE_COUNT=${FE_COUNT:-0}

if [ "$FE_COUNT" -gt 0 ] || [ "$BE_COUNT" -gt 0 ]; then
  if [ "$FE_COUNT" -gt "$BE_COUNT" ] 2>/dev/null; then
    check "Endpoint parity (Frontend: $FE_COUNT, Backend: $BE_COUNT)" "Frontend has more API calls than backend endpoints" "warning"
  else
    check "Endpoint parity (Frontend: $FE_COUNT, Backend: $BE_COUNT)" "" "info"
  fi
else
  check "Endpoint parity (skipped — no endpoints detected)" "" "info"
fi

# 12. Controllers/routes without auth — framework-aware
case "$BE_FW" in
  nestjs)
    if [ -d "$BACKEND/src/modules" ]; then
      UNGUARDED=$(find "$BACKEND/src/modules" -name "*.controller.ts" -exec sh -c 'grep -L "UseGuards" "$1" 2>/dev/null' _ {} \;)
      check "Controllers without @UseGuards" "$UNGUARDED" "warning"
    fi
    ;;
  express|fastify|hono)
    # Already covered in check 1
    check "Route auth check" "" "info"
    ;;
  django|flask|rails|spring|laravel)
    # Already covered in check 1
    check "Route auth check" "" "info"
    ;;
  *)
    check "Auth check (skipped)" "" "info"
    ;;
esac

# 13. Security audit — language-aware
echo ""
AUDIT_CMD="$(detect_audit_cmd 2>/dev/null || echo "")"

if [ -n "$AUDIT_CMD" ]; then
  AUDIT_RESULT=$(eval "$AUDIT_CMD" 2>&1)
  AUDIT_EXIT=$?
  if [ $AUDIT_EXIT -ne 0 ]; then
    check "Security audit (high+ vulnerabilities)" "$(echo "$AUDIT_RESULT" | tail -5)" "warning"
  else
    check "Security audit" "" "info"
  fi
else
  # Fallback for when lib.sh didn't load
  if command -v npm >/dev/null 2>&1; then
    AUDIT_RESULT=$(npm audit --audit-level=high 2>&1)
    AUDIT_EXIT=$?
    if [ $AUDIT_EXIT -ne 0 ]; then
      check "npm audit (high+ vulnerabilities)" "$(echo "$AUDIT_RESULT" | tail -5)" "warning"
    else
      check "npm audit" "" "info"
    fi
  else
    check "Security audit (skipped — no audit tool)" "" "info"
  fi
fi

# ═══════════════════════════════════════
# REPORT
# ═══════════════════════════════════════
printf "\n═══════════════════════════════════════════════\n"
echo "  Audit Summary"
echo "═══════════════════════════════════════════════"
echo "  ${RED}Critical: $CRITICAL${NC}"
echo "  ${YELLOW}Warnings: $WARNINGS${NC}"
echo "  ${GREEN}Passed:   $PASS${NC}"
TOTAL=$((CRITICAL + WARNINGS + PASS))
echo "  Total checks: $TOTAL"

if [ $CRITICAL -gt 0 ]; then
  printf "\n${RED}STATUS: FAIL — $CRITICAL critical issue(s) must be fixed${NC}\n"
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  printf "\n${YELLOW}STATUS: WARN — $WARNINGS warning(s) should be reviewed${NC}\n"
  exit 0
else
  printf "\n${GREEN}STATUS: PASS — All checks clean${NC}\n"
  exit 0
fi
