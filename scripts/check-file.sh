#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode — Single-File Validator (Claude Code Hook)
#
# Manifest-aware: reads manifest.yaml to determine which
# checks to run based on product type. Only activates
# checks relevant to your stack.
#
# Usage: check-file.sh <filepath>
# Exit:  0 = pass/warnings only, 2 = critical issues
# ═══════════════════════════════════════════════════════════

FILE="${1}"

# ─── Validate input ───
if [ -z "$FILE" ]; then
  echo "SKIP: check-file — no file path provided"
  exit 0
fi

if [ ! -f "$FILE" ]; then
  echo "SKIP: check-file — file not found: $FILE"
  exit 0
fi

# ─── Skip non-applicable files ───
BASENAME="$(basename "$FILE")"

# Skip test files, type defs, generated dirs
case "$BASENAME" in
  *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx|*.d.ts|\
  *.test.js|*.spec.js|*.test.jsx|*.spec.jsx|\
  test_*.py|*_test.py|conftest.py|\
  *_test.go|\
  *Test.java|*Tests.java|*Test.kt|\
  *_spec.rb|*_test.rb|\
  *Test.php|*_test.php)
    echo "PASS: check-file $BASENAME — skipped (test/type file)"
    exit 0
    ;;
esac

case "$FILE" in
  */node_modules/*|*/dist/*|*/.next/*|*/coverage/*|\
  */__pycache__/*|*/venv/*|*/.venv/*|*/.tox/*|\
  */target/*|*/vendor/*|*/build/*|*/.gradle/*|\
  */.turbo/*)
    echo "PASS: check-file $BASENAME — skipped (generated)"
    exit 0
    ;;
esac

# Only check source files (all supported languages)
case "$BASENAME" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.rb|*.go|*.java|*.kt|*.rs|*.php) ;;
  *)
    echo "PASS: check-file $BASENAME — skipped (not a source file)"
    exit 0
    ;;
esac

# ─── Find project root ───
find_root() {
  local DIR="$PWD"
  while [ "$DIR" != "/" ]; do
    [ -d "$DIR/.git" ] && echo "$DIR" && return
    DIR="$(dirname "$DIR")"
  done
  echo "$PWD"
}

ROOT="$(find_root)"
export _LIB_ROOT="$ROOT"

# Source shared library for log_issue
_LIB="$(dirname "$0")/lib.sh"
[ -f "$_LIB" ] || _LIB="$(cd "$(dirname "$0")/../.." && pwd)/saascode-kit/scripts/lib.sh"
[ -f "$_LIB" ] && source "$_LIB" 2>/dev/null

# ─── Read manifest for feature detection ───
# Uses a lightweight cache: reads manifest once, caches flags in /tmp
CACHE_FILE="/tmp/saascode-manifest-cache-$(echo "$ROOT" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "default")"

load_features() {
  # Check cache (valid for 60 seconds)
  if [ -f "$CACHE_FILE" ]; then
    CACHE_AGE=$(( $(date +%s) - $(stat -f%m "$CACHE_FILE" 2>/dev/null || stat -c%Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [ "$CACHE_AGE" -lt 60 ]; then
      . "$CACHE_FILE"
      return
    fi
  fi

  # Find manifest
  local MANIFEST=""
  for CANDIDATE in "$ROOT/saascode-kit/manifest.yaml" "$ROOT/.saascode/manifest.yaml" "$ROOT/manifest.yaml" "$ROOT/saascode-kit.yaml"; do
    [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
  done

  # Defaults: disable feature-specific checks if no manifest (safe fallback)
  HAS_TENANCY=false
  HAS_AI=false
  HAS_BILLING=false
  HAS_BACKEND=false
  HAS_FRONTEND=false
  TENANT_FIELD="tenantId"
  BACKEND_FW=""
  FRONTEND_FW=""
  ORM_NAME=""
  LANG="typescript"

  if [ -n "$MANIFEST" ]; then
    # Quick extraction — 2-level key reader
    _val() {
      local SECTION="$1" FIELD="$2"
      awk -v s="$SECTION" -v f="$FIELD" '
        BEGIN { in_s=0 }
        /^[a-z]/ { in_s=($1 == s":") ? 1 : 0; next }
        in_s && /^  [a-z]/ {
          line=$0; sub(/^[[:space:]]+/, "", line)
          if (line ~ "^"f":") {
            val=line; sub(/^[^:]+:[[:space:]]*/, "", val); sub(/[[:space:]]+#[[:space:]].*$/, "", val); gsub(/^"|"$/, "", val)
            print val; exit
          }
        }
      ' "$MANIFEST"
    }

    # 3-level key reader for stack.backend.framework etc.
    _val3() {
      local L1="$1" L2="$2" L3="$3"
      awk -v l1="$L1" -v l2="$L2" -v l3="$L3" '
        BEGIN { in1=0; in2=0 }
        /^[a-z]/ { in1=($1 == l1":") ? 1 : 0; in2=0; next }
        in1 && /^  [a-z]/ {
          line=$0; sub(/^[[:space:]]+/, "", line)
          in2=(line ~ "^"l2":") ? 1 : 0
          next
        }
        in1 && in2 && /^    [a-z]/ {
          line=$0; sub(/^[[:space:]]+/, "", line)
          if (line ~ "^"l3":") {
            val=line; sub(/^[^:]+:[[:space:]]*/, "", val); sub(/[[:space:]]+#[[:space:]].*$/, "", val); gsub(/^"|"$/, "", val)
            print val; exit
          }
        }
      ' "$MANIFEST"
    }

    local T_ENABLED=$(_val "tenancy" "enabled")
    local A_ENABLED=$(_val "ai" "enabled")
    local B_ENABLED=$(_val "billing" "enabled")
    local T_FIELD=$(_val "tenancy" "identifier")
    local S_LANG=$(_val "stack" "language")

    BACKEND_FW=$(_val3 "stack" "backend" "framework")
    FRONTEND_FW=$(_val3 "stack" "frontend" "framework")
    ORM_NAME=$(_val3 "stack" "backend" "orm")

    [ "$T_ENABLED" = "true" ] && HAS_TENANCY=true
    [ "$T_ENABLED" = "false" ] && HAS_TENANCY=false
    [ "$A_ENABLED" = "true" ] && HAS_AI=true
    [ "$B_ENABLED" = "true" ] && HAS_BILLING=true
    [ -n "$BACKEND_FW" ] && HAS_BACKEND=true
    [ -n "$FRONTEND_FW" ] && HAS_FRONTEND=true
    [ -n "$T_FIELD" ] && TENANT_FIELD="$T_FIELD"
    [ -n "$S_LANG" ] && LANG="$S_LANG"
  fi

  # Write cache
  cat > "$CACHE_FILE" << EOF
HAS_TENANCY=$HAS_TENANCY
HAS_AI=$HAS_AI
HAS_BILLING=$HAS_BILLING
HAS_BACKEND=$HAS_BACKEND
HAS_FRONTEND=$HAS_FRONTEND
TENANT_FIELD=$TENANT_FIELD
BACKEND_FW=$BACKEND_FW
FRONTEND_FW=$FRONTEND_FW
ORM_NAME=$ORM_NAME
LANG=$LANG
EOF
}

load_features

# ─── State ───
WARNINGS=0
CRITICALS=0
OUTPUT=""
_ISSUE_CAT=""  # set by each check section

warn() {
  WARNINGS=$((WARNINGS + 1))
  OUTPUT="${OUTPUT}WARNING: $1\n"
  log_issue "check-file" "warning" "${_ISSUE_CAT:-general}" "$1" "$FILE" "" ""
}

critical() {
  CRITICALS=$((CRITICALS + 1))
  OUTPUT="${OUTPUT}BLOCKED: $1\n"
  log_issue "check-file" "critical" "${_ISSUE_CAT:-general}" "$1" "$FILE" "" ""
}

# ═══════════════════════════════════════
# UNIVERSAL CHECKS (always run)
# ═══════════════════════════════════════

# Hardcoded secrets (skip type definitions, interfaces, env refs)
_ISSUE_CAT="hardcoded-secret"
while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  LINENUM=$(echo "$LINE" | cut -d: -f1)
  critical "Hardcoded secret detected (line $LINENUM)"
done < <(grep -n -i 'password\s*=\s*["\x27].\+["\x27]\|secret\s*=\s*["\x27].\+["\x27]\|api[_-]\?key\s*=\s*["\x27].\+["\x27]' "$FILE" 2>/dev/null | grep -v 'process\.env\|@Is\|interface \|type \|\.env\|example\|placeholder\|test\|mock\|TODO\|FIXME\|os\.environ\|ENV\[' || true)

# eval() usage — language-aware
_ISSUE_CAT="eval-usage"
case "$BASENAME" in
  *.ts|*.tsx|*.js|*.jsx)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      critical "eval() usage detected (line $LINENUM)"
    done < <(grep -n '\beval(' "$FILE" 2>/dev/null | grep -v '//.*eval\|/\*.*eval' || true)
    ;;
  *.py)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      critical "eval()/exec() usage detected (line $LINENUM)"
    done < <(grep -n '\beval(\|\bexec(' "$FILE" 2>/dev/null | grep -v '#.*eval\|#.*exec' || true)
    ;;
  *.rb|*.php)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      critical "eval() usage detected (line $LINENUM)"
    done < <(grep -n '\beval(' "$FILE" 2>/dev/null | grep -v '#.*eval' || true)
    ;;
esac

# rejectUnauthorized: false (JS/TS)
_ISSUE_CAT="tls-disabled"
case "$BASENAME" in
  *.ts|*.tsx|*.js|*.jsx)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      critical "rejectUnauthorized: false — TLS verification disabled (line $LINENUM)"
    done < <(grep -n 'rejectUnauthorized.*false' "$FILE" 2>/dev/null || true)
    ;;
  *.py)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      critical "SSL verification disabled (line $LINENUM)"
    done < <(grep -n 'verify\s*=\s*False' "$FILE" 2>/dev/null || true)
    ;;
esac

# Raw SQL with string interpolation — ORM-aware
_ISSUE_CAT="raw-sql"
case "${ORM_NAME:-}" in
  prisma)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      critical "Raw SQL with string interpolation (line $LINENUM)"
    done < <(grep -n '\$queryRaw\s*`\|\$executeRaw\s*`' "$FILE" 2>/dev/null | grep -v 'Prisma\.sql' || true)
    ;;
  typeorm|sequelize|drizzle)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      critical "Raw SQL with string interpolation (line $LINENUM)"
    done < <(grep -n '\.query\s*(\s*`\|\.query\s*(\s*".*\${\|sql\.raw\s*`' "$FILE" 2>/dev/null || true)
    ;;
  django|sqlalchemy)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      critical "Raw SQL with string interpolation (line $LINENUM)"
    done < <(grep -n 'cursor\.execute\s*(\s*f"\|\.raw\s*(\s*f"\|text\s*(\s*f"\|execute\s*(\s*f"' "$FILE" 2>/dev/null || true)
    ;;
  *)
    # Fallback: language-based detection
    case "$BASENAME" in
      *.ts|*.js)
        while IFS= read -r LINE; do
          [ -z "$LINE" ] && continue
          LINENUM=$(echo "$LINE" | cut -d: -f1)
          critical "Raw SQL with string interpolation (line $LINENUM)"
        done < <(grep -n '\$queryRaw\s*`\|\$executeRaw\s*`\|\.query\s*(\s*`' "$FILE" 2>/dev/null | grep -v 'Prisma\.sql' || true)
        ;;
      *.py)
        while IFS= read -r LINE; do
          [ -z "$LINE" ] && continue
          LINENUM=$(echo "$LINE" | cut -d: -f1)
          critical "Raw SQL with string interpolation (line $LINENUM)"
        done < <(grep -n 'cursor\.execute\s*(\s*f"\|\.execute\s*(\s*f"' "$FILE" 2>/dev/null || true)
        ;;
      *.go)
        while IFS= read -r LINE; do
          [ -z "$LINE" ] && continue
          LINENUM=$(echo "$LINE" | cut -d: -f1)
          critical "Raw SQL with string interpolation (line $LINENUM)"
        done < <(grep -n 'db\.Query\s*(\s*".*+\|db\.Exec\s*(\s*".*+' "$FILE" 2>/dev/null || true)
        ;;
      *.java)
        while IFS= read -r LINE; do
          [ -z "$LINE" ] && continue
          LINENUM=$(echo "$LINE" | cut -d: -f1)
          critical "Raw SQL with string interpolation (line $LINENUM)"
        done < <(grep -n 'Statement.*execute\s*(\s*"\|createQuery\s*(\s*".*+' "$FILE" 2>/dev/null || true)
        ;;
      *.rb)
        while IFS= read -r LINE; do
          [ -z "$LINE" ] && continue
          LINENUM=$(echo "$LINE" | cut -d: -f1)
          critical "Raw SQL with string interpolation (line $LINENUM)"
        done < <(grep -n '\.where\s*(\s*".*#{\|\.execute\s*(\s*".*#{' "$FILE" 2>/dev/null || true)
        ;;
      *.php)
        while IFS= read -r LINE; do
          [ -z "$LINE" ] && continue
          LINENUM=$(echo "$LINE" | cut -d: -f1)
          critical "Raw SQL with string interpolation (line $LINENUM)"
        done < <(grep -n '->query\s*(\s*"\|mysql_query\s*(' "$FILE" 2>/dev/null || true)
        ;;
    esac
    ;;
esac

# Sensitive data in logs — language-aware
_ISSUE_CAT="sensitive-log"
case "$BASENAME" in
  *.ts|*.tsx|*.js|*.jsx)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      warn "Sensitive data in console.log (line $LINENUM)"
    done < <(grep -n -i 'console\.log.*\(token\|secret\|password\|apiKey\|authorization\)' "$FILE" 2>/dev/null || true)
    ;;
  *.py)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      warn "Sensitive data in log/print (line $LINENUM)"
    done < <(grep -n -i 'print\s*(.*\(token\|secret\|password\|api_key\)\|logging\.\(info\|debug\|warning\).*\(token\|secret\|password\|api_key\)' "$FILE" 2>/dev/null || true)
    ;;
  *.go)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      warn "Sensitive data in log (line $LINENUM)"
    done < <(grep -n -i 'fmt\.Print\|log\.Print' "$FILE" 2>/dev/null | grep -i 'token\|secret\|password\|apiKey' || true)
    ;;
  *.java)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      warn "Sensitive data in log (line $LINENUM)"
    done < <(grep -n -i 'System\.out\.print\|logger\.\(info\|debug\|warn\)' "$FILE" 2>/dev/null | grep -i 'token\|secret\|password\|apiKey' || true)
    ;;
  *.rb)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      warn "Sensitive data in log (line $LINENUM)"
    done < <(grep -n -i 'puts \|logger\.\(info\|debug\|warn\)' "$FILE" 2>/dev/null | grep -i 'token\|secret\|password\|api_key' || true)
    ;;
esac

# Debug statements in non-test source files (warning only)
_ISSUE_CAT="debug-statement"
case "$FILE" in
  *.test.*|*.spec.*|*__tests__*|test_*|*_test.*) ;;
  *)
    case "$BASENAME" in
      *.ts|*.tsx|*.js|*.jsx)
        CONSOLE_COUNT=$(grep -c 'console\.log' "$FILE" 2>/dev/null) || CONSOLE_COUNT=0
        if [ "$CONSOLE_COUNT" -gt 0 ]; then
          warn "console.log found ($CONSOLE_COUNT occurrences) — remove before deploy"
        fi
        ;;
      *.py)
        DEBUG_COUNT=$(grep -c 'breakpoint()\|pdb\.set_trace()\|print(' "$FILE" 2>/dev/null) || DEBUG_COUNT=0
        if [ "$DEBUG_COUNT" -gt 0 ]; then
          warn "Debug statements found ($DEBUG_COUNT occurrences) — remove before deploy"
        fi
        ;;
      *.rb)
        DEBUG_COUNT=$(grep -c 'binding\.pry\|byebug\|puts ' "$FILE" 2>/dev/null) || DEBUG_COUNT=0
        if [ "$DEBUG_COUNT" -gt 0 ]; then
          warn "Debug statements found ($DEBUG_COUNT occurrences) — remove before deploy"
        fi
        ;;
      *.go)
        DEBUG_COUNT=$(grep -c 'fmt\.Println\|fmt\.Printf' "$FILE" 2>/dev/null) || DEBUG_COUNT=0
        if [ "$DEBUG_COUNT" -gt 0 ]; then
          warn "Debug print statements found ($DEBUG_COUNT occurrences) — remove before deploy"
        fi
        ;;
      *.java)
        DEBUG_COUNT=$(grep -c 'System\.out\.print' "$FILE" 2>/dev/null) || DEBUG_COUNT=0
        if [ "$DEBUG_COUNT" -gt 0 ]; then
          warn "System.out.print found ($DEBUG_COUNT occurrences) — use logger instead"
        fi
        ;;
      *.php)
        DEBUG_COUNT=$(grep -c 'var_dump(\|print_r(\|dd(' "$FILE" 2>/dev/null) || DEBUG_COUNT=0
        if [ "$DEBUG_COUNT" -gt 0 ]; then
          warn "Debug statements found ($DEBUG_COUNT occurrences) — remove before deploy"
        fi
        ;;
    esac
    ;;
esac

# ═══════════════════════════════════════
# AI/LLM CHECKS (only if ai.enabled=true)
# ═══════════════════════════════════════
if [ "$HAS_AI" = true ]; then

  _ISSUE_CAT="ai-security"
  # Prompt injection: user input interpolated directly into LLM prompts
  while IFS= read -r LINE; do
    [ -z "$LINE" ] && continue
    LINENUM=$(echo "$LINE" | cut -d: -f1)
    warn "User input interpolated into AI prompt — risk of prompt injection (line $LINENUM)"
  done < <(grep -n 'prompt.*\`.*\${\|messages.*\`.*\${\|systemMessage.*\`.*\${' "$FILE" 2>/dev/null | grep -v '//\|/\*\|\.test\.\|\.spec\.' || true)

  # System prompt exposure: returning system prompt to client
  while IFS= read -r LINE; do
    [ -z "$LINE" ] && continue
    LINENUM=$(echo "$LINE" | cut -d: -f1)
    warn "System prompt may be exposed in response — never return system prompts to clients (line $LINENUM)"
  done < <(grep -n 'systemPrompt\|system_prompt\|systemMessage' "$FILE" 2>/dev/null | grep -i 'return\|res\.\|response\.' || true)

  # LLM output used in eval or dangerouslySetInnerHTML
  while IFS= read -r LINE; do
    [ -z "$LINE" ] && continue
    LINENUM=$(echo "$LINE" | cut -d: -f1)
    critical "AI/LLM output used unsafely — eval/innerHTML with AI content is a security risk (line $LINENUM)"
  done < <(grep -n 'completion\|aiResponse\|llmOutput\|chatResponse\|generatedText\|aiResult' "$FILE" 2>/dev/null | grep 'eval(\|dangerouslySetInnerHTML\|innerHTML' || true)

  # Missing rate limiting on AI/LLM endpoints
  case "$BASENAME" in
    *.controller.ts)
      if grep -q 'generate\|completion\|chat\|prompt\|ai\/' "$FILE" 2>/dev/null; then
        if ! grep -q 'Throttle\|RateLimit\|throttle\|rateLimit' "$FILE" 2>/dev/null; then
          warn "AI endpoint without rate limiting — add @Throttle() to prevent abuse"
        fi
      fi
      ;;
  esac

  # Direct LLM output to database without validation
  while IFS= read -r LINE; do
    [ -z "$LINE" ] && continue
    LINENUM=$(echo "$LINE" | cut -d: -f1)
    warn "AI-generated content saved to DB — validate LLM output before persisting (line $LINENUM)"
  done < <(grep -n 'completion\|aiResponse\|llmOutput\|generatedText\|aiResult' "$FILE" 2>/dev/null | grep '\.create(\|\.update(\|\.upsert(' || true)

  # Hardcoded AI model names (makes upgrades painful)
  while IFS= read -r LINE; do
    [ -z "$LINE" ] && continue
    LINENUM=$(echo "$LINE" | cut -d: -f1)
    warn "Hardcoded AI model name — use config/constants instead (line $LINENUM)"
  done < <(grep -n "'gpt-4\|\"gpt-4\|'gpt-3\|\"gpt-3\|'claude-3\|\"claude-3\|'claude-2\|\"claude-2\|'llama\|\"llama\|'gemini\|\"gemini" "$FILE" 2>/dev/null | grep -v '//\|/\*\|\.test\.\|\.spec\.\|\.env\|config\|constant\|MODEL' || true)

  # AI API calls without error handling
  while IFS= read -r LINE; do
    [ -z "$LINE" ] && continue
    LINENUM=$(echo "$LINE" | cut -d: -f1)
    START=$((LINENUM > 5 ? LINENUM - 5 : 1))
    CONTEXT=$(sed -n "${START},$((LINENUM + 3))p" "$FILE" 2>/dev/null)
    if ! echo "$CONTEXT" | grep -q 'try\s*{'; then
      warn "AI provider call without try/catch — handle network/rate-limit/model errors (line $LINENUM)"
    fi
  done < <(grep -n 'openai\.\|anthropic\.\|groq\.\|replicate\.\|together\.' "$FILE" 2>/dev/null | grep '\.create(\|\.generate(\|\.chat(\|\.complete(\|\.embed(' | grep -v '//\|/\*\|\.test\.\|\.spec\.' || true)

  # Embedding calls inside loops (should batch)
  while IFS= read -r LINE; do
    [ -z "$LINE" ] && continue
    LINENUM=$(echo "$LINE" | cut -d: -f1)
    CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 15))p" "$FILE" 2>/dev/null)
    if echo "$CONTEXT" | grep -q 'embed\|embedding'; then
      warn "Potential single embedding call inside loop — batch embeddings for performance (line $LINENUM)"
    fi
  done < <(grep -n 'for\s*(.*of\b\|\.forEach(\|\.map(' "$FILE" 2>/dev/null || true)

fi  # HAS_AI

# ═══════════════════════════════════════
# BACKEND CHECKS (only if backend stack detected)
# ═══════════════════════════════════════
if [ "$HAS_BACKEND" = true ]; then

  _ISSUE_CAT="auth"
  # ─── Framework-specific controller/route checks ───
  case "${BACKEND_FW:-}" in
    nestjs)
      # ─── NestJS Controller checks ───
      case "$BASENAME" in
        *.controller.ts)
          if ! grep -q '@UseGuards(' "$FILE" 2>/dev/null; then
            critical "Missing @UseGuards on controller class"
          fi
          if grep -q '@Roles(' "$FILE" 2>/dev/null; then
            if ! grep -q 'RolesGuard' "$FILE" 2>/dev/null; then
              critical "@Roles() found but no RolesGuard in file — roles silently ignored"
            fi
          fi
          if [ "$HAS_TENANCY" = true ]; then
            if grep -q 'TenantGuard\|RolesGuard' "$FILE" 2>/dev/null; then
              if ! grep -q '@CurrentTenant\|@CurrentOrgId\|clerkOrgId' "$FILE" 2>/dev/null; then
                warn "Controller has guards but no tenant extraction (@CurrentTenant or @CurrentOrgId)"
              fi
            fi
          fi
          if grep -q '@nestjs/swagger' "$FILE" 2>/dev/null; then
            critical "@nestjs/swagger import — package is NOT installed"
          fi
          ;;
      esac
      ;;

    express|fastify|hono)
      # Check route files for missing auth middleware
      case "$BASENAME" in
        *.route.ts|*.routes.ts|*.route.js|*.routes.js|router.*)
          if grep -q 'router\.\(get\|post\|put\|patch\|delete\)' "$FILE" 2>/dev/null; then
            if ! grep -q 'auth\|authenticate\|isAuthenticated\|requireAuth\|protect' "$FILE" 2>/dev/null; then
              warn "Route file without auth middleware — ensure routes are protected"
            fi
          fi
          ;;
      esac
      ;;

    django)
      # Check views without login_required / permission_classes
      case "$BASENAME" in
        views.py|*_views.py|*_view.py)
          if grep -q 'def \(get\|post\|put\|patch\|delete\|list\|create\|update\|destroy\)' "$FILE" 2>/dev/null; then
            if ! grep -q '@login_required\|permission_classes\|IsAuthenticated\|LoginRequiredMixin' "$FILE" 2>/dev/null; then
              warn "View without authentication — add @login_required or permission_classes"
            fi
          fi
          ;;
      esac
      ;;

    flask)
      # Check routes without login_required
      case "$BASENAME" in
        *.py)
          if grep -q '@.*\.route(' "$FILE" 2>/dev/null; then
            if ! grep -q '@login_required\|@jwt_required\|@auth_required' "$FILE" 2>/dev/null; then
              warn "Flask route without auth decorator — add @login_required"
            fi
          fi
          ;;
      esac
      ;;

    rails)
      # Check controllers without before_action :authenticate
      case "$BASENAME" in
        *_controller.rb)
          if ! grep -q 'before_action.*authenticate\|before_action.*authorize\|authenticate_user!' "$FILE" 2>/dev/null; then
            warn "Controller without authentication — add before_action :authenticate_user!"
          fi
          ;;
      esac
      ;;

    laravel)
      # Check controllers without middleware
      case "$BASENAME" in
        *Controller.php)
          if ! grep -q 'middleware\|->middleware(' "$FILE" 2>/dev/null; then
            warn "Controller without middleware — add auth middleware"
          fi
          ;;
      esac
      ;;

    spring)
      # Check @RequestMapping without @PreAuthorize
      case "$BASENAME" in
        *Controller.java|*Controller.kt)
          if grep -q '@RequestMapping\|@GetMapping\|@PostMapping' "$FILE" 2>/dev/null; then
            if ! grep -q '@PreAuthorize\|@Secured\|@RolesAllowed' "$FILE" 2>/dev/null; then
              warn "Controller without authorization — add @PreAuthorize or @Secured"
            fi
          fi
          ;;
      esac
      ;;
  esac

  _ISSUE_CAT="tenant-scope"
  # ─── Tenant scoping checks — ORM-aware ───
  if [ "$HAS_TENANCY" = true ]; then
    case "${ORM_NAME:-}" in
      prisma)
        # ─── Prisma: findMany/deleteMany/updateMany/findUnique ───
        case "$BASENAME" in
          *.service.ts)
            while IFS= read -r LINE; do
              [ -z "$LINE" ] && continue
              LINENUM=$(echo "$LINE" | cut -d: -f1)
              CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 10))p" "$FILE" 2>/dev/null)
              if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD"; then
                critical "findMany() without $TENANT_FIELD in where clause (line $LINENUM)"
              fi
            done < <(grep -n '\.findMany(' "$FILE" 2>/dev/null || true)

            while IFS= read -r LINE; do
              [ -z "$LINE" ] && continue
              LINENUM=$(echo "$LINE" | cut -d: -f1)
              CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 10))p" "$FILE" 2>/dev/null)
              if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD"; then
                critical "deleteMany()/updateMany() without $TENANT_FIELD (line $LINENUM)"
              fi
            done < <(grep -n '\.deleteMany(\|\.updateMany(' "$FILE" 2>/dev/null || true)

            while IFS= read -r LINE; do
              [ -z "$LINE" ] && continue
              LINENUM=$(echo "$LINE" | cut -d: -f1)
              CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 15))p" "$FILE" 2>/dev/null)
              if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD"; then
                warn "findUnique() without $TENANT_FIELD check — verify ownership is enforced (line $LINENUM)"
              fi
            done < <(grep -n '\.findUnique(\|\.findFirst(' "$FILE" 2>/dev/null || true)
            ;;
        esac
        ;;

      typeorm)
        case "$BASENAME" in
          *.service.ts|*.repository.ts)
            while IFS= read -r LINE; do
              [ -z "$LINE" ] && continue
              LINENUM=$(echo "$LINE" | cut -d: -f1)
              CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 10))p" "$FILE" 2>/dev/null)
              if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD"; then
                critical ".find() without $TENANT_FIELD (line $LINENUM)"
              fi
            done < <(grep -n '\.find(\s*{\|\.findOne(\s*{' "$FILE" 2>/dev/null || true)
            ;;
        esac
        ;;

      sequelize)
        case "$BASENAME" in
          *.service.ts|*.service.js)
            while IFS= read -r LINE; do
              [ -z "$LINE" ] && continue
              LINENUM=$(echo "$LINE" | cut -d: -f1)
              CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 10))p" "$FILE" 2>/dev/null)
              if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD"; then
                critical ".findAll() without $TENANT_FIELD (line $LINENUM)"
              fi
            done < <(grep -n '\.findAll(' "$FILE" 2>/dev/null || true)
            ;;
        esac
        ;;

      django)
        case "$BASENAME" in
          *.py)
            while IFS= read -r LINE; do
              [ -z "$LINE" ] && continue
              LINENUM=$(echo "$LINE" | cut -d: -f1)
              CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 5))p" "$FILE" 2>/dev/null)
              if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD\|tenant"; then
                warn ".objects.all() without tenant filter (line $LINENUM)"
              fi
            done < <(grep -n '\.objects\.all()\|\.objects\.filter()' "$FILE" 2>/dev/null || true)
            ;;
        esac
        ;;

      sqlalchemy)
        case "$BASENAME" in
          *.py)
            while IFS= read -r LINE; do
              [ -z "$LINE" ] && continue
              LINENUM=$(echo "$LINE" | cut -d: -f1)
              CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 5))p" "$FILE" 2>/dev/null)
              if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD\|tenant"; then
                warn ".query() without tenant filter (line $LINENUM)"
              fi
            done < <(grep -n '\.query(\|session\.query(' "$FILE" 2>/dev/null || true)
            ;;
        esac
        ;;
    esac
  fi

  _ISSUE_CAT="backend-quality"
  # ─── NestJS-specific service checks ───
  case "${BACKEND_FW:-}" in
    nestjs)
      case "$BASENAME" in
        *.service.ts)
          if grep -q '@nestjs/swagger' "$FILE" 2>/dev/null; then
            critical "@nestjs/swagger import — package is NOT installed"
          fi
          # N+1 query detection
          while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            LINENUM=$(echo "$LINE" | cut -d: -f1)
            CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 20))p" "$FILE" 2>/dev/null)
            if echo "$CONTEXT" | grep -q 'await.*this\.prisma\.\|await.*this\..*find\|await.*this\..*delete\|await.*this\..*update\|await.*this\..*create\|await.*this\..*get'; then
              warn "Potential N+1 query — DB call inside loop (line $LINENUM)"
            fi
          done < <(grep -n 'for\s*(.*of\b\|for\s*(\s*let\|for\s*await\s*(\|\.forEach(\s*async\|\.map(\s*async' "$FILE" 2>/dev/null || true)
          ;;
        *.module.ts)
          if grep -q '@nestjs/swagger' "$FILE" 2>/dev/null; then
            critical "@nestjs/swagger import — package is NOT installed"
          fi
          ;;
      esac
      ;;
  esac

fi  # HAS_BACKEND

# ═══════════════════════════════════════
# FRONTEND CHECKS (only if frontend stack detected)
# ═══════════════════════════════════════
if [ "$HAS_FRONTEND" = true ]; then

  _ISSUE_CAT="xss"
  case "${FRONTEND_FW:-}" in
    nextjs|react)
      case "$BASENAME" in
        *.tsx|*.jsx)
          # dangerouslySetInnerHTML
          while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            LINENUM=$(echo "$LINE" | cut -d: -f1)
            critical "dangerouslySetInnerHTML — XSS risk (line $LINENUM)"
          done < <(grep -n 'dangerouslySetInnerHTML' "$FILE" 2>/dev/null || true)

          # Raw fetch() instead of apiClient
          while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            LINENUM=$(echo "$LINE" | cut -d: -f1)
            LINETEXT=$(sed -n "${LINENUM}p" "$FILE" 2>/dev/null)
            case "$LINETEXT" in
              *import*|*//*|*\**) continue ;;
            esac
            warn "Raw fetch() detected — use apiClient instead (line $LINENUM)"
          done < <(grep -n '\bfetch(' "$FILE" 2>/dev/null || true)

          # @nestjs/swagger import (shouldn't be in frontend at all)
          if grep -q '@nestjs/swagger' "$FILE" 2>/dev/null; then
            critical "@nestjs/swagger import — package is NOT installed"
          fi

          # React hook rules
          while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            LINENUM=$(echo "$LINE" | cut -d: -f1)
            warn "useEffect(async ...) — async functions cannot be passed directly to useEffect (line $LINENUM)"
          done < <(grep -n 'useEffect(\s*async' "$FILE" 2>/dev/null || true)

          # Missing cleanup in useEffect
          while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            LINENUM=$(echo "$LINE" | cut -d: -f1)
            CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 30))p" "$FILE" 2>/dev/null)
            if echo "$CONTEXT" | grep -q 'setInterval\|addEventListener'; then
              if ! echo "$CONTEXT" | grep -q 'return.*=>\|return ()'; then
                warn "useEffect with setInterval/addEventListener may be missing cleanup return (line $LINENUM)"
              fi
            fi
          done < <(grep -n 'useEffect(' "$FILE" 2>/dev/null | grep -v 'async' || true)
          ;;
      esac
      ;;

    vue)
      case "$BASENAME" in
        *.vue)
          # v-html (XSS risk)
          while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            LINENUM=$(echo "$LINE" | cut -d: -f1)
            critical "v-html — XSS risk (line $LINENUM)"
          done < <(grep -n 'v-html' "$FILE" 2>/dev/null || true)
          ;;
      esac
      ;;

    svelte)
      case "$BASENAME" in
        *.svelte)
          # {@html} (XSS risk)
          while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            LINENUM=$(echo "$LINE" | cut -d: -f1)
            critical "{@html} — XSS risk (line $LINENUM)"
          done < <(grep -n '{@html' "$FILE" 2>/dev/null || true)
          ;;
      esac
      ;;

    angular)
      case "$BASENAME" in
        *.component.html|*.component.ts)
          # [innerHTML] binding (XSS risk)
          while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            LINENUM=$(echo "$LINE" | cut -d: -f1)
            critical "[innerHTML] binding — XSS risk (line $LINENUM)"
          done < <(grep -n '\[innerHTML\]' "$FILE" 2>/dev/null || true)
          ;;
      esac
      ;;
  esac

fi  # HAS_FRONTEND

# ═══════════════════════════════════════
# SWITCH EXHAUSTIVENESS (TypeScript only)
# ═══════════════════════════════════════
_ISSUE_CAT="switch-exhaustiveness"
case "$BASENAME" in
  *.ts|*.tsx)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 50))p" "$FILE" 2>/dev/null)
      if ! echo "$CONTEXT" | grep -q 'default:'; then
        warn "switch statement without default case — may miss enum values (line $LINENUM)"
      fi
    done < <(grep -n 'switch\s*(' "$FILE" 2>/dev/null || true)
    ;;
esac

# ═══════════════════════════════════════
# PYTHON-SPECIFIC QUALITY CHECKS
# ═══════════════════════════════════════
_ISSUE_CAT="bare-except"
case "$BASENAME" in
  *.py)
    # Bare except (catches everything including SystemExit)
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINENUM=$(echo "$LINE" | cut -d: -f1)
      warn "Bare except: catches all exceptions including SystemExit/KeyboardInterrupt (line $LINENUM)"
    done < <(grep -n '^\s*except\s*:' "$FILE" 2>/dev/null || true)
    ;;
esac

# ═══════════════════════════════════════
# OUTPUT
# ═══════════════════════════════════════

if [ "$CRITICALS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "PASS: check-file $BASENAME — 0 issues"
  exit 0
fi

# Print collected output
printf "$OUTPUT"
echo "---"

if [ "$CRITICALS" -gt 0 ]; then
  echo "check-file: $CRITICALS critical, $WARNINGS warnings in $BASENAME"
  exit 2
else
  echo "check-file: $WARNINGS warnings in $BASENAME"
  exit 0
fi
