#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — Review Output Formatter
# Converts pipe-delimited findings to JSON, SARIF, or table.
#
# Findings format (one per line):
#   NUM|FILE|LINE|SEVERITY|CONFIDENCE|ISSUE|FIX
#
# Usage (sourced by ast-review-*.sh or called standalone):
#   bash review-formatter.sh --format json  < findings.txt
#   bash review-formatter.sh --format sarif < findings.txt
#   bash review-formatter.sh --format table < findings.txt
#
# Or sourced:
#   source review-formatter.sh
#   format_findings "$FINDINGS_FILE" "json" "$SCANNED" "$CRITICAL_COUNT" "$WARNING_COUNT"
# ═══════════════════════════════════════════════════════════

# ── JSON output ──
format_json() {
  local FINDINGS_FILE="$1"
  local SCANNED="$2"
  local CRITICALS="$3"
  local WARNINGS="$4"
  local LANG="${5:-unknown}"

  local VERDICT="APPROVE"
  [ "$WARNINGS" -gt 0 ] && VERDICT="COMMENT"
  [ "$CRITICALS" -gt 0 ] && VERDICT="REQUEST_CHANGES"

  echo "{"
  echo "  \"tool\": \"saascode-kit\","
  echo "  \"version\": \"0.1.0\","
  echo "  \"language\": \"$LANG\","
  echo "  \"summary\": {"
  echo "    \"files_scanned\": $SCANNED,"
  echo "    \"critical\": $CRITICALS,"
  echo "    \"warnings\": $WARNINGS,"
  echo "    \"verdict\": \"$VERDICT\""
  echo "  },"
  echo "  \"findings\": ["

  local FIRST=true
  if [ -f "$FINDINGS_FILE" ] && [ -s "$FINDINGS_FILE" ]; then
    while IFS='|' read -r NUM FILE LINE SEV CONF ISSUE FIX; do
      [ -z "$NUM" ] && continue
      if [ "$FIRST" = true ]; then
        FIRST=false
      else
        echo ","
      fi
      # Escape JSON strings
      ISSUE=$(echo "$ISSUE" | sed 's/\\/\\\\/g; s/"/\\"/g')
      FIX=$(echo "$FIX" | sed 's/\\/\\\\/g; s/"/\\"/g')
      FILE=$(echo "$FILE" | sed 's/\\/\\\\/g; s/"/\\"/g')
      printf '    {\n'
      printf '      "id": %s,\n' "$NUM"
      printf '      "file": "%s",\n' "$FILE"
      printf '      "line": %s,\n' "$LINE"
      printf '      "severity": "%s",\n' "$SEV"
      printf '      "confidence": %s,\n' "$CONF"
      printf '      "issue": "%s",\n' "$ISSUE"
      printf '      "fix": "%s"\n' "$FIX"
      printf '    }'
    done < "$FINDINGS_FILE"
  fi

  echo ""
  echo "  ]"
  echo "}"
}

# ── SARIF output (GitHub Code Scanning) ──
format_sarif() {
  local FINDINGS_FILE="$1"
  local SCANNED="$2"
  local CRITICALS="$3"
  local WARNINGS="$4"
  local LANG="${5:-unknown}"

  cat << 'SARIF_HEADER'
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "saascode-kit",
          "version": "0.1.0",
          "informationUri": "https://github.com/Saitata7/saascode-kit",
          "rules": []
        }
      },
      "results": [
SARIF_HEADER

  local FIRST=true
  local RULES_SEEN=""

  if [ -f "$FINDINGS_FILE" ] && [ -s "$FINDINGS_FILE" ]; then
    while IFS='|' read -r NUM FILE LINE SEV CONF ISSUE FIX; do
      [ -z "$NUM" ] && continue
      if [ "$FIRST" = true ]; then
        FIRST=false
      else
        echo ","
      fi

      # Map severity
      local SARIF_LEVEL="warning"
      [ "$SEV" = "CRITICAL" ] && SARIF_LEVEL="error"

      # Create rule ID from issue text
      local RULE_ID
      RULE_ID=$(echo "$ISSUE" | sed 's/[^a-zA-Z0-9]/-/g' | cut -c1-50 | sed 's/-*$//')

      # Escape JSON
      ISSUE=$(echo "$ISSUE" | sed 's/\\/\\\\/g; s/"/\\"/g')
      FIX=$(echo "$FIX" | sed 's/\\/\\\\/g; s/"/\\"/g')
      FILE=$(echo "$FILE" | sed 's/\\/\\\\/g; s/"/\\"/g')

      printf '        {\n'
      printf '          "ruleId": "%s",\n' "$RULE_ID"
      printf '          "level": "%s",\n' "$SARIF_LEVEL"
      printf '          "message": {\n'
      printf '            "text": "%s. Fix: %s"\n' "$ISSUE" "$FIX"
      printf '          },\n'
      printf '          "locations": [\n'
      printf '            {\n'
      printf '              "physicalLocation": {\n'
      printf '                "artifactLocation": {\n'
      printf '                  "uri": "%s"\n' "$FILE"
      printf '                },\n'
      printf '                "region": {\n'
      printf '                  "startLine": %s\n' "$LINE"
      printf '                }\n'
      printf '              }\n'
      printf '            }\n'
      printf '          ]\n'
      printf '        }'
    done < "$FINDINGS_FILE"
  fi

  cat << 'SARIF_FOOTER'

      ]
    }
  ]
}
SARIF_FOOTER
}

# ── Table output (default — colored terminal) ──
format_table() {
  local FINDINGS_FILE="$1"
  local SCANNED="$2"
  local CRITICALS="$3"
  local WARNINGS="$4"
  local LANG="${5:-unknown}"
  local CLEAN_FILES_STR="${6:-}"

  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BOLD='\033[1m'
  local NC='\033[0m'

  # Print table
  if [ -f "$FINDINGS_FILE" ] && [ -s "$FINDINGS_FILE" ]; then
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
  echo -e "  Findings:       ${RED}$CRITICALS critical${NC}, ${YELLOW}$WARNINGS warnings${NC}"
  echo ""

  # Clean files
  if [ -n "$CLEAN_FILES_STR" ]; then
    echo "Clean files (no issues):"
    echo "$CLEAN_FILES_STR" | head -20 | while IFS= read -r CF; do
      [ -n "$CF" ] && echo -e "  ${GREEN}✓${NC} $CF"
    done
    local TOTAL_CLEAN
    TOTAL_CLEAN=$(echo "$CLEAN_FILES_STR" | grep -c '.' 2>/dev/null || echo "0")
    [ "$TOTAL_CLEAN" -gt 20 ] && echo "  ... and $((TOTAL_CLEAN - 20)) more"
    echo ""
  fi

  # Verdict
  if [ "$CRITICALS" -gt 0 ]; then
    echo -e "${BOLD}VERDICT:${NC} ${RED}REQUEST CHANGES${NC} — $CRITICALS critical issues found"
  elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${BOLD}VERDICT:${NC} ${YELLOW}COMMENT${NC} — $WARNINGS warnings to consider"
  else
    echo -e "${BOLD}VERDICT:${NC} ${GREEN}APPROVE${NC} — No issues detected"
  fi
}

# ── Main dispatch (called by format_findings or standalone) ──
format_findings() {
  local FINDINGS_FILE="$1"
  local FORMAT="${2:-table}"
  local SCANNED="${3:-0}"
  local CRITICALS="${4:-0}"
  local WARNINGS="${5:-0}"
  local LANG="${6:-unknown}"
  local CLEAN_FILES_STR="${7:-}"

  case "$FORMAT" in
    json)  format_json "$FINDINGS_FILE" "$SCANNED" "$CRITICALS" "$WARNINGS" "$LANG" ;;
    sarif) format_sarif "$FINDINGS_FILE" "$SCANNED" "$CRITICALS" "$WARNINGS" "$LANG" ;;
    table|*) format_table "$FINDINGS_FILE" "$SCANNED" "$CRITICALS" "$WARNINGS" "$LANG" "$CLEAN_FILES_STR" ;;
  esac
}

# ── If called standalone ──
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  FORMAT="table"
  LANG="unknown"
  while [ $# -gt 0 ]; do
    case "$1" in
      --format) shift; FORMAT="$1" ;;
      --lang) shift; LANG="$1" ;;
    esac
    shift
  done

  # Read from stdin into temp file
  TMPF=$(mktemp)
  trap "rm -f $TMPF" EXIT
  cat > "$TMPF"

  LINES=$(wc -l < "$TMPF" | tr -d ' ')
  CRITS=$(grep -c '|CRITICAL|' "$TMPF" 2>/dev/null || echo "0")
  WARNS=$((LINES - CRITS))

  format_findings "$TMPF" "$FORMAT" "$LINES" "$CRITS" "$WARNS" "$LANG"
fi
