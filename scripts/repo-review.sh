#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Kit — Repo-Level Code Review
# Scans the full codebase for cross-module issues:
#   1. Circular imports / circular dependencies
#   2. Unused exports (exported but never imported elsewhere)
#   3. Orphan files (source files not imported by anything)
#   4. Missing index files (directories without barrel exports)
#   5. Cross-module tenant scoping gaps
#   6. Endpoint parity (frontend calls vs backend routes)
#
# Usage:
#   bash repo-review.sh [--path DIR] [--json] [--sarif]
#
# Exit codes:
#   0 — No critical issues
#   1 — Critical cross-module issues found
# ═══════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CUSTOM_PATH=""
OUTPUT_FORMAT="${SAASCODE_OUTPUT_FORMAT:-table}"

while [ $# -gt 0 ]; do
  case "$1" in
    --path) shift; CUSTOM_PATH="$1" ;;
    --json) OUTPUT_FORMAT="json" ;;
    --sarif) OUTPUT_FORMAT="sarif" ;;
  esac
  shift
done

SCAN_DIR="${CUSTOM_PATH:-$PROJECT_ROOT}"

# ── Globals ──
FINDINGS_FILE=$(mktemp)
FINDING_NUM=0
CRITICAL_COUNT=0
WARNING_COUNT=0
trap "rm -f $FINDINGS_FILE" EXIT

add_finding() {
  local FILE="$1" LINE="$2" SEVERITY="$3" CONFIDENCE="$4" ISSUE="$5" FIX="$6"
  FINDING_NUM=$((FINDING_NUM + 1))
  [ "$SEVERITY" = "CRITICAL" ] && CRITICAL_COUNT=$((CRITICAL_COUNT + 1)) || WARNING_COUNT=$((WARNING_COUNT + 1))
  echo "${FINDING_NUM}|${FILE}|${LINE}|${SEVERITY}|${CONFIDENCE}|${ISSUE}|${FIX}" >> "$FINDINGS_FILE"
}

# ── Detect language ──
detect_lang() {
  if [ -f "$PROJECT_ROOT/tsconfig.json" ]; then echo "typescript"
  elif [ -f "$PROJECT_ROOT/go.mod" ]; then echo "go"
  elif [ -f "$PROJECT_ROOT/requirements.txt" ] || [ -f "$PROJECT_ROOT/manage.py" ]; then echo "python"
  elif [ -f "$PROJECT_ROOT/Gemfile" ]; then echo "ruby"
  elif [ -f "$PROJECT_ROOT/pom.xml" ]; then echo "java"
  elif [ -f "$PROJECT_ROOT/composer.json" ]; then echo "php"
  elif [ -f "$PROJECT_ROOT/package.json" ]; then echo "javascript"
  else echo "unknown"
  fi
}

LANG=$(detect_lang)

echo ""
echo -e "${BOLD}Repo-Level Code Review${NC}"
echo "========================================"
echo "  Language: $LANG"
echo "  Path: $SCAN_DIR"
echo ""

# ═══════════════════════════════════════
# CHECK 1: Circular Imports
# ═══════════════════════════════════════
echo "[1/5] Checking for circular imports..."

check_circular_ts() {
  # Build import graph and detect cycles for TS/JS
  local IMPORT_MAP=$(mktemp)
  trap "rm -f $IMPORT_MAP $FINDINGS_FILE" EXIT

  # Extract all import relationships
  find "$SCAN_DIR" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.next/*" \
    -not -name "*.test.*" -not -name "*.spec.*" -not -name "*.d.ts" \
    2>/dev/null | while read -r SRC_FILE; do
      local SRC_REL="${SRC_FILE#$PROJECT_ROOT/}"
      grep -oE "from ['\"](\./[^'\"]+)['\"]" "$SRC_FILE" 2>/dev/null | \
        sed "s/from ['\"]//; s/['\"]$//" | while read -r IMPORT; do
          local SRC_DIR
          SRC_DIR=$(dirname "$SRC_FILE")
          # Resolve relative import
          local TARGET="$SRC_DIR/$IMPORT"
          for EXT in ".ts" ".tsx" ".js" ".jsx" "/index.ts" "/index.tsx" "/index.js"; do
            if [ -f "${TARGET}${EXT}" ]; then
              local TGT_REL="${TARGET}${EXT}"
              TGT_REL="${TGT_REL#$PROJECT_ROOT/}"
              echo "$SRC_REL -> $TGT_REL"
              break
            fi
          done
        done
  done > "$IMPORT_MAP"

  # Detect simple A->B->A cycles
  while read -r LINE; do
    local FROM=$(echo "$LINE" | awk -F' -> ' '{print $1}')
    local TO=$(echo "$LINE" | awk -F' -> ' '{print $2}')
    [ -z "$TO" ] && continue
    # Check if TO imports FROM (cycle)
    if grep -q "^$TO -> $FROM$" "$IMPORT_MAP" 2>/dev/null; then
      add_finding "$FROM" "1" "WARNING" "75" \
        "Circular import: $FROM <-> $TO" \
        "Extract shared code to a separate module or use lazy imports"
    fi
  done < "$IMPORT_MAP"

  rm -f "$IMPORT_MAP"
}

check_circular_py() {
  # Check Python circular imports (from .X import Y)
  find "$SCAN_DIR" -name "*.py" \
    -not -path "*/venv/*" -not -path "*/.venv/*" -not -path "*/__pycache__/*" \
    -not -name "test_*" -not -name "*_test.py" \
    2>/dev/null | while read -r SRC_FILE; do
      local SRC_REL="${SRC_FILE#$PROJECT_ROOT/}"
      local SRC_MOD
      SRC_MOD=$(echo "$SRC_REL" | sed 's|/|.|g; s|\.py$||; s|\.__init__$||')
      grep -n "^from \." "$SRC_FILE" 2>/dev/null | while IFS=: read -r LINE_NUM CONTENT; do
        local IMPORT_MOD
        IMPORT_MOD=$(echo "$CONTENT" | sed 's/from \.\([a-zA-Z_][a-zA-Z0-9_.]*\) import.*/\1/')
        # Check if the imported module imports back
        local SRC_DIR
        SRC_DIR=$(dirname "$SRC_FILE")
        local TARGET_FILE="$SRC_DIR/${IMPORT_MOD//.//}.py"
        if [ -f "$TARGET_FILE" ]; then
          local SRC_BASENAME
          SRC_BASENAME=$(basename "$SRC_FILE" .py)
          if grep -q "from \.$SRC_BASENAME import\|from \.${SRC_BASENAME}\." "$TARGET_FILE" 2>/dev/null; then
            add_finding "$SRC_REL" "$LINE_NUM" "WARNING" "70" \
              "Potential circular import: $SRC_REL <-> ${TARGET_FILE#$PROJECT_ROOT/}" \
              "Move shared code to a separate module or use lazy imports"
          fi
        fi
      done
  done
}

case "$LANG" in
  typescript|javascript) check_circular_ts ;;
  python) check_circular_py ;;
esac

CIRCULAR_FOUND=$((FINDING_NUM))
echo "  Found $CIRCULAR_FOUND circular import issues"

# ═══════════════════════════════════════
# CHECK 2: Orphan Files (never imported)
# ═══════════════════════════════════════
echo "[2/5] Checking for orphan files..."
BEFORE_ORPHAN=$FINDING_NUM

check_orphans_ts() {
  # Find TS/JS source files that are never imported by any other file
  local ALL_IMPORTS=$(mktemp)
  trap "rm -f $ALL_IMPORTS $FINDINGS_FILE" EXIT

  # Collect all import targets
  find "$SCAN_DIR" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.next/*" \
    2>/dev/null | while read -r F; do
      grep -oE "from ['\"][^'\"]+['\"]" "$F" 2>/dev/null | sed "s/from ['\"]//; s/['\"]$//"
  done > "$ALL_IMPORTS"

  # Find source files never referenced
  find "$SCAN_DIR" \( -name "*.ts" -o -name "*.tsx" \) \
    -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.next/*" \
    -not -name "*.test.*" -not -name "*.spec.*" -not -name "*.d.ts" \
    -not -name "index.ts" -not -name "index.tsx" \
    -not -name "main.ts" -not -name "app.ts" -not -name "server.ts" \
    -not -name "*.module.ts" -not -name "*.config.*" \
    -not -path "*/migrations/*" -not -path "*/seeds/*" \
    2>/dev/null | while read -r F; do
      local REL="${F#$PROJECT_ROOT/}"
      local BASENAME
      BASENAME=$(basename "$F" | sed 's/\.[^.]*$//')
      # Check if any import references this file
      if ! grep -q "$BASENAME" "$ALL_IMPORTS" 2>/dev/null; then
        add_finding "$REL" "1" "WARNING" "50" \
          "Orphan file: not imported by any other module" \
          "Remove if unused, or add to an index/barrel export"
      fi
  done

  rm -f "$ALL_IMPORTS"
}

case "$LANG" in
  typescript|javascript) check_orphans_ts ;;
esac

ORPHAN_FOUND=$((FINDING_NUM - BEFORE_ORPHAN))
echo "  Found $ORPHAN_FOUND orphan files"

# ═══════════════════════════════════════
# CHECK 3: Unscoped Tenant Queries (cross-module)
# ═══════════════════════════════════════
echo "[3/5] Checking for unscoped tenant queries..."
BEFORE_TENANT=$FINDING_NUM

# Read manifest for tenant field
TENANT_FIELD="tenantId"
MANIFEST=""
for CANDIDATE in "$PROJECT_ROOT/saascode-kit/manifest.yaml" "$PROJECT_ROOT/.saascode/manifest.yaml" "$PROJECT_ROOT/manifest.yaml"; do
  [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
done
if [ -n "$MANIFEST" ]; then
  TF=$(awk '/^tenancy:/{in_t=1;next} /^[a-z]/{in_t=0} in_t && /identifier:/{val=$0; sub(/.*: */, "", val); gsub(/"/, "", val); print val; exit}' "$MANIFEST")
  [ -n "$TF" ] && TENANT_FIELD="$TF"
fi

check_tenant_scoping() {
  local PATTERN=""
  case "$LANG" in
    typescript|javascript) PATTERN='findMany\s*(\s*)\|findFirst\s*(\s*)\|\.find\s*(\s*{)\|\.findAll\s*(\s*)' ;;
    python) PATTERN='\.objects\.all\(\)\|\.objects\.filter\(\)' ;;
    ruby) PATTERN='\.(all|find_by|where)\s*$\|\.(all|find_by|where)\s*(\s*)' ;;
    java) PATTERN='findAll\s*(\s*)\|\.getResultList' ;;
    *) return ;;
  esac

  # Search for unscoped queries across the codebase
  find "$SCAN_DIR" \( -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.rb" -o -name "*.java" -o -name "*.go" \) \
    -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/vendor/*" \
    -not -path "*/test*" -not -path "*/spec/*" -not -path "*/migration*" \
    -not -name "*.test.*" -not -name "*.spec.*" \
    2>/dev/null | while read -r F; do
      local REL="${F#$PROJECT_ROOT/}"
      # Skip model/schema/migration files
      case "$REL" in
        *model*|*schema*|*migration*|*seed*|*fixture*) continue ;;
      esac
      grep -n -E "$PATTERN" "$F" 2>/dev/null | while IFS=: read -r LINE_NUM CONTENT; do
        # Check surrounding context for tenant scoping
        local START=$((LINE_NUM - 5))
        [ "$START" -lt 1 ] && START=1
        local END=$((LINE_NUM + 5))
        local CONTEXT
        CONTEXT=$(sed -n "${START},${END}p" "$F" 2>/dev/null)
        if ! echo "$CONTEXT" | grep -qi "$TENANT_FIELD\|tenant\|org_id\|organization"; then
          add_finding "$REL" "$LINE_NUM" "CRITICAL" "65" \
            "Unscoped query without $TENANT_FIELD filter — potential data leak" \
            "Add $TENANT_FIELD filter to scope query to current tenant"
        fi
      done
  done
}

check_tenant_scoping

TENANT_FOUND=$((FINDING_NUM - BEFORE_TENANT))
echo "  Found $TENANT_FOUND unscoped tenant queries"

# ═══════════════════════════════════════
# CHECK 4: Duplicate Code Patterns
# ═══════════════════════════════════════
echo "[4/5] Checking for duplicated patterns..."
BEFORE_DUP=$FINDING_NUM

# Look for copy-pasted error handling, auth checks, etc.
check_duplicated_patterns() {
  case "$LANG" in
    typescript|javascript)
      # Find duplicated try-catch patterns (same error message in multiple files)
      local ERROR_MSGS=$(mktemp)
      find "$SCAN_DIR" \( -name "*.ts" -o -name "*.tsx" \) \
        -not -path "*/node_modules/*" -not -path "*/dist/*" \
        -not -name "*.test.*" -not -name "*.spec.*" \
        2>/dev/null | while read -r F; do
          grep -oE "throw new [A-Za-z]+\(['\"][^'\"]+['\"]" "$F" 2>/dev/null | \
            sed "s/throw new [A-Za-z]*(['\"]//; s/['\"]$//" | while read -r MSG; do
              echo "${F#$PROJECT_ROOT/}|$MSG"
          done
      done > "$ERROR_MSGS"

      # Find messages that appear in 3+ files
      awk -F'|' '{msgs[$2]++; files[$2]=files[$2] " " $1} END { for (m in msgs) if (msgs[m] >= 3) print msgs[m] "|" m "|" files[m] }' "$ERROR_MSGS" 2>/dev/null | \
        while IFS='|' read -r COUNT MSG FILES; do
          local FIRST_FILE
          FIRST_FILE=$(echo "$FILES" | awk '{print $1}')
          add_finding "$FIRST_FILE" "1" "WARNING" "55" \
            "Duplicated error pattern in $COUNT files: '$MSG'" \
            "Extract to a shared error utility or constants file"
        done
      rm -f "$ERROR_MSGS"
      ;;
  esac
}

check_duplicated_patterns

DUP_FOUND=$((FINDING_NUM - BEFORE_DUP))
echo "  Found $DUP_FOUND duplication issues"

# ═══════════════════════════════════════
# CHECK 5: Dead Exports (exported but never imported)
# ═══════════════════════════════════════
echo "[5/5] Checking for dead exports..."
BEFORE_DEAD=$FINDING_NUM

check_dead_exports_ts() {
  local ALL_CONTENT=$(mktemp)
  trap "rm -f $ALL_CONTENT $FINDINGS_FILE" EXIT

  # Collect all file contents for searching
  find "$SCAN_DIR" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.next/*" \
    2>/dev/null -exec cat {} + > "$ALL_CONTENT" 2>/dev/null

  # Find named exports and check usage
  find "$SCAN_DIR" \( -name "*.ts" -o -name "*.tsx" \) \
    -not -path "*/node_modules/*" -not -path "*/dist/*" \
    -not -name "*.test.*" -not -name "*.spec.*" -not -name "*.d.ts" \
    -not -name "index.ts" -not -name "index.tsx" \
    -not -path "*/migrations/*" \
    2>/dev/null | head -100 | while read -r F; do
      local REL="${F#$PROJECT_ROOT/}"
      grep -n 'export ' "$F" 2>/dev/null | while IFS=: read -r LINE_NUM CONTENT; do
        # Extract exported name
        local EXPORT_NAME
        EXPORT_NAME=$(echo "$CONTENT" | grep -oE 'export (const|function|class|interface|type|enum|async function) ([A-Za-z_][A-Za-z0-9_]*)' | awk '{print $NF}')
        [ -z "$EXPORT_NAME" ] && continue
        # Skip common patterns that are used implicitly
        case "$EXPORT_NAME" in
          default|module|App|Main|Home|Index|Page|Layout) continue ;;
        esac
        # Count how many times it appears across all files (minus the declaration)
        local USAGE_COUNT
        USAGE_COUNT=$(grep -c "\b${EXPORT_NAME}\b" "$ALL_CONTENT" 2>/dev/null || echo "0")
        if [ "$USAGE_COUNT" -le 1 ]; then
          add_finding "$REL" "$LINE_NUM" "WARNING" "45" \
            "Exported '$EXPORT_NAME' appears unused outside its module" \
            "Remove export keyword if not needed, or verify it's used in tests/configs"
        fi
      done
  done

  rm -f "$ALL_CONTENT"
}

case "$LANG" in
  typescript|javascript) check_dead_exports_ts ;;
esac

DEAD_FOUND=$((FINDING_NUM - BEFORE_DEAD))
echo "  Found $DEAD_FOUND dead export issues"

# ═══════════════════════════════════════
# OUTPUT
# ═══════════════════════════════════════
echo ""

SCANNED_FILES=$(find "$SCAN_DIR" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.rb" -o -name "*.java" -o -name "*.go" -o -name "*.php" \) \
  -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/vendor/*" \
  -not -path "*/test*" -not -path "*/.git/*" \
  2>/dev/null | wc -l | tr -d ' ')

FORMATTER="$(dirname "$0")/review-formatter.sh"
if [ -f "$FORMATTER" ] && [ "$OUTPUT_FORMAT" != "table" ]; then
  source "$FORMATTER"
  format_findings "$FINDINGS_FILE" "$OUTPUT_FORMAT" "$SCANNED_FILES" "$CRITICAL_COUNT" "$WARNING_COUNT" "$LANG"
else
  # Table output
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
  echo "  Files in repo:   $SCANNED_FILES"
  echo -e "  Findings:        ${RED}$CRITICAL_COUNT critical${NC}, ${YELLOW}$WARNING_COUNT warnings${NC}"
  echo ""
  echo "  Breakdown:"
  echo "    Circular imports:    $CIRCULAR_FOUND"
  echo "    Orphan files:        $ORPHAN_FOUND"
  echo "    Unscoped queries:    $TENANT_FOUND"
  echo "    Duplicated patterns: $DUP_FOUND"
  echo "    Dead exports:        $DEAD_FOUND"
  echo ""

  if [ "$CRITICAL_COUNT" -gt 0 ]; then
    echo -e "${BOLD}VERDICT:${NC} ${RED}REQUEST CHANGES${NC} — $CRITICAL_COUNT critical cross-module issues"
  elif [ "$WARNING_COUNT" -gt 0 ]; then
    echo -e "${BOLD}VERDICT:${NC} ${YELLOW}COMMENT${NC} — $WARNING_COUNT cross-module warnings"
  else
    echo -e "${BOLD}VERDICT:${NC} ${GREEN}APPROVE${NC} — No cross-module issues detected"
  fi
fi

[ "$CRITICAL_COUNT" -gt 0 ] && exit 1
exit 0
