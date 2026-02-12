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

# Skip test files, type defs, node_modules, lock files
case "$BASENAME" in
  *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx|*.d.ts)
    echo "PASS: check-file $BASENAME — skipped (test/type file)"
    exit 0
    ;;
esac

case "$FILE" in
  */node_modules/*|*/dist/*|*/.next/*|*/coverage/*)
    echo "PASS: check-file $BASENAME — skipped (generated)"
    exit 0
    ;;
esac

# Only check ts/tsx/js/jsx files
case "$BASENAME" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *)
    echo "PASS: check-file $BASENAME — skipped (not JS/TS)"
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
  for CANDIDATE in "$ROOT/saascode-kit/manifest.yaml" "$ROOT/.saascode/manifest.yaml" "$ROOT/manifest.yaml"; do
    [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
  done

  # Defaults: enable everything if no manifest (safe fallback)
  HAS_TENANCY=true
  HAS_AI=false
  HAS_BILLING=false
  HAS_BACKEND=true
  HAS_FRONTEND=true
  TENANT_FIELD="tenantId"

  if [ -n "$MANIFEST" ]; then
    # Quick extraction — each value is a single grep+awk
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

    local T_ENABLED=$(_val "tenancy" "enabled")
    local A_ENABLED=$(_val "ai" "enabled")
    local B_ENABLED=$(_val "billing" "enabled")
    local BE_FW=$(_val "stack" "backend")
    local FE_FW=$(_val "stack" "frontend")
    local T_FIELD=$(_val "tenancy" "identifier")

    [ "$T_ENABLED" = "false" ] && HAS_TENANCY=false
    [ "$A_ENABLED" = "true" ] && HAS_AI=true
    [ "$B_ENABLED" = "true" ] && HAS_BILLING=true
    [ -z "$BE_FW" ] && HAS_BACKEND=false
    [ -z "$FE_FW" ] && HAS_FRONTEND=false
    [ -n "$T_FIELD" ] && TENANT_FIELD="$T_FIELD"
  fi

  # Write cache
  cat > "$CACHE_FILE" << EOF
HAS_TENANCY=$HAS_TENANCY
HAS_AI=$HAS_AI
HAS_BILLING=$HAS_BILLING
HAS_BACKEND=$HAS_BACKEND
HAS_FRONTEND=$HAS_FRONTEND
TENANT_FIELD=$TENANT_FIELD
EOF
}

load_features

# ─── State ───
WARNINGS=0
CRITICALS=0
OUTPUT=""

warn() {
  WARNINGS=$((WARNINGS + 1))
  OUTPUT="${OUTPUT}WARNING: $1\n"
}

critical() {
  CRITICALS=$((CRITICALS + 1))
  OUTPUT="${OUTPUT}BLOCKED: $1\n"
}

# ═══════════════════════════════════════
# UNIVERSAL CHECKS (always run)
# ═══════════════════════════════════════

# Hardcoded secrets (skip type definitions, interfaces, env refs)
while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  LINENUM=$(echo "$LINE" | cut -d: -f1)
  critical "Hardcoded secret detected (line $LINENUM)"
done < <(grep -n -i 'password\s*=\s*["\x27].\+["\x27]\|secret\s*=\s*["\x27].\+["\x27]\|api[_-]\?key\s*=\s*["\x27].\+["\x27]' "$FILE" 2>/dev/null | grep -v 'process\.env\|@Is\|interface \|type \|\.env\|example\|placeholder\|test\|mock\|TODO\|FIXME' || true)

# eval() usage
while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  LINENUM=$(echo "$LINE" | cut -d: -f1)
  critical "eval() usage detected (line $LINENUM)"
done < <(grep -n '\beval(' "$FILE" 2>/dev/null | grep -v '//.*eval\|/\*.*eval' || true)

# rejectUnauthorized: false
while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  LINENUM=$(echo "$LINE" | cut -d: -f1)
  critical "rejectUnauthorized: false — TLS verification disabled (line $LINENUM)"
done < <(grep -n 'rejectUnauthorized.*false' "$FILE" 2>/dev/null || true)

# Raw SQL with string interpolation
while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  LINENUM=$(echo "$LINE" | cut -d: -f1)
  critical "Raw SQL with string interpolation (line $LINENUM)"
done < <(grep -n '\$queryRaw\s*`\|\$executeRaw\s*`' "$FILE" 2>/dev/null | grep -v 'Prisma\.sql' || true)

# Sensitive data in console.log
while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  LINENUM=$(echo "$LINE" | cut -d: -f1)
  warn "Sensitive data in console.log (line $LINENUM)"
done < <(grep -n -i 'console\.log.*\(token\|secret\|password\|apiKey\|authorization\)' "$FILE" 2>/dev/null || true)

# console.log in non-test source files (warning only)
case "$FILE" in
  *.test.*|*.spec.*|*__tests__*) ;;
  *)
    CONSOLE_COUNT=$(grep -c 'console\.log' "$FILE" 2>/dev/null) || CONSOLE_COUNT=0
    if [ "$CONSOLE_COUNT" -gt 0 ]; then
      warn "console.log found ($CONSOLE_COUNT occurrences) — remove before deploy"
    fi
    ;;
esac

# ═══════════════════════════════════════
# AI/LLM CHECKS (only if ai.enabled=true)
# ═══════════════════════════════════════
if [ "$HAS_AI" = true ]; then

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

  # ─── Controller checks ───
  case "$BASENAME" in
    *.controller.ts)
      # Must have @UseGuards on the controller class
      if ! grep -q '@UseGuards(' "$FILE" 2>/dev/null; then
        critical "Missing @UseGuards on controller class"
      fi

      # @Roles() without RolesGuard in same file
      if grep -q '@Roles(' "$FILE" 2>/dev/null; then
        if ! grep -q 'RolesGuard' "$FILE" 2>/dev/null; then
          critical "@Roles() found but no RolesGuard in file — roles silently ignored"
        fi
      fi

      # Tenant extraction (only if tenancy enabled)
      if [ "$HAS_TENANCY" = true ]; then
        if grep -q 'TenantGuard\|RolesGuard' "$FILE" 2>/dev/null; then
          if ! grep -q '@CurrentTenant\|@CurrentOrgId\|clerkOrgId' "$FILE" 2>/dev/null; then
            warn "Controller has guards but no tenant extraction (@CurrentTenant or @CurrentOrgId)"
          fi
        fi
      fi

      # @nestjs/swagger import (not installed)
      if grep -q '@nestjs/swagger' "$FILE" 2>/dev/null; then
        critical "@nestjs/swagger import — package is NOT installed"
      fi
      ;;
  esac

  # ─── Service checks ───
  case "$BASENAME" in
    *.service.ts)
      # Tenant scoping (only if tenancy enabled)
      if [ "$HAS_TENANCY" = true ]; then
        # findMany() without tenantId
        while IFS= read -r LINE; do
          [ -z "$LINE" ] && continue
          LINENUM=$(echo "$LINE" | cut -d: -f1)
          CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 10))p" "$FILE" 2>/dev/null)
          if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD"; then
            critical "findMany() without $TENANT_FIELD in where clause (line $LINENUM)"
          fi
        done < <(grep -n '\.findMany(' "$FILE" 2>/dev/null || true)

        # deleteMany/updateMany without tenantId
        while IFS= read -r LINE; do
          [ -z "$LINE" ] && continue
          LINENUM=$(echo "$LINE" | cut -d: -f1)
          CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 10))p" "$FILE" 2>/dev/null)
          if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD"; then
            critical "deleteMany()/updateMany() without $TENANT_FIELD (line $LINENUM)"
          fi
        done < <(grep -n '\.deleteMany(\|\.updateMany(' "$FILE" 2>/dev/null || true)

        # findUnique without ownership check
        while IFS= read -r LINE; do
          [ -z "$LINE" ] && continue
          LINENUM=$(echo "$LINE" | cut -d: -f1)
          CONTEXT=$(sed -n "${LINENUM},$((LINENUM + 15))p" "$FILE" 2>/dev/null)
          if ! echo "$CONTEXT" | grep -q "$TENANT_FIELD"; then
            warn "findUnique() without $TENANT_FIELD check — verify ownership is enforced (line $LINENUM)"
          fi
        done < <(grep -n '\.findUnique(\|\.findFirst(' "$FILE" 2>/dev/null || true)
      fi

      # @nestjs/swagger import
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
  esac

  # ─── Module checks ───
  case "$BASENAME" in
    *.module.ts)
      if grep -q '@nestjs/swagger' "$FILE" 2>/dev/null; then
        critical "@nestjs/swagger import — package is NOT installed"
      fi
      ;;
  esac

fi  # HAS_BACKEND

# ═══════════════════════════════════════
# FRONTEND CHECKS (only if frontend stack detected)
# ═══════════════════════════════════════
if [ "$HAS_FRONTEND" = true ]; then

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

fi  # HAS_FRONTEND

# ═══════════════════════════════════════
# SWITCH EXHAUSTIVENESS (always — universal TS quality)
# ═══════════════════════════════════════
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
