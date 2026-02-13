#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode — Issue Report Viewer + GitHub Issue Creator
#
# View and query the issue log, and optionally file
# detected issues as a GitHub Issue via `gh issue create`.
#
# Usage:
#   saascode report                         # Today's issues
#   saascode report --days N                # Last N days
#   saascode report --severity critical     # Filter by severity
#   saascode report --source check-file     # Filter by source
#   saascode report --file <path>           # Filter by affected file
#   saascode report --summary               # Counts by category + severity
#   saascode report --json                  # Raw JSONL output
#   saascode report --github                # Create a GitHub Issue
#   saascode report --clear                 # Delete logs older than 30 days
# ═══════════════════════════════════════════════════════════

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

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
LOG_DIR="$ROOT/.saascode/logs"

# ─── Parse arguments ───
SEVERITY_FILTER=""
SOURCE_FILTER=""
FILE_FILTER=""
SHOW_SUMMARY=false
SHOW_JSON=false
SHOW_HELP=false
DO_GITHUB=false
DO_CLEAR=false
DAYS=1
NEXT_IS=""

for arg in "$@"; do
  if [ -n "$NEXT_IS" ]; then
    case "$NEXT_IS" in
      severity) SEVERITY_FILTER="$arg" ;;
      source)   SOURCE_FILTER="$arg" ;;
      file)     FILE_FILTER="$arg" ;;
      days)     DAYS="$arg" ;;
    esac
    NEXT_IS=""
    continue
  fi
  case "$arg" in
    --severity)    NEXT_IS="severity" ;;
    --source)      NEXT_IS="source" ;;
    --file|-f)     NEXT_IS="file" ;;
    --days|-d)     NEXT_IS="days" ;;
    --summary)     SHOW_SUMMARY=true ;;
    --json)        SHOW_JSON=true ;;
    --github)      DO_GITHUB=true ;;
    --clear)       DO_CLEAR=true ;;
    --help|-h)     SHOW_HELP=true ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  echo ""
  echo -e "${BOLD}SaasCode Issue Report${NC}"
  echo ""
  echo "Usage:"
  echo "  saascode report                         Show today's issues"
  echo "  saascode report --days N                Show last N days (default: 1)"
  echo "  saascode report --severity critical     Filter: critical or warning"
  echo "  saascode report --source check-file     Filter: check-file, full-audit, pre-deploy"
  echo "  saascode report --file <path>           Filter by affected file path"
  echo "  saascode report --summary               Aggregate counts by category + severity"
  echo "  saascode report --json                  Raw JSONL output"
  echo "  saascode report --github                Create a GitHub Issue from collected issues"
  echo "  saascode report --clear                 Delete issue logs older than 30 days"
  echo ""
  exit 0
fi

# ─── Clear old logs ───
if [ "$DO_CLEAR" = true ]; then
  if [ ! -d "$LOG_DIR" ]; then
    echo -e "${YELLOW}No log directory found.${NC}"
    exit 0
  fi
  DELETED=0
  CUTOFF=$(date -u -v-30d +%Y-%m-%d 2>/dev/null || date -u -d "30 days ago" +%Y-%m-%d 2>/dev/null || echo "")
  if [ -z "$CUTOFF" ]; then
    echo -e "${RED}Could not determine cutoff date.${NC}"
    exit 1
  fi
  for F in "$LOG_DIR"/issues-*.jsonl; do
    [ -f "$F" ] || continue
    FILE_DATE=$(basename "$F" | sed 's/issues-//;s/\.jsonl//')
    if [ "$FILE_DATE" \< "$CUTOFF" ]; then
      rm "$F"
      DELETED=$((DELETED + 1))
    fi
  done
  echo -e "${GREEN}Cleared $DELETED issue log(s) older than 30 days.${NC}"
  exit 0
fi

# ─── Collect log files for the date range ───
LOG_FILES=()
for i in $(seq 0 $((DAYS - 1))); do
  if date -v-${i}d +"%Y-%m-%d" >/dev/null 2>&1; then
    # macOS date
    DAY=$(date -v-${i}d -u +"%Y-%m-%d")
  else
    # GNU date
    DAY=$(date -u -d "$i days ago" +"%Y-%m-%d")
  fi
  FILE="$LOG_DIR/issues-${DAY}.jsonl"
  if [ -f "$FILE" ]; then
    LOG_FILES+=("$FILE")
  fi
done

if [ ${#LOG_FILES[@]} -eq 0 ]; then
  echo -e "${YELLOW}No issue logs found for the last $DAYS day(s).${NC}"
  echo ""
  echo -e "${DIM}Logs are created when check-file, full-audit, or pre-deploy detect issues.${NC}"
  echo -e "${DIM}Location: $LOG_DIR/issues-YYYY-MM-DD.jsonl${NC}"
  exit 0
fi

# ─── Read and filter entries ───
ALL_ENTRIES=""
for F in "${LOG_FILES[@]}"; do
  ALL_ENTRIES="${ALL_ENTRIES}$(cat "$F")
"
done

# Apply filters
if [ -n "$SEVERITY_FILTER" ]; then
  ALL_ENTRIES=$(echo "$ALL_ENTRIES" | jq -c "select(.severity == \"$SEVERITY_FILTER\")" 2>/dev/null)
fi

if [ -n "$SOURCE_FILTER" ]; then
  ALL_ENTRIES=$(echo "$ALL_ENTRIES" | jq -c "select(.source == \"$SOURCE_FILTER\")" 2>/dev/null)
fi

if [ -n "$FILE_FILTER" ]; then
  ALL_ENTRIES=$(echo "$ALL_ENTRIES" | jq -c "select(.file | contains(\"$FILE_FILTER\"))" 2>/dev/null)
fi

# Remove empty lines
ALL_ENTRIES=$(echo "$ALL_ENTRIES" | grep -v '^$')

if [ -z "$ALL_ENTRIES" ]; then
  echo -e "${YELLOW}No matching issues found.${NC}"
  exit 0
fi

ENTRY_COUNT=$(echo "$ALL_ENTRIES" | wc -l | tr -d '[:space:]')

# ─── Raw JSON output ───
if [ "$SHOW_JSON" = true ]; then
  echo "$ALL_ENTRIES"
  exit 0
fi

# ─── Summary mode ───
if [ "$SHOW_SUMMARY" = true ]; then
  echo ""
  echo -e "${BOLD}═══ SaasCode Issue Summary ═══${NC}"
  echo ""

  # Count by severity
  CRIT_COUNT=$(echo "$ALL_ENTRIES" | jq -r '.severity' 2>/dev/null | grep -c '^critical$') || CRIT_COUNT=0
  WARN_COUNT=$(echo "$ALL_ENTRIES" | jq -r '.severity' 2>/dev/null | grep -c '^warning$') || WARN_COUNT=0

  echo -e "  ${RED}Critical: $CRIT_COUNT${NC}"
  echo -e "  ${YELLOW}Warning:  $WARN_COUNT${NC}"
  echo -e "  Total:    $ENTRY_COUNT"
  echo ""

  # Group by category
  echo -e "  ${BOLD}By Category:${NC}"
  echo "$ALL_ENTRIES" | jq -r '[.category, .severity] | join("\t")' 2>/dev/null | sort | uniq -c | sort -rn | while IFS= read -r LINE; do
    COUNT=$(echo "$LINE" | awk '{print $1}')
    CAT=$(echo "$LINE" | awk '{print $2}')
    SEV=$(echo "$LINE" | awk '{print $3}')
    case "$SEV" in
      critical) SEV_FMT="${RED}critical${NC}" ;;
      warning)  SEV_FMT="${YELLOW}warning${NC}" ;;
      *)        SEV_FMT="$SEV" ;;
    esac
    printf "    %3d  %-30s %b\n" "$COUNT" "$CAT" "$SEV_FMT"
  done

  echo ""

  # Group by source
  echo -e "  ${BOLD}By Source:${NC}"
  echo "$ALL_ENTRIES" | jq -r '.source' 2>/dev/null | sort | uniq -c | sort -rn | while IFS= read -r LINE; do
    COUNT=$(echo "$LINE" | awk '{print $1}')
    SRC=$(echo "$LINE" | awk '{print $2}')
    printf "    %3d  %s\n" "$COUNT" "$SRC"
  done

  echo ""
  exit 0
fi

# ─── GitHub Issue creation ───
if [ "$DO_GITHUB" = true ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}Error: 'gh' CLI not found. Install it: https://cli.github.com${NC}"
    exit 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: Not authenticated with GitHub. Run: gh auth login${NC}"
    exit 1
  fi

  # Build issue title
  CRIT_COUNT=$(echo "$ALL_ENTRIES" | jq -r '.severity' 2>/dev/null | grep -c '^critical$') || CRIT_COUNT=0
  WARN_COUNT=$(echo "$ALL_ENTRIES" | jq -r '.severity' 2>/dev/null | grep -c '^warning$') || WARN_COUNT=0
  TODAY=$(date -u +%Y-%m-%d)
  TITLE="[saascode-kit] Issue Report: ${CRIT_COUNT} critical, ${WARN_COUNT} warning ($TODAY)"

  # Build markdown body via temp file
  TMPBODY=$(mktemp)
  {
    echo "## SaasCode Kit Issue Report"
    echo ""
    echo "**Date range:** Last ${DAYS} day(s) | **Total:** ${ENTRY_COUNT} issues"
    echo ""

    if [ "$CRIT_COUNT" -gt 0 ]; then
      echo "### Critical Issues"
      echo ""
      echo "$ALL_ENTRIES" | jq -r 'select(.severity == "critical") | "- [ ] **[\(.source)]** \(.category): \(.message)" + (if .file != "" then " (`\(.file)`)" else "" end)' 2>/dev/null
      echo ""
    fi

    if [ "$WARN_COUNT" -gt 0 ]; then
      echo "### Warnings"
      echo ""
      echo "$ALL_ENTRIES" | jq -r 'select(.severity == "warning") | "- [ ] **[\(.source)]** \(.category): \(.message)" + (if .file != "" then " (`\(.file)`)" else "" end)' 2>/dev/null
      echo ""
    fi

    echo "---"
    echo "*Generated by [saascode-kit](https://github.com/AshGw/saascode-kit) report*"
  } > "$TMPBODY"

  echo -e "${BOLD}Creating GitHub Issue...${NC}"
  ISSUE_URL=$(gh issue create --title "$TITLE" --body-file "$TMPBODY" --label "saascode-report" 2>&1)
  GH_EXIT=$?
  rm -f "$TMPBODY"

  if [ $GH_EXIT -eq 0 ]; then
    echo -e "${GREEN}Issue created: $ISSUE_URL${NC}"
  else
    # Label might not exist — retry without label
    TMPBODY2=$(mktemp)
    {
      echo "## SaasCode Kit Issue Report"
      echo ""
      echo "**Date range:** Last ${DAYS} day(s) | **Total:** ${ENTRY_COUNT} issues"
      echo ""

      if [ "$CRIT_COUNT" -gt 0 ]; then
        echo "### Critical Issues"
        echo ""
        echo "$ALL_ENTRIES" | jq -r 'select(.severity == "critical") | "- [ ] **[\(.source)]** \(.category): \(.message)" + (if .file != "" then " (`\(.file)`)" else "" end)' 2>/dev/null
        echo ""
      fi

      if [ "$WARN_COUNT" -gt 0 ]; then
        echo "### Warnings"
        echo ""
        echo "$ALL_ENTRIES" | jq -r 'select(.severity == "warning") | "- [ ] **[\(.source)]** \(.category): \(.message)" + (if .file != "" then " (`\(.file)`)" else "" end)' 2>/dev/null
        echo ""
      fi

      echo "---"
      echo "*Generated by [saascode-kit](https://github.com/AshGw/saascode-kit) report*"
    } > "$TMPBODY2"

    ISSUE_URL=$(gh issue create --title "$TITLE" --body-file "$TMPBODY2" 2>&1)
    GH_EXIT2=$?
    rm -f "$TMPBODY2"

    if [ $GH_EXIT2 -eq 0 ]; then
      echo -e "${GREEN}Issue created: $ISSUE_URL${NC}"
    else
      echo -e "${RED}Failed to create issue: $ISSUE_URL${NC}"
      exit 1
    fi
  fi
  exit 0
fi

# ─── Detailed log mode (default) ───
echo ""
echo -e "${BOLD}═══ SaasCode Issue Report ═══${NC}"
echo ""

CURRENT_SOURCE=""

echo "$ALL_ENTRIES" | while IFS= read -r ENTRY; do
  [ -z "$ENTRY" ] && continue

  SOURCE=$(echo "$ENTRY" | jq -r '.source // "unknown"' 2>/dev/null)
  TS=$(echo "$ENTRY" | jq -r '.ts // ""' 2>/dev/null)
  SEVERITY=$(echo "$ENTRY" | jq -r '.severity // ""' 2>/dev/null)
  CATEGORY=$(echo "$ENTRY" | jq -r '.category // ""' 2>/dev/null)
  MESSAGE=$(echo "$ENTRY" | jq -r '.message // ""' 2>/dev/null | cut -c1-120)
  ISSUE_FILE=$(echo "$ENTRY" | jq -r '.file // ""' 2>/dev/null)

  # Extract time portion
  TIME=$(echo "$TS" | cut -dT -f2 | cut -dZ -f1 | cut -d: -f1-2)

  # New source header
  if [ "$SOURCE" != "$CURRENT_SOURCE" ]; then
    if [ -n "$CURRENT_SOURCE" ]; then
      echo ""
    fi
    echo -e "${CYAN}── $SOURCE ──${NC}"
    CURRENT_SOURCE="$SOURCE"
  fi

  # Format severity with color
  case "$SEVERITY" in
    critical) SEV_FMT="${RED}CRITICAL${NC}" ;;
    warning)  SEV_FMT="${YELLOW}WARNING${NC}" ;;
    *)        SEV_FMT="${DIM}${SEVERITY}${NC}" ;;
  esac

  # File basename for compact display
  if [ -n "$ISSUE_FILE" ]; then
    FILE_BASE=$(basename "$ISSUE_FILE")
    printf "  ${DIM}%s${NC}  %b  %-20s %-20s %s\n" "$TIME" "$SEV_FMT" "$CATEGORY" "$FILE_BASE" "$MESSAGE"
  else
    printf "  ${DIM}%s${NC}  %b  %-20s %s\n" "$TIME" "$SEV_FMT" "$CATEGORY" "$MESSAGE"
  fi
done

echo ""
echo -e "${DIM}───${NC}"
echo -e "${DIM}$ENTRY_COUNT issue(s)${NC}"
echo ""
