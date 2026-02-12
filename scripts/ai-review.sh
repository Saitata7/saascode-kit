#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode — AI-Powered Code Review (Groq)
#
# Uses Groq's free tier (llama-3.3-70b) with project-specific
# review rules loaded from manifest.yaml.
#
# Usage:
#   saascode review --ai              # Review staged changes
#   saascode review --ai --file X.ts  # Review specific file
#
# Exit: 0 = pass/warnings, 2 = critical issues
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

# ─── Read manifest.yaml values ───
read_manifest() {
  local KEY="$1"
  local DEFAULT="$2"
  local MANIFEST=""

  # Search order: kit dir, .saascode/, project root
  for CANDIDATE in "$ROOT/saascode-kit/manifest.yaml" "$ROOT/.saascode/manifest.yaml" "$ROOT/manifest.yaml"; do
    [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
  done
  [ -z "$MANIFEST" ] && echo "$DEFAULT" && return

  # Simple awk extraction for dotted keys (e.g. "project.name" → finds name under project)
  local SECTION="${KEY%%.*}"
  local FIELD="${KEY#*.}"

  if [ "$SECTION" = "$FIELD" ]; then
    # Top-level key
    awk -v key="$SECTION" '
      /^[a-z]/ && $1 == key":" { val=$0; sub(/^[^:]+:[[:space:]]*/, "", val); gsub(/^"|"$/, "", val); print val; exit }
    ' "$MANIFEST"
  else
    # Nested key (one level deep)
    awk -v section="$SECTION" -v field="$FIELD" '
      BEGIN { in_section=0 }
      /^[a-z]/ { if ($1 == section":") in_section=1; else in_section=0; next }
      in_section && /^  [a-z]/ {
        line=$0; sub(/^[[:space:]]+/, "", line)
        if (line ~ "^"field":") {
          val=line; sub(/^[^:]+:[[:space:]]*/, "", val); gsub(/^"|"$/, "", val); print val; exit
        }
      }
    ' "$MANIFEST"
  fi | head -1 | { read -r VAL; echo "${VAL:-$DEFAULT}"; }
}

# Read project info from manifest
PROJECT_NAME=$(read_manifest "project.name" "Project")
PROJECT_DESC=$(read_manifest "project.description" "")
PROJECT_TYPE=$(read_manifest "project.type" "")
BACKEND_FRAMEWORK=$(read_manifest "stack.backend.framework" "")
BACKEND_ORM=$(read_manifest "stack.backend.orm" "")
BACKEND_DB=$(read_manifest "stack.backend.database" "")
FRONTEND_FRAMEWORK=$(read_manifest "stack.frontend.framework" "")
FRONTEND_UI=$(read_manifest "stack.frontend.ui_library" "")
FRONTEND_CSS=$(read_manifest "stack.frontend.css" "")
AUTH_PROVIDER=$(read_manifest "auth.provider" "")
TENANT_ID=$(read_manifest "tenancy.identifier" "tenantId")
TENANT_ENABLED=$(read_manifest "tenancy.enabled" "false")
AI_ENABLED=$(read_manifest "ai.enabled" "false")

# ─── Parse arguments ───
FILE_PATH=""
SHOW_HELP=false

for arg in "$@"; do
  case "$arg" in
    --ai) ;; # consumed by saascode.sh, skip
    --file)  NEXT_IS_FILE=true ;;
    --help|-h) SHOW_HELP=true ;;
    *)
      if [ "$NEXT_IS_FILE" = true ]; then
        FILE_PATH="$arg"
        NEXT_IS_FILE=false
      fi
      ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  echo ""
  echo "${BOLD}SaasCode AI Review${NC}"
  echo ""
  echo "Usage:"
  echo "  saascode review --ai              Review staged git changes"
  echo "  saascode review --ai --file X.ts  Review a specific file"
  echo ""
  echo "Requires: GROQ_API_KEY in .env or environment"
  echo ""
  exit 0
fi

# ─── Load API key ───
# Priority: environment variable > root .env > common .env locations
if [ -z "$GROQ_API_KEY" ]; then
  for ENV_CANDIDATE in "$ROOT/.env" "$ROOT/.env.local"; do
    if [ -f "$ENV_CANDIDATE" ]; then
      GROQ_API_KEY=$(grep '^GROQ_API_KEY=' "$ENV_CANDIDATE" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d "'\"" | tr -d '[:space:]')
      [ -n "$GROQ_API_KEY" ] && break
    fi
  done
fi

if [ -z "$GROQ_API_KEY" ]; then
  echo -e "${RED}Error: GROQ_API_KEY not found${NC}"
  echo ""
  echo "Set it in one of these locations:"
  echo "  1. Environment: export GROQ_API_KEY=gsk_xxx"
  echo "  2. File: .env → GROQ_API_KEY=gsk_xxx"
  echo ""
  echo "Get a free key at: https://console.groq.com"
  exit 1
fi

# ─── Load model (default: llama-3.3-70b-versatile) ───
GROQ_MODEL="${GROQ_MODEL:-}"
if [ -z "$GROQ_MODEL" ]; then
  for ENV_CANDIDATE in "$ROOT/.env" "$ROOT/.env.local"; do
    if [ -f "$ENV_CANDIDATE" ]; then
      GROQ_MODEL=$(grep '^GROQ_MODEL=' "$ENV_CANDIDATE" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d "'\"" | tr -d '[:space:]')
      [ -n "$GROQ_MODEL" ] && break
    fi
  done
fi
GROQ_MODEL="${GROQ_MODEL:-llama-3.3-70b-versatile}"

# ─── Collect content to review ───
CONTENT=""
SCOPE_DESC=""

if [ -n "$FILE_PATH" ]; then
  # Review specific file
  if [ ! -f "$FILE_PATH" ]; then
    echo -e "${RED}Error: File not found: $FILE_PATH${NC}"
    exit 1
  fi
  CONTENT=$(cat "$FILE_PATH")
  LINECOUNT=$(wc -l < "$FILE_PATH" | tr -d '[:space:]')
  SCOPE_DESC="1 file ($FILE_PATH), $LINECOUNT lines"
else
  # Review staged changes (git diff --cached)
  CONTENT=$(git -C "$ROOT" diff --cached 2>/dev/null)

  if [ -z "$CONTENT" ]; then
    # Fallback to unstaged changes
    CONTENT=$(git -C "$ROOT" diff 2>/dev/null)
    if [ -n "$CONTENT" ]; then
      SCOPE_DESC="unstaged changes"
    fi
  else
    SCOPE_DESC="staged changes"
  fi

  if [ -z "$CONTENT" ]; then
    echo -e "${YELLOW}No changes to review.${NC}"
    echo ""
    echo "Options:"
    echo "  Stage files first:  git add <files>"
    echo "  Review a file:      saascode review --ai --file <path>"
    exit 0
  fi

  # Count files and lines
  FILE_COUNT=$(echo "$CONTENT" | grep -c '^diff --git' || echo "0")
  LINE_COUNT=$(echo "$CONTENT" | grep -c '^[+-]' || echo "0")
  SCOPE_DESC="$FILE_COUNT files, ~$LINE_COUNT lines changed ($SCOPE_DESC)"
fi

# ─── Truncate if too large (Groq free tier limits) ───
CHAR_COUNT=${#CONTENT}
MAX_CHARS=60000  # ~15K tokens, well within Groq limits
if [ "$CHAR_COUNT" -gt "$MAX_CHARS" ]; then
  CONTENT="${CONTENT:0:$MAX_CHARS}

... [TRUNCATED — content exceeded $MAX_CHARS characters] ..."
  SCOPE_DESC="$SCOPE_DESC (truncated)"
fi

# ─── Build system prompt dynamically from manifest ───

# Build stack description
STACK_DESC=""
[ -n "$BACKEND_FRAMEWORK" ] && STACK_DESC="- Backend: ${BACKEND_FRAMEWORK}"
[ -n "$BACKEND_ORM" ] && STACK_DESC="${STACK_DESC}, ${BACKEND_ORM} ORM"
[ -n "$BACKEND_DB" ] && STACK_DESC="${STACK_DESC}, ${BACKEND_DB}"
[ -n "$FRONTEND_FRAMEWORK" ] && STACK_DESC="${STACK_DESC}
- Frontend: ${FRONTEND_FRAMEWORK}"
[ -n "$FRONTEND_UI" ] && STACK_DESC="${STACK_DESC}, ${FRONTEND_UI}"
[ -n "$FRONTEND_CSS" ] && STACK_DESC="${STACK_DESC}, ${FRONTEND_CSS}"
[ -n "$AUTH_PROVIDER" ] && STACK_DESC="${STACK_DESC}
- Auth: ${AUTH_PROVIDER}"

# Build tenant isolation rules
TENANT_RULES=""
if [ "$TENANT_ENABLED" = "true" ]; then
  TENANT_RULES="
### Tenant Isolation (CRITICAL — data leak if wrong)
- ALL queries MUST include \`where: { ${TENANT_ID} }\` or verify tenant ownership
- After findUnique: verify \`record.${TENANT_ID} === ${TENANT_ID}\` before returning
- Querying child records by parent ID is OK if the parent was already tenant-verified
- NEVER return unscoped queries — this leaks data between tenants"
fi

# Build AI security + development pattern rules
AI_RULES=""
if [ "$AI_ENABLED" = "true" ]; then
  AI_RULES="
### AI/LLM Security (CRITICAL — prompt injection & data leak risks)
- User input MUST be sanitized before passing to LLM prompts — flag raw string interpolation into prompts
- System prompts MUST NOT be exposed to end users — flag if system prompt is returned in API responses
- LLM outputs MUST be treated as untrusted — flag if LLM output is rendered with dangerouslySetInnerHTML or used in eval()
- Rate limiting MUST exist on AI endpoints — flag AI endpoints without throttle/rate-limit decorators
- Sensitive data (PII, credentials) MUST NOT be sent to external AI providers without explicit filtering
- AI-generated content MUST be validated before database writes — flag direct LLM output → DB inserts without validation

### AI/GenAI Development Patterns (flag violations)
- AI API calls MUST have error handling — flag bare await without try/catch on AI provider calls (network failures, rate limits, model errors)
- AI API calls MUST have timeouts — flag AI provider calls without timeout/AbortController (LLM calls can hang for 30s+)
- Streaming responses MUST handle connection drops — flag SSE/stream handlers without error/close event handling
- Token usage SHOULD be tracked — flag AI calls that discard usage metadata from response (needed for cost tracking)
- AI responses SHOULD be validated against expected schema — flag if structured output (JSON mode) response is used without JSON.parse try/catch
- Embedding operations SHOULD be batched — flag single-item embedding calls inside loops (use batch API instead)
- AI model names SHOULD use constants/config — flag hardcoded model strings like 'gpt-4' or 'claude-3' (makes model upgrades painful)
- Hallucination mitigation: AI-generated URLs, file paths, and code references SHOULD be verified before use
- AI context windows: flag if prompt construction doesn't check/truncate input length (can exceed model limits and fail silently)"
fi

SYSTEM_PROMPT="You are a senior code reviewer for ${PROJECT_NAME}${PROJECT_DESC:+, ${PROJECT_DESC}}.

## Tech Stack
${STACK_DESC}

## Critical Rules (MUST flag violations)
${TENANT_RULES}
### Guard Chain (CRITICAL — auth bypass if wrong)
- Standard guard chain must be present on all protected endpoints — exact order matters
- @Roles() decorator is SILENTLY IGNORED without RolesGuard in the guard chain

### API Client (Frontend)
- MUST use the designated API client — never raw \`fetch()\`
- Raw fetch() bypasses auth headers (token injection)

### Anti-Patterns (flag if found)
- \`eval()\` — security risk
- \`dangerouslySetInnerHTML\` — XSS risk
- Hardcoded secrets (passwords, API keys, tokens in string literals)
- \`rejectUnauthorized: false\` — disables TLS
- Raw SQL with string interpolation — SQL injection
- Empty catch blocks that swallow errors silently
${AI_RULES}

## Quality Checks
- N+1 queries: findMany result looped with individual DB calls inside the loop
- Missing error handling on async operations
- Console.log in production code (not tests)

## STRICT OUTPUT RULES
- Maximum 15 issues. Focus on most impactful.
- NEVER repeat the same issue. If a pattern appears N times, report ONCE with \"(N occurrences)\".
- Only include line numbers you can verify. Omit if unsure.
- STRICTLY one line per issue. NO explanations, NO paragraphs, NO extra text after the issue line.
- Do NOT output anything before the first issue line (no preamble).
- Do NOT output anything after the Summary line (no closing remarks).

## Output Format (follow EXACTLY)
CRITICAL: <short description> — <file:line>
WARNING: <short description> — <file:line>
INFO: <short description>
Summary: X critical, Y warnings, Z info

Example of CORRECT output:
CRITICAL: findMany() without ${TENANT_ID} — invoices.service.ts:34
WARNING: N+1 query in getAgentTools loop (3 occurrences) — agents.service.ts:45
INFO: console.log statements should be removed before deploy
Summary: 1 critical, 1 warning, 1 info

If code is clean: PASS: No issues found
Summary: 0 critical, 0 warnings, 0 info"

# ─── Build JSON payload ───
# Use jq to safely escape the content into JSON
PAYLOAD=$(jq -n \
  --arg model "$GROQ_MODEL" \
  --arg system "$SYSTEM_PROMPT" \
  --arg user "Review the following code for the ${PROJECT_NAME} project. Flag any violations of the rules above.

$CONTENT" \
  '{
    model: $model,
    messages: [
      { role: "system", content: $system },
      { role: "user", content: $user }
    ],
    max_tokens: 4096,
    temperature: 0.2
  }')

# ─── Call Groq API ───
echo ""
echo -e "${BOLD}═══ SaasCode AI Review ═══${NC}"
echo -e "${DIM}Provider: Groq ($GROQ_MODEL)${NC}"
echo -e "${DIM}Scope: $SCOPE_DESC${NC}"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" \
  --max-time 60 \
  -X POST "https://api.groq.com/openai/v1/chat/completions" \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" 2>/dev/null)

# Extract HTTP status (last line) and body (everything else)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

# ─── Handle errors ───
if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" = "000" ]; then
  echo -e "${RED}Error: Could not reach Groq API (network timeout)${NC}"
  exit 1
fi

if [ "$HTTP_CODE" != "200" ]; then
  ERROR_MSG=$(echo "$BODY" | jq -r '.error.message // "Unknown error"' 2>/dev/null)
  if [ "$HTTP_CODE" = "429" ]; then
    echo -e "${RED}Error: Groq rate limit exceeded${NC}"
    echo -e "${DIM}Free tier: 100K tokens/day. Try again later or use a smaller diff.${NC}"
  elif [ "$HTTP_CODE" = "401" ]; then
    echo -e "${RED}Error: Invalid GROQ_API_KEY${NC}"
    echo -e "${DIM}Check your key at: https://console.groq.com${NC}"
  else
    echo -e "${RED}Error: Groq API returned HTTP $HTTP_CODE${NC}"
    echo -e "${DIM}$ERROR_MSG${NC}"
  fi
  exit 1
fi

# ─── Extract review content ───
REVIEW=$(echo "$BODY" | jq -r '.choices[0].message.content // empty' 2>/dev/null)

if [ -z "$REVIEW" ]; then
  FINISH_REASON=$(echo "$BODY" | jq -r '.choices[0].finish_reason // "unknown"' 2>/dev/null)
  echo -e "${RED}Error: Empty response from Groq (finish_reason: $FINISH_REASON)${NC}"
  exit 1
fi

# ─── Display review with color coding ───
echo "$REVIEW" | while IFS= read -r LINE; do
  case "$LINE" in
    CRITICAL:*) echo -e "${RED}${LINE}${NC}" ;;
    WARNING:*)  echo -e "${YELLOW}${LINE}${NC}" ;;
    INFO:*)     echo -e "${CYAN}${LINE}${NC}" ;;
    PASS:*)     echo -e "${GREEN}${LINE}${NC}" ;;
    Summary:*)  echo -e "\n${DIM}───${NC}"; echo -e "${BOLD}${LINE}${NC}" ;;
    *)          echo "$LINE" ;;
  esac
done

echo ""

# ─── Determine exit code ───
CRITICAL_COUNT=$(echo "$REVIEW" | grep -c '^CRITICAL:' || true)
if [ "$CRITICAL_COUNT" -gt 0 ]; then
  exit 2
fi

exit 0
