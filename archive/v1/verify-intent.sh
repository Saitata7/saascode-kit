#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — Intent Verification (kluster.ai-inspired)
# Compares a git diff against a task description to verify
# the code changes actually implement what was requested.
#
# Uses AI providers (same as ai-review.sh) to analyze:
#   1. Does the diff match the stated intent?
#   2. Are there hallucinated APIs/imports/functions?
#   3. Are there unintended side effects?
#
# Usage:
#   bash verify-intent.sh --intent "Add user authentication"
#   bash verify-intent.sh --intent "Fix billing webhook" --diff-from HEAD~3
#   bash verify-intent.sh --intent-file task.md
#
# Exit codes:
#   0 — Intent verified (changes match description)
#   1 — Intent mismatch or hallucinations detected
#   2 — Runtime error
# ═══════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Parse args ──
INTENT=""
INTENT_FILE=""
DIFF_FROM="HEAD"
DIFF_CONTEXT=5

while [ $# -gt 0 ]; do
  case "$1" in
    --intent) shift; INTENT="$1" ;;
    --intent-file) shift; INTENT_FILE="$1" ;;
    --diff-from) shift; DIFF_FROM="$1" ;;
    --context) shift; DIFF_CONTEXT="$1" ;;
    --help|-h)
      echo "${BOLD}SaasCode Kit — Intent Verification${NC}"
      echo ""
      echo "Usage:"
      echo "  verify-intent --intent \"Add user auth\"       Verify staged/recent changes"
      echo "  verify-intent --intent-file task.md           Read intent from file"
      echo "  verify-intent --diff-from HEAD~3              Compare last 3 commits"
      echo ""
      echo "Requires one of: ANTHROPIC_API_KEY, OPENAI_API_KEY, or GROQ_API_KEY"
      exit 0
      ;;
  esac
  shift
done

# ── Load intent ──
if [ -n "$INTENT_FILE" ] && [ -f "$INTENT_FILE" ]; then
  INTENT=$(cat "$INTENT_FILE")
elif [ -z "$INTENT" ]; then
  echo -e "${RED}Error: --intent or --intent-file required${NC}"
  echo "Usage: verify-intent --intent \"description of what was supposed to change\""
  exit 2
fi

# ── Get diff ──
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DIFF=$(git -C "$PROJECT_ROOT" diff "$DIFF_FROM" -U"$DIFF_CONTEXT" 2>/dev/null)

if [ -z "$DIFF" ]; then
  # Try staged changes
  DIFF=$(git -C "$PROJECT_ROOT" diff --cached -U"$DIFF_CONTEXT" 2>/dev/null)
fi

if [ -z "$DIFF" ]; then
  echo -e "${YELLOW}No changes found to verify.${NC}"
  exit 0
fi

# ── Truncate diff if too large ──
DIFF_LINES=$(echo "$DIFF" | wc -l)
MAX_LINES=500
if [ "$DIFF_LINES" -gt "$MAX_LINES" ]; then
  DIFF=$(echo "$DIFF" | head -n "$MAX_LINES")
  DIFF="${DIFF}

... (truncated — ${DIFF_LINES} total lines, showing first ${MAX_LINES})"
fi

# ── Changed files list ──
CHANGED_FILES=$(git -C "$PROJECT_ROOT" diff "$DIFF_FROM" --name-only 2>/dev/null || git -C "$PROJECT_ROOT" diff --cached --name-only 2>/dev/null || echo "(unknown)")

# ── Build prompt ──
PROMPT="You are a code intent verification system. Your job is to compare a stated task/intent against actual code changes and determine if the changes correctly implement the intent.

## Stated Intent
${INTENT}

## Changed Files
${CHANGED_FILES}

## Code Diff
\`\`\`diff
${DIFF}
\`\`\`

## Your Analysis
Respond with a structured analysis:

### 1. Intent Match (MATCH / PARTIAL / MISMATCH)
Does the diff implement what was described? Explain briefly.

### 2. Hallucination Check
- Are there imports of modules/packages that likely don't exist?
- Are there calls to API endpoints or functions that seem fabricated?
- Are there references to database tables/columns that weren't mentioned and may not exist?

### 3. Unintended Side Effects
- Does the diff change anything beyond what was requested?
- Are there security implications (removed auth checks, exposed data, etc.)?
- Are there breaking changes to existing interfaces?

### 4. Verdict
One of:
- **VERIFIED** — Changes match the stated intent, no hallucinations detected
- **WARNING** — Changes partially match but have concerns (list them)
- **MISMATCH** — Changes don't match the stated intent
- **HALLUCINATION** — Fabricated imports/APIs/functions detected"

# ── Detect AI provider ──
detect_provider() {
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "anthropic"
  elif [ -n "${OPENAI_API_KEY:-}" ]; then
    echo "openai"
  elif [ -n "${GROQ_API_KEY:-}" ]; then
    echo "groq"
  else
    echo ""
  fi
}

PROVIDER=$(detect_provider)

if [ -z "$PROVIDER" ]; then
  echo -e "${RED}Error: No AI API key found.${NC}"
  echo "Set one of: ANTHROPIC_API_KEY, OPENAI_API_KEY, GROQ_API_KEY"
  exit 2
fi

echo ""
echo -e "${BOLD}Intent Verification${NC}"
echo "========================================"
echo "  Intent: ${INTENT:0:80}$([ ${#INTENT} -gt 80 ] && echo '...')"
echo "  Diff from: $DIFF_FROM"
echo "  Files changed: $(echo "$CHANGED_FILES" | wc -l | tr -d ' ')"
echo "  Provider: $PROVIDER"
echo ""
echo "Analyzing..."
echo ""

# ── Call AI provider ──
call_anthropic() {
  local ESCAPED_PROMPT
  ESCAPED_PROMPT=$(echo "$PROMPT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "$PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\t/\\t/g')

  local RESPONSE
  RESPONSE=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "{
      \"model\": \"claude-haiku-4-5-20251001\",
      \"max_tokens\": 1500,
      \"messages\": [{\"role\": \"user\", \"content\": $ESCAPED_PROMPT}]
    }" 2>/dev/null)

  echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['content'][0]['text'])" 2>/dev/null || echo "$RESPONSE"
}

call_openai() {
  local ESCAPED_PROMPT
  ESCAPED_PROMPT=$(echo "$PROMPT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "$PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\t/\\t/g')

  local RESPONSE
  RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"gpt-4o-mini\",
      \"max_tokens\": 1500,
      \"messages\": [{\"role\": \"user\", \"content\": $ESCAPED_PROMPT}]
    }" 2>/dev/null)

  echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['choices'][0]['message']['content'])" 2>/dev/null || echo "$RESPONSE"
}

call_groq() {
  local ESCAPED_PROMPT
  ESCAPED_PROMPT=$(echo "$PROMPT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "$PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\t/\\t/g')

  local RESPONSE
  RESPONSE=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"llama-3.1-70b-versatile\",
      \"max_tokens\": 1500,
      \"messages\": [{\"role\": \"user\", \"content\": $ESCAPED_PROMPT}]
    }" 2>/dev/null)

  echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['choices'][0]['message']['content'])" 2>/dev/null || echo "$RESPONSE"
}

# ── Execute ──
RESULT=""
case "$PROVIDER" in
  anthropic) RESULT=$(call_anthropic) ;;
  openai)    RESULT=$(call_openai) ;;
  groq)      RESULT=$(call_groq) ;;
esac

if [ -z "$RESULT" ]; then
  echo -e "${RED}Error: No response from AI provider${NC}"
  exit 2
fi

# ── Display result ──
echo "$RESULT"
echo ""
echo "========================================"

# ── Parse verdict ──
if echo "$RESULT" | grep -qi 'VERIFIED'; then
  echo -e "${BOLD}VERDICT:${NC} ${GREEN}VERIFIED${NC} — Changes match the stated intent"
  exit 0
elif echo "$RESULT" | grep -qi 'HALLUCINATION'; then
  echo -e "${BOLD}VERDICT:${NC} ${RED}HALLUCINATION DETECTED${NC} — Fabricated references found"
  exit 1
elif echo "$RESULT" | grep -qi 'MISMATCH'; then
  echo -e "${BOLD}VERDICT:${NC} ${RED}MISMATCH${NC} — Changes don't match the stated intent"
  exit 1
elif echo "$RESULT" | grep -qi 'WARNING'; then
  echo -e "${BOLD}VERDICT:${NC} ${YELLOW}WARNING${NC} — Partial match with concerns"
  exit 0
else
  echo -e "${BOLD}VERDICT:${NC} ${YELLOW}INCONCLUSIVE${NC} — Could not determine verdict"
  exit 0
fi
