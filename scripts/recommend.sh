#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — Smart Project Health Scoring
# Scores project health 0-100 across 5 categories.
# Must complete in under 5 seconds — fast greps, no AST.
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Parse flags ───
JSON_OUTPUT=false
for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=true ;;
  esac
done

# ─── Load manifest ───
ROOT="$(find_root)"
MANIFEST=""
for CANDIDATE in "$ROOT/saascode-kit/manifest.yaml" "$ROOT/.saascode/manifest.yaml" "$ROOT/manifest.yaml" "$ROOT/saascode-kit.yaml"; do
  [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
done

if [ -n "$MANIFEST" ]; then
  load_manifest_vars "$MANIFEST"
fi

# ─── Scoring variables ───
SCORE=0
PASS_ITEMS=""
WARN_ITEMS=""
CRIT_ITEMS=""

add_pass() { PASS_ITEMS="${PASS_ITEMS}$1\n"; }
add_warn() { WARN_ITEMS="${WARN_ITEMS}$1|$2\n"; }
add_crit() { CRIT_ITEMS="${CRIT_ITEMS}$1|$2\n"; }

# ═══════════════════════════════════════════════════════════
# Category 1: Tool Coverage (20 pts)
# ═══════════════════════════════════════════════════════════

# ESLint (+4)
if [ -f "$ROOT/eslint.config.js" ] || [ -f "$ROOT/.eslintrc.json" ] || [ -f "$ROOT/.eslintrc.js" ] || [ -f "$ROOT/.eslintrc.yml" ] || [ -f "$ROOT/ruff.toml" ] || [ -f "$ROOT/.golangci.yml" ]; then
  SCORE=$((SCORE + 4))
  add_pass "Linter configured"
else
  add_warn "No linter configured" "Run: npx saascode add eslint"
fi

# Prettier (+4)
if [ -f "$ROOT/.prettierrc" ] || [ -f "$ROOT/.prettierrc.json" ] || [ -f "$ROOT/.prettierrc.js" ] || [ -f "$ROOT/prettier.config.js" ]; then
  SCORE=$((SCORE + 4))
  add_pass "Prettier configured"
elif [ "${LANGUAGE:-}" = "python" ] || [ "${LANGUAGE:-}" = "go" ]; then
  SCORE=$((SCORE + 4))
  add_pass "Language-native formatter"
else
  add_warn "No formatter configured" "Run: npx saascode add prettier"
fi

# TypeScript strict (+4)
if [ -f "$ROOT/tsconfig.json" ]; then
  if grep -q '"strict": true\|"strict":true' "$ROOT/tsconfig.json" 2>/dev/null; then
    SCORE=$((SCORE + 4))
    add_pass "TypeScript strict mode enabled"
  else
    add_warn "TypeScript strict mode not enabled" "Set strict: true in tsconfig.json"
  fi
elif [ "${LANGUAGE:-}" != "typescript" ]; then
  SCORE=$((SCORE + 4)) # Not applicable
fi

# Husky/hooks (+4)
if [ -d "$ROOT/.husky" ] || [ -f "$ROOT/.pre-commit-config.yaml" ]; then
  SCORE=$((SCORE + 4))
  add_pass "Git hooks configured"
else
  add_warn "No pre-commit hooks configured" "Run: npx saascode add husky"
fi

# Semgrep (+4)
if [ -f "$ROOT/.semgrep.yml" ] || [ -d "$ROOT/.semgrep" ]; then
  SCORE=$((SCORE + 4))
  add_pass "Semgrep security rules configured"
else
  add_warn "No Semgrep security rules" "Run: npx saascode add semgrep"
fi

# ═══════════════════════════════════════════════════════════
# Category 2: Security Posture (30 pts)
# ═══════════════════════════════════════════════════════════

# Auth on routes (+8)
UNGUARDED=0
if [ "${LANGUAGE:-}" = "typescript" ] || [ "${LANGUAGE:-}" = "javascript" ]; then
  # Check for routes without auth guards
  CONTROLLER_FILES=$(find "$ROOT" -name "*.controller.ts" -not -path "*/node_modules/*" -not -path "*/dist/*" 2>/dev/null | head -20)
  for f in $CONTROLLER_FILES; do
    if ! grep -q '@UseGuards\|@Public\|@Auth\|auth\|guard' "$f" 2>/dev/null; then
      UNGUARDED=$((UNGUARDED + 1))
    fi
  done
fi
if [ "$UNGUARDED" -eq 0 ]; then
  SCORE=$((SCORE + 8))
  add_pass "Auth guards on routes"
else
  add_crit "$UNGUARDED API routes lack auth guards" "Run: npx saascode review --saas"
fi

# No hardcoded secrets (+8)
SECRET_COUNT=0
if [ -d "$ROOT" ]; then
  SECRET_COUNT=$(grep -rn 'sk_live_\|sk_test_\|AKIA[A-Z0-9]\|-----BEGIN.*PRIVATE KEY\|password\s*=\s*"[^"]\{8,\}"' \
    --include="*.ts" --include="*.js" --include="*.py" --include="*.rb" --include="*.go" --include="*.java" --include="*.php" \
    "$ROOT" 2>/dev/null | grep -v node_modules | grep -v dist | grep -v '.test.' | grep -v '.spec.' | wc -l | tr -d ' ')
fi
if [ "$SECRET_COUNT" -eq 0 ]; then
  SCORE=$((SCORE + 8))
  add_pass "No hardcoded secrets detected"
else
  add_crit "$SECRET_COUNT potential hardcoded secrets found" "Run: npx saascode review"
fi

# Tenant isolation (+6)
if [ "${LANGUAGE:-}" = "typescript" ] || [ "${LANGUAGE:-}" = "javascript" ]; then
  TENANT_ID="${TENANT_IDENTIFIER:-tenantId}"
  if [ -n "$TENANT_ID" ]; then
    MISSING_TENANT=$(grep -rn 'findMany\|findFirst\|find(' --include="*.ts" --include="*.js" "$ROOT" 2>/dev/null | \
      grep -v node_modules | grep -v dist | grep -v "$TENANT_ID" | grep -v '.test.' | grep -v '.spec.' | wc -l | tr -d ' ')
    if [ "$MISSING_TENANT" -lt 3 ]; then
      SCORE=$((SCORE + 6))
      add_pass "Tenant isolation patterns followed"
    else
      add_warn "Some queries may lack tenant scoping" "Run: npx saascode review --saas"
    fi
  else
    SCORE=$((SCORE + 6))
  fi
else
  SCORE=$((SCORE + 6))
fi

# Rate limiting (+4)
RATE_LIMIT_FOUND=false
grep -rq '@Throttle\|rateLimit\|rate_limit\|RateLimit\|rate-limit' --include="*.ts" --include="*.js" --include="*.py" --include="*.rb" "$ROOT" 2>/dev/null && RATE_LIMIT_FOUND=true
if [ "$RATE_LIMIT_FOUND" = true ]; then
  SCORE=$((SCORE + 4))
  add_pass "Rate limiting configured"
else
  add_warn "No rate limiting detected" "Run: npx saascode review --saas"
fi

# Webhook verification (+4)
WEBHOOK_FILES=$(find "$ROOT" -name "*webhook*" -not -path "*/node_modules/*" -not -path "*/dist/*" 2>/dev/null | head -5)
if [ -n "$WEBHOOK_FILES" ]; then
  VERIFIED=true
  for f in $WEBHOOK_FILES; do
    if ! grep -q 'verify\|signature\|rawBody\|hmac\|HMAC' "$f" 2>/dev/null; then
      VERIFIED=false
    fi
  done
  if [ "$VERIFIED" = true ]; then
    SCORE=$((SCORE + 4))
    add_pass "Webhook verification present"
  else
    add_warn "Webhook handlers may lack signature verification" "Check webhook handler files"
  fi
else
  SCORE=$((SCORE + 4)) # No webhooks = not applicable
fi

# ═══════════════════════════════════════════════════════════
# Category 3: Code Quality (20 pts)
# ═══════════════════════════════════════════════════════════

# No console.logs (+5)
CONSOLE_COUNT=$(grep -rn 'console\.log\b' --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" "$ROOT" 2>/dev/null | \
  grep -v node_modules | grep -v dist | grep -v '.test.' | grep -v '.spec.' | wc -l | tr -d ' ')
if [ "$CONSOLE_COUNT" -lt 5 ]; then
  SCORE=$((SCORE + 5))
  add_pass "Minimal console.log usage"
else
  add_warn "$CONSOLE_COUNT console.log statements found" "Clean up debug logging"
fi

# No empty catches (+5)
EMPTY_CATCH=$(grep -rn 'catch\s*([^)]*)\s*{\s*}' --include="*.ts" --include="*.js" "$ROOT" 2>/dev/null | \
  grep -v node_modules | grep -v dist | wc -l | tr -d ' ')
if [ "$EMPTY_CATCH" -eq 0 ]; then
  SCORE=$((SCORE + 5))
  add_pass "No empty catch blocks"
else
  add_warn "$EMPTY_CATCH empty catch blocks found" "Add error handling or logging"
fi

# No eval() (+5)
EVAL_COUNT=$(grep -rn '\beval\s*(' --include="*.ts" --include="*.js" --include="*.py" --include="*.rb" "$ROOT" 2>/dev/null | \
  grep -v node_modules | grep -v dist | grep -v '.test.' | wc -l | tr -d ' ')
if [ "$EVAL_COUNT" -eq 0 ]; then
  SCORE=$((SCORE + 5))
  add_pass "No eval() usage"
else
  add_crit "$EVAL_COUNT eval() calls found" "Remove eval() usage"
fi

# No raw SQL injection (+5)
RAW_SQL=$(grep -rn '\$queryRaw\s*`\|\$executeRaw\s*`\|cursor\.execute\s*(.*f"\|\.query\s*(.*".*+' \
  --include="*.ts" --include="*.js" --include="*.py" "$ROOT" 2>/dev/null | \
  grep -v node_modules | grep -v dist | wc -l | tr -d ' ')
if [ "$RAW_SQL" -eq 0 ]; then
  SCORE=$((SCORE + 5))
  add_pass "No raw SQL injection patterns"
else
  add_crit "$RAW_SQL potential SQL injection patterns" "Use parameterized queries"
fi

# ═══════════════════════════════════════════════════════════
# Category 4: CI/CD Setup (15 pts)
# ═══════════════════════════════════════════════════════════

# CI pipeline (+5)
if [ -d "$ROOT/.github/workflows" ] || [ -f "$ROOT/.gitlab-ci.yml" ] || [ -f "$ROOT/.circleci/config.yml" ] || [ -f "$ROOT/bitbucket-pipelines.yml" ]; then
  SCORE=$((SCORE + 5))
  add_pass "CI pipeline configured"
else
  add_warn "No CI pipeline detected" "Add GitHub Actions or GitLab CI"
fi

# Pre-commit hooks (+5) — already checked above, reuse
if [ -d "$ROOT/.husky" ] || [ -f "$ROOT/.pre-commit-config.yaml" ]; then
  SCORE=$((SCORE + 5))
fi

# Automated tests (+5)
TEST_FILES=$(find "$ROOT" \( -name "*.test.ts" -o -name "*.spec.ts" -o -name "*.test.js" -o -name "*.spec.js" -o -name "test_*.py" -o -name "*_test.go" -o -name "*Test.java" \) \
  -not -path "*/node_modules/*" -not -path "*/dist/*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TEST_FILES" -gt 0 ]; then
  SCORE=$((SCORE + 5))
  add_pass "Automated tests found ($TEST_FILES test files)"
else
  add_warn "No automated tests detected" "Add unit tests to your project"
fi

# ═══════════════════════════════════════════════════════════
# Category 5: SaaS Maturity (15 pts)
# ═══════════════════════════════════════════════════════════

# Payment error handling (+5)
PAYMENT_FILES=$(find "$ROOT" \( -name "*payment*" -o -name "*billing*" -o -name "*stripe*" -o -name "*subscription*" \) \
  -not -path "*/node_modules/*" -not -path "*/dist/*" 2>/dev/null | head -5)
if [ -n "$PAYMENT_FILES" ]; then
  PAYMENT_ERROR_HANDLING=true
  for f in $PAYMENT_FILES; do
    if ! grep -q 'catch\|try\|error\|Error\|rescue\|except' "$f" 2>/dev/null; then
      PAYMENT_ERROR_HANDLING=false
    fi
  done
  if [ "$PAYMENT_ERROR_HANDLING" = true ]; then
    SCORE=$((SCORE + 5))
    add_pass "Payment flows have error handling"
  else
    add_crit "Payment flows missing error handling" "Add try/catch to payment handlers"
  fi
else
  SCORE=$((SCORE + 5)) # No payments = not applicable
fi

# Multi-tenancy patterns (+5)
if [ "${M_tenancy_enabled:-}" = "true" ] || grep -rq 'tenantId\|tenant_id\|organization_id\|orgId' --include="*.ts" --include="*.js" --include="*.py" "$ROOT" 2>/dev/null; then
  SCORE=$((SCORE + 5))
  add_pass "Multi-tenancy patterns detected"
else
  SCORE=$((SCORE + 5)) # Not a multi-tenant app
fi

# API documentation (+5)
if [ -f "$ROOT/openapi.yaml" ] || [ -f "$ROOT/openapi.json" ] || [ -f "$ROOT/swagger.json" ] || [ -f "$ROOT/swagger.yaml" ] || \
   grep -rq '@ApiTags\|@ApiOperation\|swagger\|openapi' --include="*.ts" --include="*.js" --include="*.py" "$ROOT" 2>/dev/null; then
  SCORE=$((SCORE + 5))
  add_pass "API documentation present"
else
  add_warn "No API documentation detected" "Consider adding OpenAPI/Swagger docs"
fi

# ═══════════════════════════════════════════════════════════
# Output
# ═══════════════════════════════════════════════════════════

if [ "$JSON_OUTPUT" = true ]; then
  echo "{"
  echo "  \"score\": $SCORE,"
  echo "  \"max\": 100,"
  echo "  \"pass\": ["
  echo -e "$PASS_ITEMS" | sed '/^$/d' | while IFS= read -r item; do echo "    \"$item\","; done | sed '$ s/,$//'
  echo "  ],"
  echo "  \"warnings\": ["
  echo -e "$WARN_ITEMS" | sed '/^$/d' | while IFS='|' read -r msg fix; do echo "    {\"message\": \"$msg\", \"fix\": \"$fix\"},"; done | sed '$ s/,$//'
  echo "  ],"
  echo "  \"critical\": ["
  echo -e "$CRIT_ITEMS" | sed '/^$/d' | while IFS='|' read -r msg fix; do echo "    {\"message\": \"$msg\", \"fix\": \"$fix\"},"; done | sed '$ s/,$//'
  echo "  ]"
  echo "}"
  exit 0
fi

# Terminal output
echo ""
echo "  ${BOLD}SAASCODE PROJECT HEALTH${NC}"
echo "  ────────────────────────"

# Color score based on value
if [ "$SCORE" -ge 80 ]; then
  echo "  Score: ${GREEN}${SCORE}/100${NC}"
elif [ "$SCORE" -ge 50 ]; then
  echo "  Score: ${YELLOW}${SCORE}/100${NC}"
else
  echo "  Score: ${RED}${SCORE}/100${NC}"
fi
echo ""

# Passes
echo -e "$PASS_ITEMS" | sed '/^$/d' | while IFS= read -r item; do
  echo "  ${GREEN}✓${NC} $item"
done

# Warnings
HAS_WARNINGS=false
echo -e "$WARN_ITEMS" | sed '/^$/d' | while IFS='|' read -r msg fix; do
  if [ "$HAS_WARNINGS" = false ]; then
    echo ""
    echo "  ${YELLOW}⚠ RECOMMENDED${NC}"
    HAS_WARNINGS=true
  fi
  echo "  ${YELLOW}→${NC} $msg"
  [ -n "$fix" ] && echo "    $fix"
done

# Criticals
HAS_CRITS=false
echo -e "$CRIT_ITEMS" | sed '/^$/d' | while IFS='|' read -r msg fix; do
  if [ "$HAS_CRITS" = false ]; then
    echo ""
    echo "  ${RED}✗ CRITICAL${NC}"
    HAS_CRITS=true
  fi
  echo "  ${RED}→${NC} $msg"
  [ -n "$fix" ] && echo "    $fix"
done

echo "  ────────────────────────"
echo ""
