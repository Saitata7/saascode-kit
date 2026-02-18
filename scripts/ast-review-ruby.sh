#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — Ruby/Rails AST Code Review
# Pure bash + grep/awk — no external parser required.
# Mirrors ast-review-java.sh output format (table, verdict, exit codes).
#
# Checks:
#   1. Missing before_action auth in controllers
#   2. Unscoped ActiveRecord queries (no tenant/user scope)
#   3. binding.pry / debugger left in code
#   4. Bare rescue without re-raise or logging
#   5. SQL injection (string interpolation in queries)
#   6. Hardcoded secrets
#   7. Mass assignment (permit all / no strong params)
#
# Usage:
#   bash ast-review-ruby.sh [--changed-only] [--path DIR]
#
# Exit codes:
#   0 — No CRITICAL issues (may have WARNINGs)
#   1 — Has CRITICAL issues
#   2 — Runtime error
# ═══════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Globals ──
FINDINGS_FILE=""
FINDING_NUM=0
CRITICAL_COUNT=0
WARNING_COUNT=0
SCANNED=0
CLEAN_FILES=()

# ── Find project root ──
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# ── Parse args ──
CHANGED_ONLY=false
CUSTOM_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --changed-only) CHANGED_ONLY=true ;;
    --path) shift; CUSTOM_PATH="$1" ;;
  esac
  shift
done

# ── Read manifest ──
read_manifest_val() {
  local KEY="$1"
  local DEFAULT="$2"
  local MANIFEST=""
  for CANDIDATE in "$PROJECT_ROOT/saascode-kit/manifest.yaml" \
                   "$PROJECT_ROOT/.saascode/manifest.yaml" \
                   "$PROJECT_ROOT/manifest.yaml" \
                   "$PROJECT_ROOT/saascode-kit.yaml"; do
    [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
  done
  [ -z "$MANIFEST" ] && echo "$DEFAULT" && return

  local SECTION="${KEY%%.*}"
  local FIELD="${KEY#*.}"
  local VAL
  VAL=$(awk -v section="$SECTION" -v field="$FIELD" '
    BEGIN { in_section=0 }
    /^[a-z]/ { if ($1 == section":") in_section=1; else in_section=0; next }
    in_section && /^  [a-z]/ {
      line=$0; sub(/^[[:space:]]+/, "", line)
      if (line ~ "^"field":") {
        val=line; sub(/^[^:]+:[[:space:]]*/, "", val)
        sub(/[[:space:]]+#[[:space:]].*$/, "", val)
        gsub(/^"|"$/, "", val)
        print val; exit
      }
    }
  ' "$MANIFEST")
  echo "${VAL:-$DEFAULT}"
}

# ── Add finding ──
add_finding() {
  local FILE="$1" LINE="$2" SEVERITY="$3" CONFIDENCE="$4" ISSUE="$5" FIX="$6"
  FINDING_NUM=$((FINDING_NUM + 1))
  if [ "$SEVERITY" = "CRITICAL" ]; then
    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
  else
    WARNING_COUNT=$((WARNING_COUNT + 1))
  fi
  echo "${FINDING_NUM}|${FILE}|${LINE}|${SEVERITY}|${CONFIDENCE}|${ISSUE}|${FIX}" >> "$FINDINGS_FILE"
}

# ── Collect Ruby files ──
collect_files() {
  local SEARCH_DIR="$1"
  if [ "$CHANGED_ONLY" = true ]; then
    git diff --name-only HEAD 2>/dev/null | grep '\.rb$' | while read -r f; do
      [ -f "$PROJECT_ROOT/$f" ] && echo "$PROJECT_ROOT/$f"
    done
    return
  fi

  find "$SEARCH_DIR" -name "*.rb" \
    -not -path "*/test/*" \
    -not -path "*/spec/*" \
    -not -path "*/vendor/*" \
    -not -path "*/tmp/*" \
    -not -path "*/log/*" \
    -not -path "*/.git/*" \
    -not -path "*/node_modules/*" \
    -not -name "*_test.rb" \
    -not -name "*_spec.rb" \
    2>/dev/null | sort
}

# ── Check: Missing before_action auth in controllers ──
check_missing_auth() {
  local FILE="$1"
  local REL="$2"

  # Only check controller files
  if ! echo "$REL" | grep -qE '(controllers|controller)'; then
    return
  fi

  # Skip ApplicationController (base class)
  if grep -q 'class ApplicationController' "$FILE" 2>/dev/null; then
    return
  fi

  # Check if controller has before_action for auth
  if grep -q 'class.*Controller' "$FILE" 2>/dev/null; then
    if ! grep -qE '(before_action\s+:authenticate|before_action\s+:require_login|before_action\s+:authorize|devise|authenticate_user!|pundit|cancan|authorize!)' "$FILE" 2>/dev/null; then
      local LINE_NUM
      LINE_NUM=$(grep -n 'class.*Controller' "$FILE" | head -1 | cut -d: -f1)
      add_finding "$REL" "$LINE_NUM" "CRITICAL" "80" \
        "Controller has no authentication before_action" \
        "Add: before_action :authenticate_user! (Devise) or before_action :require_login"
    fi
  fi
}

# ── Check: Unscoped ActiveRecord queries ──
check_unscoped_queries() {
  local FILE="$1"
  local REL="$2"

  # Only check controllers and services, not models
  if echo "$REL" | grep -qE '(models|model|migration|schema|seed)'; then
    return
  fi

  # Pattern: Model.find / Model.where / Model.all without current_user/tenant scope
  while IFS=: read -r LINE_NUM CONTENT; do
    local START=$((LINE_NUM - 3))
    [ "$START" -lt 1 ] && START=1
    local END=$((LINE_NUM + 3))
    local CONTEXT
    CONTEXT=$(sed -n "${START},${END}p" "$FILE" 2>/dev/null)
    if ! echo "$CONTEXT" | grep -qiE '(current_user|current_tenant|tenant|scope|policy|authorize|where.*user_id|where.*tenant_id|where.*organization_id)'; then
      add_finding "$REL" "$LINE_NUM" "WARNING" "65" \
        "ActiveRecord query without visible tenant/user scoping" \
        "Scope to current user: current_user.posts.find(id) instead of Post.find(id)"
    fi
  done < <(grep -n -E '[A-Z][a-zA-Z]+\.(find|find_by|where|all|first|last|pluck|select)\b' "$FILE" 2>/dev/null \
    | grep -v '^\s*#' || true)
}

# ── Check: binding.pry / debugger left in code ──
check_debug_statements() {
  local FILE="$1"
  local REL="$2"

  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "95" \
      "Debug statement left in code — will halt production" \
      "Remove binding.pry / byebug / debugger before committing"
  done < <(grep -n -E '^\s*(binding\.pry|byebug|debugger|binding\.irb|binding\.break)\b' "$FILE" 2>/dev/null || true)
}

# ── Check: Bare rescue without re-raise or logging ──
check_bare_rescue() {
  local FILE="$1"
  local REL="$2"

  # Find rescue blocks that don't re-raise or log
  while read -r RESCUE_LINE; do
    [ -z "$RESCUE_LINE" ] && continue
    add_finding "$REL" "$RESCUE_LINE" "WARNING" "75" \
      "Bare rescue swallows exception without logging or re-raising" \
      "Add logging: Rails.logger.error(e.message) or re-raise: raise"
  done < <(awk '
    /^\s*rescue\b/ {
      rescue_line = NR
      has_log = 0
      has_raise = 0
      in_rescue = 1
      next
    }
    in_rescue {
      if (/Rails\.logger\.|logger\.|log\.|puts\s|raise\b|re_raise|throw/) {
        has_log = 1
      }
      # End of rescue block
      if (/^\s*(end|rescue|ensure|else)\b/ && NR > rescue_line) {
        if (!has_log) {
          print rescue_line
        }
        in_rescue = 0
      }
    }
  ' "$FILE" 2>/dev/null || true)
}

# ── Check: SQL injection (string interpolation in queries) ──
check_sql_injection() {
  local FILE="$1"
  local REL="$2"

  # Pattern: .where("... #{variable} ...")
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "90" \
      "SQL injection: string interpolation in query" \
      "Use parameterized query: .where(\"name = ?\", name) or .where(name: name)"
  done < <(grep -n -E '\.(where|find_by_sql|select|having|order|group|joins)\s*\(\s*"[^"]*#\{' "$FILE" 2>/dev/null \
    | grep -v '^\s*#' || true)

  # Pattern: execute with interpolation
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "90" \
      "SQL injection: string interpolation in raw SQL" \
      "Use sanitize_sql or parameterized query"
  done < <(grep -n -E '(execute|exec_query|select_all)\s*\(\s*"[^"]*#\{' "$FILE" 2>/dev/null \
    | grep -v '^\s*#' || true)
}

# ── Check: Hardcoded secrets ──
check_secrets() {
  local FILE="$1"
  local REL="$2"

  # API keys and tokens
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "90" \
      "Hardcoded secret detected in source" \
      "Move to Rails credentials: Rails.application.credentials.secret_key or ENV['SECRET_KEY']"
  done < <(grep -n -E '(sk_live_|sk_test_|pk_live_|pk_test_|api[_-]?key|apikey|secret[_-]?key|auth[_-]?token|access[_-]?token)\s*=\s*["\x27][^"\x27]{8,}["\x27]' "$FILE" 2>/dev/null \
    | grep -v '^\s*#' | grep -v 'ENV\[' | grep -v 'credentials\.' || true)

  # AWS keys
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "95" \
      "AWS access key hardcoded in source" \
      "Use AWS SDK credential chain or ENV variables"
  done < <(grep -n 'AKIA[0-9A-Z]\{16\}' "$FILE" 2>/dev/null || true)
}

# ── Check: Mass assignment (permit all) ──
check_mass_assignment() {
  local FILE="$1"
  local REL="$2"

  # Pattern: params.permit! (permits everything)
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "95" \
      "Mass assignment vulnerability — params.permit! allows all parameters" \
      "Use explicit permit: params.require(:user).permit(:name, :email)"
  done < <(grep -n 'params\.permit!' "$FILE" 2>/dev/null | grep -v '^\s*#' || true)

  # Pattern: Model.new(params) or Model.create(params) without strong params
  while IFS=: read -r LINE_NUM CONTENT; do
    if ! echo "$CONTENT" | grep -qE '(_params|permitted|sanitize)'; then
      add_finding "$REL" "$LINE_NUM" "WARNING" "70" \
        "Model creation with raw params — may allow mass assignment" \
        "Use strong parameters: Model.new(permitted_params)"
    fi
  done < <(grep -n -E '[A-Z][a-zA-Z]+\.(new|create|update|assign_attributes)\s*\(\s*params\b' "$FILE" 2>/dev/null \
    | grep -v '^\s*#' || true)
}

# ── Main ──
main() {
  FINDINGS_FILE=$(mktemp)
  trap "rm -f $FINDINGS_FILE" EXIT

  BACKEND_PATH=$(read_manifest_val "paths.backend" "app")
  PROJECT_NAME=$(read_manifest_val "project.name" "Ruby Project")
  FRAMEWORK=$(read_manifest_val "stack.backend" "rails")

  if [ -n "$CUSTOM_PATH" ]; then
    BACKEND_PATH="$CUSTOM_PATH"
  fi

  local SEARCH_DIR="$PROJECT_ROOT/$BACKEND_PATH"
  if [ ! -d "$SEARCH_DIR" ]; then
    SEARCH_DIR="$PROJECT_ROOT/app"
    [ ! -d "$SEARCH_DIR" ] && SEARCH_DIR="$PROJECT_ROOT/lib"
    [ ! -d "$SEARCH_DIR" ] && SEARCH_DIR="$PROJECT_ROOT"
  fi

  echo ""
  echo -e "${BOLD}AST Code Review${NC}"
  echo "========================================"
  echo "  Project: $PROJECT_NAME ($FRAMEWORK)"
  echo "  Language: Ruby"
  echo "  Path: $BACKEND_PATH"
  echo ""

  # Collect files
  echo "[1/3] Collecting Ruby files..."
  local FILES
  FILES=$(collect_files "$SEARCH_DIR")
  local FILE_COUNT
  FILE_COUNT=$(echo "$FILES" | grep -c '.' 2>/dev/null || echo "0")
  echo "  Scanning $FILE_COUNT source files"
  echo ""

  if [ "$FILE_COUNT" -eq 0 ]; then
    echo -e "  ${YELLOW}No Ruby files found to scan.${NC}"
    echo ""
    echo -e "${BOLD}VERDICT:${NC} ${GREEN}APPROVE${NC} — No files to review"
    exit 0
  fi

  # Analyze
  echo "[2/3] Analyzing Ruby source..."
  while IFS= read -r RUBY_FILE; do
    [ -z "$RUBY_FILE" ] && continue
    [ ! -f "$RUBY_FILE" ] && continue

    local REL_PATH="${RUBY_FILE#$PROJECT_ROOT/}"
    local BEFORE=$FINDING_NUM
    SCANNED=$((SCANNED + 1))

    check_missing_auth "$RUBY_FILE" "$REL_PATH"
    check_unscoped_queries "$RUBY_FILE" "$REL_PATH"
    check_debug_statements "$RUBY_FILE" "$REL_PATH"
    check_bare_rescue "$RUBY_FILE" "$REL_PATH"
    check_sql_injection "$RUBY_FILE" "$REL_PATH"
    check_secrets "$RUBY_FILE" "$REL_PATH"
    check_mass_assignment "$RUBY_FILE" "$REL_PATH"

    if [ "$FINDING_NUM" -eq "$BEFORE" ]; then
      CLEAN_FILES+=("$REL_PATH")
    fi
  done <<< "$FILES"

  echo "[3/3] Generating report..."
  echo ""

  # Print table
  if [ -s "$FINDINGS_FILE" ]; then
    echo ""
    printf "| %3s | %-40s | %-8s | %-10s | %-60s | %-50s |\n" "#" "File:Line" "Severity" "Confidence" "Issue" "Fix"
    echo "|-----|------------------------------------------|----------|------------|--------------------------------------------------------------|--------------------------------------------------|"
    while IFS='|' read -r NUM FILE LINE SEV CONF ISSUE FIX; do
      local SEV_COLOR
      [ "$SEV" = "CRITICAL" ] && SEV_COLOR="$RED" || SEV_COLOR="$YELLOW"
      printf "| %3s | %s:%s | ${SEV_COLOR}%-8s${NC} | %s%% | %s | %s |\n" \
        "$NUM" "$FILE" "$LINE" "$SEV" "$CONF" "$ISSUE" "$FIX"
    done < "$FINDINGS_FILE"
    echo ""
  fi

  # Summary
  echo "========================================"
  echo "  Files scanned:  $SCANNED"
  echo -e "  Findings:       ${RED}$CRITICAL_COUNT critical${NC}, ${YELLOW}$WARNING_COUNT warnings${NC}"
  echo ""

  # Clean files (max 20)
  if [ ${#CLEAN_FILES[@]} -gt 0 ]; then
    echo "Clean files (no issues):"
    local SHOWN=0
    for CF in "${CLEAN_FILES[@]}"; do
      [ $SHOWN -ge 20 ] && break
      echo -e "  ${GREEN}✓${NC} $CF"
      SHOWN=$((SHOWN + 1))
    done
    local REMAINING=$((${#CLEAN_FILES[@]} - SHOWN))
    [ $REMAINING -gt 0 ] && echo "  ... and $REMAINING more"
    echo ""
  fi

  # Verdict
  if [ "$CRITICAL_COUNT" -gt 0 ]; then
    echo -e "${BOLD}VERDICT:${NC} ${RED}REQUEST CHANGES${NC} — $CRITICAL_COUNT critical issues found"
    exit 1
  elif [ "$WARNING_COUNT" -gt 0 ]; then
    echo -e "${BOLD}VERDICT:${NC} ${YELLOW}COMMENT${NC} — $WARNING_COUNT warnings to consider"
    exit 0
  else
    echo -e "${BOLD}VERDICT:${NC} ${GREEN}APPROVE${NC} — No issues detected"
    exit 0
  fi
}

main
