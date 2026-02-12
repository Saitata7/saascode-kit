#!/bin/bash
# SaasCode Kit — Endpoint Parity Enforcer
# Compares backend controllers vs frontend API clients
# Reports: missing in frontend, missing in backend
# Usage: saascode parity  OR  bash saascode-kit/scripts/endpoint-parity.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# ─── Read manifest.yaml values ───
read_manifest() {
  local KEY="$1"
  local DEFAULT="$2"
  local MANIFEST=""

  for CANDIDATE in "$PROJECT_ROOT/saascode-kit/manifest.yaml" "$PROJECT_ROOT/.saascode/manifest.yaml" "$PROJECT_ROOT/manifest.yaml"; do
    [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
  done
  [ -z "$MANIFEST" ] && echo "$DEFAULT" && return

  local SECTION="${KEY%%.*}"
  local FIELD="${KEY#*.}"

  if [ "$SECTION" = "$FIELD" ]; then
    awk -v key="$SECTION" '
      /^[a-z]/ && $1 == key":" { val=$0; sub(/^[^:]+:[[:space:]]*/, "", val); sub(/[[:space:]]+#[[:space:]].*$/, "", val); gsub(/^"|"$/, "", val); print val; exit }
    ' "$MANIFEST"
  else
    awk -v section="$SECTION" -v field="$FIELD" '
      BEGIN { in_section=0 }
      /^[a-z]/ { if ($1 == section":") in_section=1; else in_section=0; next }
      in_section && /^  [a-z]/ {
        line=$0; sub(/^[[:space:]]+/, "", line)
        if (line ~ "^"field":") {
          val=line; sub(/^[^:]+:[[:space:]]*/, "", val); sub(/[[:space:]]+#[[:space:]].*$/, "", val); gsub(/^"|"$/, "", val); print val; exit
        }
      }
    ' "$MANIFEST"
  fi | head -1 | { read -r VAL; echo "${VAL:-$DEFAULT}"; }
}

# Read paths from manifest with fallback defaults
BACKEND_PATH=$(read_manifest "paths.backend" "apps/api")
API_CLIENT_REL=$(read_manifest "paths.api_client" "apps/portal/src/lib/api")

CONTROLLERS_DIR="$PROJECT_ROOT/$BACKEND_PATH/src/modules"
API_CLIENT_DIR="$PROJECT_ROOT/$API_CLIENT_REL"

TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

echo -e "${BOLD}Endpoint Parity Check${NC}"
echo "================================"
echo ""

touch "$TEMP_DIR/backend.txt" "$TEMP_DIR/frontend.txt"
touch "$TEMP_DIR/backend_normalized.txt" "$TEMP_DIR/frontend_normalized.txt"
touch "$TEMP_DIR/backend_full.txt" "$TEMP_DIR/frontend_full.txt"

# ─── Extract Backend Endpoints ───
echo -e "${CYAN}[1/3] Scanning backend controllers...${NC}"

if [ -d "$CONTROLLERS_DIR" ]; then
  find "$CONTROLLERS_DIR" -name "*.controller.ts" -not -path "*/platform/*" | sort | while read -r file; do
    # Get controller base path (macOS-compatible: no grep -P)
    controller_line=$(grep "@Controller(" "$file" 2>/dev/null | head -1)

    # Skip if no controller decorator
    [ -z "$controller_line" ] && continue

    # Extract path from @Controller('path') — empty if @Controller() has no path arg
    base_path=""
    if echo "$controller_line" | grep -qE "@Controller\(['\"]"; then
      base_path=$(echo "$controller_line" | sed -E "s/.*@Controller\(['\"]([^'\"]*)['\"].*/\1/")
    fi

    # Extract each route using awk (macOS sed doesn't support \| in BRE)
    grep -nE "@(Get|Post|Put|Patch|Delete)" "$file" 2>/dev/null | while read -r line; do
      method=$(echo "$line" | sed -E 's/.*@(Get|Post|Put|Patch|Delete).*/\1/' | tr '[:upper:]' '[:lower:]')
      sub_path=$(echo "$line" | sed -nE "s/.*@[A-Za-z]+\(['\"]([^'\"]*)['\"].*/\1/p")

      full_path="/${base_path}"
      [ -n "$sub_path" ] && full_path="${full_path}/${sub_path}"

      # Normalize: remove trailing slash, collapse double slashes
      full_path=$(echo "$full_path" | sed 's|//|/|g;s|/$||')

      echo "${method}|${full_path}|${file}" >> "$TEMP_DIR/backend.txt"
    done
  done
fi

TOTAL_BACKEND=$(wc -l < "$TEMP_DIR/backend.txt" 2>/dev/null | tr -d ' ')
echo -e "  Found ${GREEN}$TOTAL_BACKEND${NC} backend endpoints"

# ─── Extract Frontend API Calls ───
echo -e "${CYAN}[2/3] Scanning frontend API clients...${NC}"

if [ -d "$API_CLIENT_DIR" ]; then
  find "$API_CLIENT_DIR" -name "*.ts" | sort | while read -r file; do
    # Extract apiClient.method('/path') calls using sed (macOS-compatible)
    # Match quoted paths: apiClient.get('/path') or apiClient.get("/path")
    grep -E "apiClient\.(get|post|put|patch|delete)" "$file" 2>/dev/null | while read -r line; do
      method=$(echo "$line" | sed -E 's/.*apiClient\.(get|post|put|patch|delete).*/\1/')

      # Try quoted path: ('path') or ("path")
      path=$(echo "$line" | sed -nE "s/.*apiClient\.[a-z]+[^(]*\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")

      # Try backtick path: (`/path/${id}`)
      if [ -z "$path" ]; then
        path=$(echo "$line" | sed -nE 's/.*apiClient\.[a-z]+[^(]*\([[:space:]]*`([^`]*)`.*/\1/p')
        # Replace ${...} with :param
        path=$(echo "$path" | sed -E 's/\$\{[^}]*\}/:param/g')
      fi

      [ -z "$path" ] && continue
      echo "${method}|${path}|${file}" >> "$TEMP_DIR/frontend.txt"
    done
  done
fi

TOTAL_FRONTEND=$(wc -l < "$TEMP_DIR/frontend.txt" 2>/dev/null | tr -d ' ')
echo -e "  Found ${GREEN}$TOTAL_FRONTEND${NC} frontend API calls"

# ─── Normalize for Comparison ───
echo ""
echo -e "${CYAN}[3/3] Comparing...${NC}"
echo ""

# Normalize backend paths: :paramName → :param
if [ -s "$TEMP_DIR/backend.txt" ]; then
  while IFS='|' read -r method path file; do
    normalized=$(echo "$path" | sed 's/:[a-zA-Z]*/:param/g')
    echo "${method}|${normalized}" >> "$TEMP_DIR/backend_normalized.txt"
    echo "${method}|${normalized}|${path}|${file}" >> "$TEMP_DIR/backend_full.txt"
  done < "$TEMP_DIR/backend.txt"
fi

# Normalize frontend paths: :param already done for templates
if [ -s "$TEMP_DIR/frontend.txt" ]; then
  while IFS='|' read -r method path file; do
    normalized=$(echo "$path" | sed 's/:[a-zA-Z]*/:param/g')
    echo "${method}|${normalized}" >> "$TEMP_DIR/frontend_normalized.txt"
    echo "${method}|${normalized}|${path}|${file}" >> "$TEMP_DIR/frontend_full.txt"
  done < "$TEMP_DIR/frontend.txt"
fi

# Sort and unique
sort -u "$TEMP_DIR/backend_normalized.txt" > "$TEMP_DIR/backend_sorted.txt" 2>/dev/null
sort -u "$TEMP_DIR/frontend_normalized.txt" > "$TEMP_DIR/frontend_sorted.txt" 2>/dev/null

# ─── Backend without Frontend ───
echo -e "${BOLD}Backend endpoints without frontend API calls:${NC}"
MISSING_FE=0
while IFS='|' read -r method path; do
  if ! grep -qF "${method}|${path}" "$TEMP_DIR/frontend_sorted.txt" 2>/dev/null; then
    original=$(grep "^${method}|${path}|" "$TEMP_DIR/backend_full.txt" 2>/dev/null | head -1)
    orig_path=$(echo "$original" | cut -d'|' -f3)
    orig_file=$(echo "$original" | cut -d'|' -f4 | sed "s|$PROJECT_ROOT/||")
    method_upper=$(echo "$method" | tr '[:lower:]' '[:upper:]')
    echo -e "  ${YELLOW}UNUSED${NC}  ${method_upper} ${orig_path}  ${DIM}← ${orig_file}${NC}"
    MISSING_FE=$((MISSING_FE + 1))
  fi
done < "$TEMP_DIR/backend_sorted.txt"

if [ "$MISSING_FE" -eq 0 ]; then
  echo -e "  ${GREEN}All backend endpoints have frontend calls.${NC}"
fi

echo ""

# ─── Frontend without Backend ───
echo -e "${BOLD}Frontend API calls without backend endpoints:${NC}"
MISSING_BE=0
while IFS='|' read -r method path; do
  if ! grep -qF "${method}|${path}" "$TEMP_DIR/backend_sorted.txt" 2>/dev/null; then
    original=$(grep "^${method}|${path}|" "$TEMP_DIR/frontend_full.txt" 2>/dev/null | head -1)
    orig_path=$(echo "$original" | cut -d'|' -f3)
    orig_file=$(echo "$original" | cut -d'|' -f4 | sed "s|$PROJECT_ROOT/||")
    method_upper=$(echo "$method" | tr '[:lower:]' '[:upper:]')
    echo -e "  ${RED}ORPHAN${NC}  ${method_upper} ${orig_path}  ${DIM}← ${orig_file}${NC}"
    MISSING_BE=$((MISSING_BE + 1))
  fi
done < "$TEMP_DIR/frontend_sorted.txt"

if [ "$MISSING_BE" -eq 0 ]; then
  echo -e "  ${GREEN}All frontend calls have backend endpoints.${NC}"
fi

echo ""

# ─── Summary ───
echo "================================"
ISSUES=$((MISSING_FE + MISSING_BE))

echo -e "  Backend endpoints:  ${BOLD}$TOTAL_BACKEND${NC}"
echo -e "  Frontend API calls: ${BOLD}$TOTAL_FRONTEND${NC}"
echo ""

if [ "$MISSING_BE" -gt 0 ]; then
  echo -e "  ${RED}$MISSING_BE frontend calls will 404 (no backend endpoint)${NC}"
fi
if [ "$MISSING_FE" -gt 0 ]; then
  echo -e "  ${YELLOW}$MISSING_FE backend endpoints unused by frontend (may be used elsewhere)${NC}"
fi

if [ "$MISSING_BE" -eq 0 ]; then
  echo -e "  ${GREEN}PASS — No orphaned frontend calls.${NC}"
else
  echo -e "  ${RED}FAIL — Fix orphaned frontend calls to prevent 404s.${NC}"
fi

echo ""
# Only fail on frontend orphans (those cause real bugs)
exit $( [ "$MISSING_BE" -gt 0 ] && echo 1 || echo 0 )
