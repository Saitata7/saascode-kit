#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode — Intent Log Viewer
#
# View and query the AI edit intent log.
#
# Usage:
#   saascode intent                    # Today's log
#   saascode intent --session <sid>    # Filter by session
#   saascode intent --file <path>      # Filter by file
#   saascode intent --summary          # Session summaries
#   saascode intent --days N           # Last N days
#   saascode intent --json             # Raw JSONL
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
SESSION_FILTER=""
FILE_FILTER=""
SHOW_SUMMARY=false
SHOW_JSON=false
SHOW_HELP=false
DAYS=1
NEXT_IS=""

for arg in "$@"; do
  if [ -n "$NEXT_IS" ]; then
    case "$NEXT_IS" in
      session) SESSION_FILTER="$arg" ;;
      file)    FILE_FILTER="$arg" ;;
      days)    DAYS="$arg" ;;
    esac
    NEXT_IS=""
    continue
  fi
  case "$arg" in
    --session|-s)  NEXT_IS="session" ;;
    --file|-f)     NEXT_IS="file" ;;
    --days|-d)     NEXT_IS="days" ;;
    --summary)     SHOW_SUMMARY=true ;;
    --json)        SHOW_JSON=true ;;
    --help|-h)     SHOW_HELP=true ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  echo ""
  echo -e "${BOLD}SaasCode Intent Log${NC}"
  echo ""
  echo "Usage:"
  echo "  saascode intent                    Show today's log"
  echo "  saascode intent --session <sid>    Filter by session ID"
  echo "  saascode intent --file <path>      Filter by file path"
  echo "  saascode intent --summary          Show session summaries only"
  echo "  saascode intent --days N           Show last N days (default: 1)"
  echo "  saascode intent --json             Raw JSONL output"
  echo ""
  exit 0
fi

# ─── Collect log files for the date range ───
LOG_FILES=""
for i in $(seq 0 $((DAYS - 1))); do
  if date -v-${i}d +"%Y-%m-%d" >/dev/null 2>&1; then
    # macOS date
    DAY=$(date -v-${i}d -u +"%Y-%m-%d")
  else
    # GNU date
    DAY=$(date -u -d "$i days ago" +"%Y-%m-%d")
  fi
  FILE="$LOG_DIR/intent-${DAY}.jsonl"
  if [ -f "$FILE" ]; then
    LOG_FILES="$LOG_FILES $FILE"
  fi
done

if [ -z "$LOG_FILES" ]; then
  echo -e "${YELLOW}No intent logs found for the last $DAYS day(s).${NC}"
  echo ""
  echo -e "${DIM}Logs are created when Claude Code edits files with the intent-log hook active.${NC}"
  echo -e "${DIM}Location: $LOG_DIR/intent-YYYY-MM-DD.jsonl${NC}"
  exit 0
fi

# ─── Read and filter entries ───
ALL_ENTRIES=""
for F in $LOG_FILES; do
  ALL_ENTRIES="${ALL_ENTRIES}$(cat "$F")
"
done

# Apply filters
if [ -n "$SESSION_FILTER" ]; then
  ALL_ENTRIES=$(echo "$ALL_ENTRIES" | jq -c "select(.sid == \"$SESSION_FILTER\")" 2>/dev/null)
fi

if [ -n "$FILE_FILTER" ]; then
  ALL_ENTRIES=$(echo "$ALL_ENTRIES" | jq -c "select(.file | contains(\"$FILE_FILTER\"))" 2>/dev/null)
fi

# Remove empty lines
ALL_ENTRIES=$(echo "$ALL_ENTRIES" | grep -v '^$')

if [ -z "$ALL_ENTRIES" ]; then
  echo -e "${YELLOW}No matching entries found.${NC}"
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
  echo -e "${BOLD}═══ SaasCode Intent Summary ═══${NC}"
  echo ""

  # Group by session
  SESSIONS=$(echo "$ALL_ENTRIES" | jq -r '.sid' 2>/dev/null | sort -u)

  TOTAL_EDITS=0
  TOTAL_FILES=0
  TOTAL_PASS=0
  TOTAL_WARN=0
  TOTAL_BLOCKED=0

  while IFS= read -r SID; do
    [ -z "$SID" ] && continue
    SESSION_ENTRIES=$(echo "$ALL_ENTRIES" | jq -c "select(.sid == \"$SID\")" 2>/dev/null)
    EDIT_COUNT=$(echo "$SESSION_ENTRIES" | wc -l | tr -d '[:space:]')
    FILE_COUNT=$(echo "$SESSION_ENTRIES" | jq -r '.file' 2>/dev/null | sort -u | wc -l | tr -d '[:space:]')
    PASS_COUNT=$(echo "$SESSION_ENTRIES" | jq -r '.check_result' 2>/dev/null | grep -c '^PASS$') || PASS_COUNT=0
    WARN_COUNT=$(echo "$SESSION_ENTRIES" | jq -r '.check_result' 2>/dev/null | grep -c '^WARNING$') || WARN_COUNT=0
    BLOCK_COUNT=$(echo "$SESSION_ENTRIES" | jq -r '.check_result' 2>/dev/null | grep -c '^BLOCKED$') || BLOCK_COUNT=0

    # Get first timestamp and intent
    FIRST_TS=$(echo "$SESSION_ENTRIES" | head -1 | jq -r '.ts // ""' 2>/dev/null)
    FIRST_TIME=$(echo "$FIRST_TS" | cut -dT -f2 | cut -d: -f1-2)
    FIRST_INTENT=$(echo "$SESSION_ENTRIES" | head -1 | jq -r '.intent // "unknown"' 2>/dev/null | cut -c1-80)

    # Session header
    SID_SHORT=$(echo "$SID" | cut -c1-8)
    echo -e "  ${CYAN}Session ${SID_SHORT}...${NC}  ${DIM}${FIRST_TIME}${NC}  ${EDIT_COUNT} edits, ${FILE_COUNT} files"

    # Check results
    RESULT_STR=""
    [ "$PASS_COUNT" -gt 0 ] && RESULT_STR="${GREEN}${PASS_COUNT} passed${NC}"
    if [ "$WARN_COUNT" -gt 0 ]; then
      [ -n "$RESULT_STR" ] && RESULT_STR="$RESULT_STR, "
      RESULT_STR="${RESULT_STR}${YELLOW}${WARN_COUNT} warnings${NC}"
    fi
    if [ "$BLOCK_COUNT" -gt 0 ]; then
      [ -n "$RESULT_STR" ] && RESULT_STR="$RESULT_STR, "
      RESULT_STR="${RESULT_STR}${RED}${BLOCK_COUNT} blocked${NC}"
    fi
    echo -e "    Checks: ${RESULT_STR}"
    echo -e "    ${DIM}→ \"${FIRST_INTENT}\"${NC}"
    echo ""

    TOTAL_EDITS=$((TOTAL_EDITS + EDIT_COUNT))
    TOTAL_FILES=$((TOTAL_FILES + FILE_COUNT))
    TOTAL_PASS=$((TOTAL_PASS + PASS_COUNT))
    TOTAL_WARN=$((TOTAL_WARN + WARN_COUNT))
    TOTAL_BLOCKED=$((TOTAL_BLOCKED + BLOCK_COUNT))
  done <<< "$SESSIONS"

  echo -e "${DIM}───${NC}"
  echo -e "${BOLD}Total: $TOTAL_EDITS edits, $TOTAL_FILES files, ${GREEN}$TOTAL_PASS passed${NC}, ${YELLOW}$TOTAL_WARN warnings${NC}, ${RED}$TOTAL_BLOCKED blocked${NC}"
  echo ""
  exit 0
fi

# ─── Detailed log mode ───
echo ""
echo -e "${BOLD}═══ SaasCode Intent Log ═══${NC}"
echo ""

CURRENT_SID=""

echo "$ALL_ENTRIES" | while IFS= read -r ENTRY; do
  [ -z "$ENTRY" ] && continue

  SID=$(echo "$ENTRY" | jq -r '.sid // "unknown"' 2>/dev/null)
  TS=$(echo "$ENTRY" | jq -r '.ts // ""' 2>/dev/null)
  TOOL=$(echo "$ENTRY" | jq -r '.tool // ""' 2>/dev/null)
  FILE=$(echo "$ENTRY" | jq -r '.file // ""' 2>/dev/null)
  LINES=$(echo "$ENTRY" | jq -r '.lines_changed // 0' 2>/dev/null)
  CHECK=$(echo "$ENTRY" | jq -r '.check_result // "SKIP"' 2>/dev/null)
  INTENT=$(echo "$ENTRY" | jq -r '.intent // "unknown"' 2>/dev/null | cut -c1-100)

  # Extract time portion
  TIME=$(echo "$TS" | cut -dT -f2 | cut -dZ -f1 | cut -d: -f1-2)

  # New session header
  if [ "$SID" != "$CURRENT_SID" ]; then
    SID_SHORT=$(echo "$SID" | cut -c1-8)
    if [ -n "$CURRENT_SID" ]; then
      echo ""
    fi
    echo -e "${CYAN}Session ${SID_SHORT}...${NC}"
    CURRENT_SID="$SID"
  fi

  # Format check result with color
  case "$CHECK" in
    PASS)    CHECK_FMT="${GREEN}PASS${NC}" ;;
    WARNING) CHECK_FMT="${YELLOW}WARN${NC}" ;;
    BLOCKED) CHECK_FMT="${RED}BLOCKED${NC}" ;;
    *)       CHECK_FMT="${DIM}${CHECK}${NC}" ;;
  esac

  # Format lines changed
  if [ "$TOOL" = "Write" ]; then
    LINES_FMT="new file"
  else
    LINES_FMT="+${LINES} lines"
  fi

  # File basename for compact display
  FILE_BASE=$(basename "$FILE")

  # Print entry
  printf "  ${DIM}%s${NC}  %-5s %-30s %10s  " "$TIME" "$TOOL" "$FILE_BASE" "$LINES_FMT"
  echo -e "$CHECK_FMT"

  # Print intent (indented)
  if [ "$INTENT" != "unknown" ] && [ -n "$INTENT" ]; then
    echo -e "         ${DIM}→ \"${INTENT}\"${NC}"
  fi
done

echo ""
echo -e "${DIM}───${NC}"
echo -e "${DIM}$ENTRY_COUNT entries${NC}"
echo ""
