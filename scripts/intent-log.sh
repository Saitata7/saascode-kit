#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode — Intent Tracking Logger (Claude Code Hook)
#
# PostToolUse hook that logs every Edit/Write with metadata.
# Reads full JSON from stdin, extracts intent from transcript,
# appends to daily JSONL log file.
#
# Usage: Called automatically by Claude Code PostToolUse hook
# Output: Silent (no stdout to avoid cluttering Claude context)
# ═══════════════════════════════════════════════════════════

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
TODAY=$(date -u +"%Y-%m-%d")
LOG_FILE="$LOG_DIR/intent-${TODAY}.jsonl"

# Ensure log directory exists
mkdir -p "$LOG_DIR" 2>/dev/null

# ─── Read stdin JSON (received once, save it) ───
INPUT=$(cat)

if [ -z "$INPUT" ]; then
  exit 0
fi

# ─── Extract fields from hook JSON ───
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
TOOL_USE_ID=$(echo "$INPUT" | jq -r '.tool_use_id // ""' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)

# Skip if not Edit/Write or no file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Make file path relative to project root
REL_PATH="${FILE_PATH#$ROOT/}"

# ─── Extract change details ───
LINES_CHANGED=0
OLD_PREVIEW=""
NEW_PREVIEW=""

if [ "$TOOL_NAME" = "Edit" ]; then
  OLD_PREVIEW=$(echo "$INPUT" | jq -r '.tool_input.old_string // ""' 2>/dev/null | head -1 | cut -c1-120)
  NEW_PREVIEW=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null | head -1 | cut -c1-120)
  # Count lines changed (approximate from new_string)
  LINES_CHANGED=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null | wc -l | tr -d '[:space:]')
elif [ "$TOOL_NAME" = "Write" ]; then
  OLD_PREVIEW=""
  NEW_PREVIEW="[new file]"
  LINES_CHANGED=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null | wc -l | tr -d '[:space:]')
fi

# ─── Run check-file.sh and capture result ───
CHECK_RESULT="SKIP"
SCRIPTS_DIR="$ROOT/.saascode/scripts"
if [ -f "$SCRIPTS_DIR/check-file.sh" ] && [ -f "$FILE_PATH" ]; then
  CHECK_OUTPUT=$(bash "$SCRIPTS_DIR/check-file.sh" "$FILE_PATH" 2>&1)
  CHECK_EXIT=$?
  if [ $CHECK_EXIT -eq 2 ]; then
    CHECK_RESULT="BLOCKED"
  elif echo "$CHECK_OUTPUT" | grep -q "^WARNING:"; then
    CHECK_RESULT="WARNING"
  elif echo "$CHECK_OUTPUT" | grep -q "^PASS:"; then
    CHECK_RESULT="PASS"
  else
    CHECK_RESULT="PASS"
  fi
fi

# ─── Extract intent from transcript ───
INTENT="unknown"
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # Read transcript backwards, find last user message before this tool call
  # Transcript is JSONL — each line is a JSON object
  # Look for role=user messages, take the last one's content (first 200 chars)
  INTENT=$(tac "$TRANSCRIPT_PATH" 2>/dev/null \
    | grep -m 1 '"role":\s*"user"' 2>/dev/null \
    | jq -r '
      if .message.content then
        if (.message.content | type) == "string" then
          .message.content
        elif (.message.content | type) == "array" then
          [.message.content[] | select(.type == "text") | .text] | join(" ")
        else
          "unknown"
        end
      else
        "unknown"
      end
    ' 2>/dev/null \
    | head -1 \
    | cut -c1-200)

  # Clean up: remove newlines, excess whitespace
  INTENT=$(echo "$INTENT" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
fi

# Fallback
if [ -z "$INTENT" ] || [ "$INTENT" = "null" ]; then
  INTENT="unknown"
fi

# ─── Build and append log entry ───
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

LOG_ENTRY=$(jq -cn \
  --arg ts "$TIMESTAMP" \
  --arg sid "$SESSION_ID" \
  --arg tool "$TOOL_NAME" \
  --arg file "$REL_PATH" \
  --argjson lines "$LINES_CHANGED" \
  --arg old_preview "$OLD_PREVIEW" \
  --arg new_preview "$NEW_PREVIEW" \
  --arg check "$CHECK_RESULT" \
  --arg intent "$INTENT" \
  --arg tool_use_id "$TOOL_USE_ID" \
  '{
    ts: $ts,
    sid: $sid,
    tool: $tool,
    file: $file,
    lines_changed: $lines,
    old_preview: $old_preview,
    new_preview: $new_preview,
    check_result: $check,
    intent: $intent,
    tool_use_id: $tool_use_id
  }' 2>/dev/null)

if [ -n "$LOG_ENTRY" ]; then
  echo "$LOG_ENTRY" >> "$LOG_FILE"
fi

# Silent exit — don't pollute Claude's context
exit 0
