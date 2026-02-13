#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — Java AST Code Review
# Pure bash + grep/awk — no external parser required.
# Mirrors ast-review.ts output format (table, verdict, exit codes).
#
# Usage:
#   bash ast-review-java.sh [--changed-only] [--path DIR]
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

# ── Collect Java files ──
collect_files() {
  local SEARCH_DIR="$1"
  if [ "$CHANGED_ONLY" = true ]; then
    git diff --name-only HEAD 2>/dev/null | grep '\.java$' | while read -r f; do
      [ -f "$PROJECT_ROOT/$f" ] && echo "$PROJECT_ROOT/$f"
    done
    return
  fi

  find "$SEARCH_DIR" -name "*.java" \
    -not -path "*/test/*" \
    -not -path "*/tests/*" \
    -not -path "*/target/*" \
    -not -path "*/build/*" \
    -not -path "*/.gradle/*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    2>/dev/null | sort
}

# ── Check: Missing @PreAuthorize/@Secured on REST controller methods ──
check_missing_auth() {
  local FILE="$1"
  local REL="$2"

  # Only check files with @RestController or @Controller
  if ! grep -q '@\(RestController\|Controller\)' "$FILE" 2>/dev/null; then
    return
  fi

  # Find mapping annotations without auth annotations
  local PREV_LINE=""
  local LINE_NUM=0
  local IN_METHOD_AREA=false
  local AUTH_FOUND=false
  local MAPPING_LINE=0
  local MAPPING_METHOD=""

  while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))

    # Check for auth annotations (may appear lines before mapping)
    if echo "$line" | grep -qE '@(PreAuthorize|Secured|RolesAllowed)'; then
      AUTH_FOUND=true
    fi

    # Check for mapping annotations
    if echo "$line" | grep -qE '@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping|RequestMapping)'; then
      if [ "$AUTH_FOUND" = false ]; then
        MAPPING_METHOD=$(echo "$line" | grep -oE '@(Get|Post|Put|Delete|Patch|Request)Mapping')
        add_finding "$REL" "$LINE_NUM" "CRITICAL" "85" \
          "REST endpoint ($MAPPING_METHOD) has no @PreAuthorize or @Secured annotation" \
          "Add @PreAuthorize(\"hasRole('USER')\") or @Secured(\"ROLE_USER\")"
      fi
      AUTH_FOUND=false
    fi

    # Reset auth tracking on blank lines or method signatures
    if echo "$line" | grep -qE '^\s*$|^\s*(public|private|protected)'; then
      AUTH_FOUND=false
    fi
  done < "$FILE"
}

# ── Check: Missing @Valid on @RequestBody ──
check_missing_valid() {
  local FILE="$1"
  local REL="$2"

  while IFS=: read -r LINE_NUM CONTENT; do
    if ! echo "$CONTENT" | grep -q '@Valid'; then
      add_finding "$REL" "$LINE_NUM" "WARNING" "80" \
        "@RequestBody parameter missing @Valid annotation — input not validated" \
        "Add @Valid before @RequestBody: methodName(@Valid @RequestBody Dto dto)"
    fi
  done < <(grep -n '@RequestBody' "$FILE" 2>/dev/null || true)
}

# ── Check: Empty catch blocks ──
check_empty_catch() {
  local FILE="$1"
  local REL="$2"

  # Use awk state machine to find catch blocks with empty or pass-only bodies
  while read -r CATCH_LINE; do
    add_finding "$REL" "$CATCH_LINE" "WARNING" "85" \
      "Empty catch block silently swallows exception" \
      "Add logging (logger.error), re-throw, or add a comment explaining why"
  done < <(awk -v rel="$REL" '
    /catch\s*\(/ {
      catch_line = NR
      brace_count = 0
      body_lines = 0
      has_content = 0
      in_catch = 1
    }
    in_catch {
      # Count braces
      n = gsub(/{/, "{")
      brace_count += n
      m = gsub(/}/, "}")
      brace_count -= m
      if (NR != catch_line) {
        body_lines++
        line = $0
        gsub(/^[[:space:]]+/, "", line)
        gsub(/[[:space:]]+$/, "", line)
        if (line != "" && line != "{" && line != "}" && line !~ /^\/\//) {
          has_content = 1
        }
      }
      if (brace_count == 0 && NR > catch_line) {
        if (!has_content && body_lines <= 3) {
          print catch_line
        }
        in_catch = 0
      }
    }
  ' "$FILE" || true)
}

# ── Check: System.out.println in production ──
check_sysout() {
  local FILE="$1"
  local REL="$2"

  local MATCHES
  MATCHES=$(grep -n 'System\.out\.print\|System\.err\.print' "$FILE" 2>/dev/null || true)
  local COUNT
  COUNT=$(echo "$MATCHES" | grep -c '.' 2>/dev/null || echo "0")

  if [ "$COUNT" -gt 3 ]; then
    local FIRST_LINE
    FIRST_LINE=$(echo "$MATCHES" | head -1 | cut -d: -f1)
    add_finding "$REL" "$FIRST_LINE" "WARNING" "80" \
      "$COUNT System.out.println/print statements found in production code" \
      "Replace with SLF4J logger: private static final Logger log = LoggerFactory.getLogger(ClassName.class)"
  elif [ "$COUNT" -gt 0 ]; then
    while IFS=: read -r LINE_NUM CONTENT; do
      add_finding "$REL" "$LINE_NUM" "WARNING" "75" \
        "System.out.println in production code" \
        "Replace with logger.info() or logger.debug()"
    done < <(echo "$MATCHES")
  fi
}

# ── Check: SQL injection (string concatenation in queries) ──
check_sql_injection() {
  local FILE="$1"
  local REL="$2"

  # Pattern: createQuery/execute with string concatenation
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "90" \
      "SQL injection: string concatenation in query construction" \
      "Use parameterized queries: createQuery(\"SELECT u FROM User u WHERE u.id = :id\").setParameter(\"id\", id)"
  done < <(grep -n -E '(createQuery|createNativeQuery|execute|executeQuery|executeUpdate|prepareStatement)\s*\(\s*"[^"]*"\s*\+' "$FILE" 2>/dev/null || true)

  # Pattern: String.format in query
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "90" \
      "SQL injection: String.format used to build query" \
      "Use parameterized queries instead of String.format"
  done < <(grep -n -E '(createQuery|execute)\s*\(\s*String\.format' "$FILE" 2>/dev/null || true)
}

# ── Check: Hardcoded secrets ──
check_secrets() {
  local FILE="$1"
  local REL="$2"

  # Skip lines with @Value or System.getenv
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "90" \
      "Hardcoded secret detected in source" \
      "Move to application.properties with @Value or use environment variables"
  done < <(grep -n -E '(sk_live_|sk_test_|pk_live_|pk_test_|api[_-]?key|apikey|secret[_-]?key|auth[_-]?token|access[_-]?token)\s*=\s*"[^"]{8,}"' "$FILE" 2>/dev/null | grep -v '@Value\|System\.getenv\|getProperty' || true)

  # AWS keys
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "95" \
      "AWS access key hardcoded in source" \
      "Use AWS SDK credential chain or environment variables"
  done < <(grep -n 'AKIA[0-9A-Z]\{16\}' "$FILE" 2>/dev/null || true)

  # Bearer tokens
  while IFS=: read -r LINE_NUM CONTENT; do
    add_finding "$REL" "$LINE_NUM" "CRITICAL" "85" \
      "Hardcoded Bearer token in source" \
      "Move token to secure configuration or environment variable"
  done < <(grep -n 'Bearer [A-Za-z0-9_\.\-]\{20,\}' "$FILE" 2>/dev/null | grep -v '//\|/\*\|\*' || true)
}

# ── Main ──
main() {
  FINDINGS_FILE=$(mktemp)
  trap "rm -f $FINDINGS_FILE" EXIT

  BACKEND_PATH=$(read_manifest_val "paths.backend" "src/main")
  PROJECT_NAME=$(read_manifest_val "project.name" "Java Project")
  FRAMEWORK=$(read_manifest_val "stack.backend.framework" "spring")

  if [ -n "$CUSTOM_PATH" ]; then
    BACKEND_PATH="$CUSTOM_PATH"
  fi

  local SEARCH_DIR="$PROJECT_ROOT/$BACKEND_PATH"
  # Fallback: if backend path doesn't exist, try src/main/java
  if [ ! -d "$SEARCH_DIR" ]; then
    SEARCH_DIR="$PROJECT_ROOT/src/main"
    [ ! -d "$SEARCH_DIR" ] && SEARCH_DIR="$PROJECT_ROOT/src"
    [ ! -d "$SEARCH_DIR" ] && SEARCH_DIR="$PROJECT_ROOT"
  fi

  echo ""
  echo -e "${BOLD}AST Code Review${NC}"
  echo "========================================"
  echo "  Project: $PROJECT_NAME ($FRAMEWORK)"
  echo "  Language: Java"
  echo "  Path: $BACKEND_PATH"
  echo ""

  # Collect files
  echo "[1/3] Collecting Java files..."
  local FILES
  FILES=$(collect_files "$SEARCH_DIR")
  local FILE_COUNT
  FILE_COUNT=$(echo "$FILES" | grep -c '.' 2>/dev/null || echo "0")
  echo "  Scanning $FILE_COUNT source files"
  echo ""

  if [ "$FILE_COUNT" -eq 0 ]; then
    echo -e "  ${YELLOW}No Java files found to scan.${NC}"
    echo ""
    echo -e "${BOLD}VERDICT:${NC} ${GREEN}APPROVE${NC} — No files to review"
    exit 0
  fi

  # Analyze
  echo "[2/3] Analyzing Java source..."
  while IFS= read -r JAVA_FILE; do
    [ -z "$JAVA_FILE" ] && continue
    [ ! -f "$JAVA_FILE" ] && continue

    local REL_PATH="${JAVA_FILE#$PROJECT_ROOT/}"
    local BEFORE=$FINDING_NUM
    SCANNED=$((SCANNED + 1))

    check_missing_auth "$JAVA_FILE" "$REL_PATH"
    check_missing_valid "$JAVA_FILE" "$REL_PATH"
    check_empty_catch "$JAVA_FILE" "$REL_PATH"
    check_sysout "$JAVA_FILE" "$REL_PATH"
    check_sql_injection "$JAVA_FILE" "$REL_PATH"
    check_secrets "$JAVA_FILE" "$REL_PATH"

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
