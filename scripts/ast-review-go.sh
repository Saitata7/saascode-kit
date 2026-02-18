#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Kit — Go AST Code Review
# Pure bash + grep/awk — no external parser required.
# Mirrors ast-review-java.sh output format (table, verdict, exit codes).
#
# Checks:
#   1. Missing auth middleware on HTTP handlers
#   2. Unscoped DB queries (no tenant/user WHERE clause)
#   3. fmt.Println in production code
#   4. Error swallowing (err ignored or empty if-err block)
#   5. SQL injection (string concatenation in queries)
#   6. Hardcoded secrets
#   7. Unsafe HTTP (http.ListenAndServe without TLS)
#
# Usage:
#   bash ast-review-go.sh [--changed-only] [--path DIR]
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

# ── Collect Go files ──
collect_files() {
  local SEARCH_DIR="$1"
  if [ "$CHANGED_ONLY" = true ]; then
    git diff --name-only HEAD 2>/dev/null | grep '\.go$' | while read -r f; do
      [ -f "$PROJECT_ROOT/$f" ] && echo "$PROJECT_ROOT/$f"
    done
    return
  fi

  find "$SEARCH_DIR" -name "*.go" \
    -not -name "*_test.go" \
    -not -path "*/vendor/*" \
    -not -path "*/testdata/*" \
    -not -path "*/.git/*" \
    -not -path "*/node_modules/*" \
    2>/dev/null | sort
}

# ── Check: Missing auth middleware on HTTP handlers ──
check_missing_auth() {
  local FILE="$1"
  local REL="$2"

  # Look for http.HandleFunc / router.GET / r.HandleFunc without auth middleware nearby
  # Check for handler registrations
  while IFS=: read -r LINE_NUM CONTENT; do
    # Skip if auth middleware is referenced within 5 lines above
    local START=$((LINE_NUM - 5))
    [ "$START" -lt 1 ] && START=1
    local CONTEXT
    CONTEXT=$(sed -n "${START},${LINE_NUM}p" "$FILE" 2>/dev/null)
    if ! echo "$CONTEXT" | grep -qiE '(auth|middleware|jwt|token|session|guard|protect|secure)'; then
      add_finding "$REL" "$LINE_NUM" "WARNING" "70" \
        "HTTP handler registered without visible auth middleware" \
        "Wrap with auth middleware: r.Use(authMiddleware) or add auth check in handler group"
    fi
  done < <(grep -n -E '(HandleFunc|\.GET|\.POST|\.PUT|\.DELETE|\.PATCH)\s*\(' "$FILE" 2>/dev/null \
    | grep -v '_test\.go' | grep -v '^\s*//' || true)
}

# ── Check: Unscoped DB queries (no tenant/user filter) ──
check_unscoped_queries() {
  local FILE="$1"
  local REL="$2"

  # Pattern: db.Find / db.First / db.Where without tenant or user scoping
  while IFS=: read -r LINE_NUM CONTENT; do
    # Check if the line or nearby lines have tenant/user scoping
    local START=$((LINE_NUM - 3))
    [ "$START" -lt 1 ] && START=1
    local END=$((LINE_NUM + 3))
    local CONTEXT
    CONTEXT=$(sed -n "${START},${END}p" "$FILE" 2>/dev/null)
    if ! echo "$CONTEXT" | grep -qiE '(tenant|org_id|organization_id|user_id|owner_id|account_id|workspace_id|Where)'; then
      add_finding "$REL" "$LINE_NUM" "WARNING" "65" \
        "DB query without visible tenant/user scoping — potential data leak" \
        "Add tenant filter: db.Where(\"tenant_id = ?\", tenantID).Find(&results)"
    fi
  done < <(grep -n -E 'db\.(Find|First|Last|Take|Scan|Raw|Exec)\s*\(' "$FILE" 2>/dev/null \
    | grep -v '^\s*//' || true)
}

# ── Check: fmt.Println / fmt.Printf in production code ──
check_fmt_println() {
  local FILE="$1"
  local REL="$2"

  # Skip main.go (may legitimately use fmt for CLI output)
  local BASENAME
  BASENAME=$(basename "$FILE")
  [ "$BASENAME" = "main.go" ] && return

  local MATCHES
  MATCHES=$(grep -n -E 'fmt\.(Print|Println|Printf)\s*\(' "$FILE" 2>/dev/null | grep -v '^\s*//' || true)
  local COUNT
  COUNT=$(echo "$MATCHES" | grep -c '.' 2>/dev/null || echo "0")

  if [ "$COUNT" -gt 3 ]; then
    local FIRST_LINE
    FIRST_LINE=$(echo "$MATCHES" | head -1 | cut -d: -f1)
    add_finding "$REL" "$FIRST_LINE" "WARNING" "80" \
      "$COUNT fmt.Print statements in production code" \
      "Replace with structured logger: log.Info(), zap.L().Info(), or slog.Info()"
  elif [ "$COUNT" -gt 0 ]; then
    while IFS=: read -r LINE_NUM CONTENT; do
      add_finding "$REL" "$LINE_NUM" "WARNING" "75" \
        "fmt.Println in production code — use structured logging" \
        "Replace with log.Info() or your project's logger"
    done < <(echo "$MATCHES")
  fi
}

# ── Check: Error swallowing (ignored err or empty if-err block) ──
check_error_swallowing() {
  local FILE="$1"
  local REL="$2"

  # Pattern 1: Assigning to _ for error: val, _ := someFunc()
  while IFS=: read -r LINE_NUM CONTENT; do
    # Skip if it's a well-known acceptable case (e.g., io.Copy, fmt.Fprintf to response)
    if ! echo "$CONTENT" | grep -qE '(io\.Copy|fmt\.Fprint|fmt\.Fprintf|defer|Close\(\))'; then
      add_finding "$REL" "$LINE_NUM" "WARNING" "80" \
        "Error explicitly ignored with _ — may hide failures" \
        "Handle the error: if err != nil { return fmt.Errorf(\"context: %w\", err) }"
    fi
  done < <(grep -n -E ',\s*_\s*(:=|=)\s*\S+\(' "$FILE" 2>/dev/null \
    | grep -v '^\s*//' | grep -v '_test\.go' || true)

  # Pattern 2: if err != nil block that's empty or just has return
  while read -r EMPTY_LINE; do
    [ -z "$EMPTY_LINE" ] && continue
    add_finding "$REL" "$EMPTY_LINE" "WARNING" "70" \
      "Error checked but not logged or wrapped" \
      "Add context: return fmt.Errorf(\"operation failed: %w\", err)"
  done < <(awk '
    /if err != nil/ {
      err_line = NR
      brace_count = 0
      body_lines = 0
      has_log = 0
      in_block = 1
    }
    in_block {
      n = gsub(/{/, "{")
      brace_count += n
      m = gsub(/}/, "}")
      brace_count -= m
      if (NR != err_line) {
        body_lines++
        line = $0
        gsub(/^[[:space:]]+/, "", line)
        gsub(/[[:space:]]+$/, "", line)
        if (line ~ /(log\.|slog\.|zap\.|fmt\.Errorf|errors\.Wrap|Wrap\()/) {
          has_log = 1
        }
      }
      if (brace_count == 0 && NR > err_line) {
        if (!has_log && body_lines <= 2) {
          print err_line
        }
        in_block = 0
      }
    }
  ' "$FILE" 2>/dev/null || true)
}

# ── Check: SQL injection (string concatenation in queries) ──
check_sql_injection() {
  local FILE="$1"
  local REL="$2"

  # Pattern: string concatenation in SQL queries
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "90" \
      "SQL injection: string concatenation in query" \
      "Use parameterized queries: db.Raw(\"SELECT * FROM users WHERE id = ?\", id)"
  done < <(grep -n -E '(Raw|Exec|Query|QueryRow)\s*\(\s*"[^"]*"\s*\+' "$FILE" 2>/dev/null \
    | grep -v '^\s*//' || true)

  # Pattern: fmt.Sprintf in SQL
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "90" \
      "SQL injection: fmt.Sprintf used to build query" \
      "Use parameterized queries instead of string formatting"
  done < <(grep -n -E '(Raw|Exec|Query|QueryRow)\s*\(\s*fmt\.Sprintf' "$FILE" 2>/dev/null \
    | grep -v '^\s*//' || true)
}

# ── Check: Hardcoded secrets ──
check_secrets() {
  local FILE="$1"
  local REL="$2"

  # API keys and tokens
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "90" \
      "Hardcoded secret detected in source" \
      "Move to environment variable: os.Getenv(\"SECRET_KEY\")"
  done < <(grep -n -E '(sk_live_|sk_test_|pk_live_|pk_test_|api[_-]?key|apikey|secret[_-]?key|auth[_-]?token|access[_-]?token)\s*=\s*"[^"]{8,}"' "$FILE" 2>/dev/null \
    | grep -v '^\s*//' | grep -v 'os\.Getenv\|viper\.\|env\.' || true)

  # AWS keys
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "95" \
      "AWS access key hardcoded in source" \
      "Use AWS SDK credential chain or os.Getenv"
  done < <(grep -n 'AKIA[0-9A-Z]\{16\}' "$FILE" 2>/dev/null || true)
}

# ── Check: Unsafe HTTP server ──
check_unsafe_http() {
  local FILE="$1"
  local REL="$2"

  while IFS=: read -r LINE_NUM CONTENT; do
    if ! echo "$CONTENT" | grep -q 'TLS\|tls\|ListenAndServeTLS'; then
      add_finding "$REL" "$LINE_NUM" "WARNING" "60" \
        "HTTP server without TLS — traffic is unencrypted" \
        "Use http.ListenAndServeTLS() or put behind a TLS-terminating reverse proxy"
    fi
  done < <(grep -n 'http\.ListenAndServe\b' "$FILE" 2>/dev/null \
    | grep -v '^\s*//' | grep -v 'ListenAndServeTLS' || true)
}

# ── Main ──
main() {
  FINDINGS_FILE=$(mktemp)
  trap "rm -f $FINDINGS_FILE" EXIT

  BACKEND_PATH=$(read_manifest_val "paths.backend" ".")
  PROJECT_NAME=$(read_manifest_val "project.name" "Go Project")
  FRAMEWORK=$(read_manifest_val "stack.backend" "stdlib")

  if [ -n "$CUSTOM_PATH" ]; then
    BACKEND_PATH="$CUSTOM_PATH"
  fi

  local SEARCH_DIR="$PROJECT_ROOT/$BACKEND_PATH"
  if [ ! -d "$SEARCH_DIR" ]; then
    SEARCH_DIR="$PROJECT_ROOT/cmd"
    [ ! -d "$SEARCH_DIR" ] && SEARCH_DIR="$PROJECT_ROOT/internal"
    [ ! -d "$SEARCH_DIR" ] && SEARCH_DIR="$PROJECT_ROOT"
  fi

  echo ""
  echo -e "${BOLD}AST Code Review${NC}"
  echo "========================================"
  echo "  Project: $PROJECT_NAME ($FRAMEWORK)"
  echo "  Language: Go"
  echo "  Path: $BACKEND_PATH"
  echo ""

  # Collect files
  echo "[1/3] Collecting Go files..."
  local FILES
  FILES=$(collect_files "$SEARCH_DIR")
  local FILE_COUNT
  FILE_COUNT=$(echo "$FILES" | grep -c '.' 2>/dev/null || echo "0")
  echo "  Scanning $FILE_COUNT source files"
  echo ""

  if [ "$FILE_COUNT" -eq 0 ]; then
    echo -e "  ${YELLOW}No Go files found to scan.${NC}"
    echo ""
    echo -e "${BOLD}VERDICT:${NC} ${GREEN}APPROVE${NC} — No files to review"
    exit 0
  fi

  # Analyze
  echo "[2/3] Analyzing Go source..."
  while IFS= read -r GO_FILE; do
    [ -z "$GO_FILE" ] && continue
    [ ! -f "$GO_FILE" ] && continue

    local REL_PATH="${GO_FILE#$PROJECT_ROOT/}"
    local BEFORE=$FINDING_NUM
    SCANNED=$((SCANNED + 1))

    check_missing_auth "$GO_FILE" "$REL_PATH"
    check_unscoped_queries "$GO_FILE" "$REL_PATH"
    check_fmt_println "$GO_FILE" "$REL_PATH"
    check_error_swallowing "$GO_FILE" "$REL_PATH"
    check_sql_injection "$GO_FILE" "$REL_PATH"
    check_secrets "$GO_FILE" "$REL_PATH"
    check_unsafe_http "$GO_FILE" "$REL_PATH"

    if [ "$FINDING_NUM" -eq "$BEFORE" ]; then
      CLEAN_FILES+=("$REL_PATH")
    fi
  done <<< "$FILES"

  echo "[3/3] Generating report..."
  echo ""

  local CLEAN_STR=""
  for CF in "${CLEAN_FILES[@]}"; do
    CLEAN_STR="${CLEAN_STR}${CF}\n"
  done

  local FORMATTER="$(dirname "$0")/review-formatter.sh"
  local FMT="${SAASCODE_OUTPUT_FORMAT:-table}"
  if [ -f "$FORMATTER" ]; then
    source "$FORMATTER"
    format_findings "$FINDINGS_FILE" "$FMT" "$SCANNED" "$CRITICAL_COUNT" "$WARNING_COUNT" "go" "$(printf "$CLEAN_STR")"
  else
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
    echo "========================================"
    echo "  Files scanned:  $SCANNED"
    echo -e "  Findings:       ${RED}$CRITICAL_COUNT critical${NC}, ${YELLOW}$WARNING_COUNT warnings${NC}"
    echo ""
  fi

  [ "$CRITICAL_COUNT" -gt 0 ] && exit 1
  exit 0
}

main
