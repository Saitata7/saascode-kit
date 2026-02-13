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

# Source shared library for detection helpers
_LIB="$(dirname "$0")/lib.sh"
[ -f "$_LIB" ] || _LIB="$PROJECT_ROOT/saascode-kit/scripts/lib.sh"
[ -f "$_LIB" ] || _LIB="$PROJECT_ROOT/.saascode/scripts/lib.sh"
if [ -f "$_LIB" ]; then
  source "$_LIB"
  export _LIB_ROOT="$PROJECT_ROOT"
  MANIFEST=""
  for CANDIDATE in "$PROJECT_ROOT/saascode-kit/manifest.yaml" "$PROJECT_ROOT/.saascode/manifest.yaml" "$PROJECT_ROOT/manifest.yaml" "$PROJECT_ROOT/saascode-kit.yaml"; do
    [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
  done
  [ -n "$MANIFEST" ] && load_manifest_vars "$MANIFEST"
fi

# ─── Read manifest.yaml values ───
read_manifest() {
  local KEY="$1"
  local DEFAULT="$2"
  local MANIFEST=""

  for CANDIDATE in "$PROJECT_ROOT/saascode-kit/manifest.yaml" "$PROJECT_ROOT/.saascode/manifest.yaml" "$PROJECT_ROOT/manifest.yaml" "$PROJECT_ROOT/saascode-kit.yaml"; do
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
BACKEND_DIR=$(read_manifest "paths.backend" "apps/api")
FRONTEND_DIR=$(read_manifest "paths.frontend" "apps/portal")
API_CLIENT_REL=$(read_manifest "paths.api_client" "${FRONTEND_DIR}/src/lib/api")

BE_FW="${BACKEND_FRAMEWORK:-$(read_manifest "stack.backend.framework" "nestjs")}"
FE_FW="${FRONTEND_FRAMEWORK:-$(read_manifest "stack.frontend.framework" "nextjs")}"

CONTROLLERS_DIR="$PROJECT_ROOT/$BACKEND_DIR/src/modules"
API_CLIENT_DIR="$PROJECT_ROOT/$API_CLIENT_REL"

TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

echo -e "${BOLD}Endpoint Parity Check${NC}"
echo "================================"
echo -e "  Stack: $BE_FW / $FE_FW"
echo ""

touch "$TEMP_DIR/backend.txt" "$TEMP_DIR/frontend.txt"
touch "$TEMP_DIR/backend_normalized.txt" "$TEMP_DIR/frontend_normalized.txt"
touch "$TEMP_DIR/backend_full.txt" "$TEMP_DIR/frontend_full.txt"

# ─── Extract Backend Endpoints — Framework-aware ───
echo -e "${CYAN}[1/3] Scanning backend endpoints...${NC}"

case "$BE_FW" in
  nestjs)
    if [ -d "$CONTROLLERS_DIR" ]; then
      find "$CONTROLLERS_DIR" -name "*.controller.ts" -not -path "*/platform/*" | sort | while read -r file; do
        controller_line=$(grep "@Controller(" "$file" 2>/dev/null | head -1)
        [ -z "$controller_line" ] && continue
        base_path=""
        if echo "$controller_line" | grep -qE "@Controller\(['\"]"; then
          base_path=$(echo "$controller_line" | sed -E "s/.*@Controller\(['\"]([^'\"]*)['\"].*/\1/")
        fi
        grep -nE "@(Get|Post|Put|Patch|Delete)" "$file" 2>/dev/null | while read -r line; do
          method=$(echo "$line" | sed -E 's/.*@(Get|Post|Put|Patch|Delete).*/\1/' | tr '[:upper:]' '[:lower:]')
          sub_path=$(echo "$line" | sed -nE "s/.*@[A-Za-z]+\(['\"]([^'\"]*)['\"].*/\1/p")
          full_path="/${base_path}"
          [ -n "$sub_path" ] && full_path="${full_path}/${sub_path}"
          full_path=$(echo "$full_path" | sed 's|//|/|g;s|/$||')
          echo "${method}|${full_path}|${file}" >> "$TEMP_DIR/backend.txt"
        done
      done
    fi
    ;;
  express|fastify|hono)
    find "$PROJECT_ROOT/$BACKEND_DIR/src" \( -name "*.route.ts" -o -name "*.routes.ts" -o -name "*.route.js" -o -name "*.routes.js" -o -name "router.*" \) 2>/dev/null | sort | while read -r file; do
      grep -nE "router\.(get|post|put|patch|delete)\(" "$file" 2>/dev/null | while read -r line; do
        method=$(echo "$line" | sed -E 's/.*router\.(get|post|put|patch|delete).*/\1/')
        path=$(echo "$line" | sed -nE "s/.*router\.[a-z]+\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
        [ -z "$path" ] && continue
        echo "${method}|${path}|${file}" >> "$TEMP_DIR/backend.txt"
      done
    done
    ;;
  django)
    find "$PROJECT_ROOT/$BACKEND_DIR" -name "urls.py" 2>/dev/null | sort | while read -r file; do
      grep -nE "path\(" "$file" 2>/dev/null | while read -r line; do
        path=$(echo "$line" | sed -nE "s/.*path\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
        [ -z "$path" ] && continue
        # Django urls don't always specify methods — default to get
        echo "get|/${path}|${file}" >> "$TEMP_DIR/backend.txt"
      done
    done
    ;;
  flask)
    grep -rl '@.*\.route(' --include="*.py" "$PROJECT_ROOT/$BACKEND_DIR/" 2>/dev/null | sort | while read -r file; do
      grep -nE '@.*\.route\(' "$file" 2>/dev/null | while read -r line; do
        path=$(echo "$line" | sed -nE "s/.*\.route\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
        methods=$(echo "$line" | sed -nE "s/.*methods=\[([^]]*)\].*/\1/p" | tr -d "'\"" | tr ',' '\n' | tr '[:upper:]' '[:lower:]')
        [ -z "$path" ] && continue
        if [ -z "$methods" ]; then
          echo "get|${path}|${file}" >> "$TEMP_DIR/backend.txt"
        else
          echo "$methods" | while read -r m; do
            [ -n "$m" ] && echo "${m}|${path}|${file}" >> "$TEMP_DIR/backend.txt"
          done
        fi
      done
    done
    ;;
  rails)
    ROUTES_FILE="$PROJECT_ROOT/$BACKEND_DIR/config/routes.rb"
    if [ -f "$ROUTES_FILE" ]; then
      grep -nE '(get|post|put|patch|delete)\s' "$ROUTES_FILE" 2>/dev/null | while read -r line; do
        method=$(echo "$line" | sed -E 's/.*\b(get|post|put|patch|delete)\b.*/\1/')
        path=$(echo "$line" | sed -nE "s/.*\b(get|post|put|patch|delete)\s+['\"]([^'\"]*)['\"].*/\2/p")
        [ -n "$path" ] && echo "${method}|/${path}|${ROUTES_FILE}" >> "$TEMP_DIR/backend.txt"
      done
    fi
    ;;
  spring)
    find "$PROJECT_ROOT/$BACKEND_DIR/src" \( -name "*Controller.java" -o -name "*Controller.kt" \) 2>/dev/null | sort | while read -r file; do
      # Get base RequestMapping
      base_path=$(grep -oE '@RequestMapping\([[:space:]]*"([^"]*)"' "$file" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)".*/\1/')
      grep -nE "@(Get|Post|Put|Patch|Delete)Mapping" "$file" 2>/dev/null | while read -r line; do
        method=$(echo "$line" | sed -E 's/.*@(Get|Post|Put|Patch|Delete)Mapping.*/\1/' | tr '[:upper:]' '[:lower:]')
        sub_path=$(echo "$line" | sed -nE 's/.*Mapping\([[:space:]]*"([^"]*)".*/\1/p')
        full_path="${base_path}${sub_path}"
        [ -z "$full_path" ] && full_path="/"
        echo "${method}|${full_path}|${file}" >> "$TEMP_DIR/backend.txt"
      done
    done
    ;;
  laravel)
    API_ROUTES="$PROJECT_ROOT/$BACKEND_DIR/routes/api.php"
    if [ -f "$API_ROUTES" ]; then
      grep -nE "Route::(get|post|put|patch|delete)" "$API_ROUTES" 2>/dev/null | while read -r line; do
        method=$(echo "$line" | sed -E 's/.*Route::(get|post|put|patch|delete).*/\1/')
        path=$(echo "$line" | sed -nE "s/.*Route::[a-z]+\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
        [ -n "$path" ] && echo "${method}|/${path}|${API_ROUTES}" >> "$TEMP_DIR/backend.txt"
      done
    fi
    ;;
esac

TOTAL_BACKEND=$(wc -l < "$TEMP_DIR/backend.txt" 2>/dev/null | tr -d ' ')
echo -e "  Found ${GREEN}$TOTAL_BACKEND${NC} backend endpoints"

# ─── Extract Frontend API Calls — Framework-aware ───
echo -e "${CYAN}[2/3] Scanning frontend API clients...${NC}"

case "$FE_FW" in
  nextjs|react)
    # Try apiClient pattern first
    if [ -d "$API_CLIENT_DIR" ]; then
      find "$API_CLIENT_DIR" -name "*.ts" -o -name "*.js" | sort | while read -r file; do
        grep -E "apiClient\.(get|post|put|patch|delete)" "$file" 2>/dev/null | while read -r line; do
          method=$(echo "$line" | sed -E 's/.*apiClient\.(get|post|put|patch|delete).*/\1/')
          path=$(echo "$line" | sed -nE "s/.*apiClient\.[a-z]+[^(]*\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
          if [ -z "$path" ]; then
            path=$(echo "$line" | sed -nE 's/.*apiClient\.[a-z]+[^(]*\([[:space:]]*`([^`]*)`.*/\1/p')
            path=$(echo "$path" | sed -E 's/\$\{[^}]*\}/:param/g')
          fi
          [ -z "$path" ] && continue
          echo "${method}|${path}|${file}" >> "$TEMP_DIR/frontend.txt"
        done
      done
    fi
    # Also check for axios/fetch patterns
    if [ ! -s "$TEMP_DIR/frontend.txt" ]; then
      find "$PROJECT_ROOT/$FRONTEND_DIR/src" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) -not -path "*/node_modules/*" 2>/dev/null | sort | while read -r file; do
        grep -E "axios\.(get|post|put|patch|delete)\|fetch\(" "$file" 2>/dev/null | while read -r line; do
          method=$(echo "$line" | sed -nE 's/.*axios\.(get|post|put|patch|delete).*/\1/p')
          [ -z "$method" ] && method="get"
          path=$(echo "$line" | sed -nE "s/.*\.[a-z]+\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
          [ -z "$path" ] && continue
          # Only count API paths
          echo "$path" | grep -q '^/' && echo "${method}|${path}|${file}" >> "$TEMP_DIR/frontend.txt"
        done
      done
    fi
    ;;
  vue)
    find "$PROJECT_ROOT/$FRONTEND_DIR/src" \( -name "*.vue" -o -name "*.ts" -o -name "*.js" \) -not -path "*/node_modules/*" 2>/dev/null | sort | while read -r file; do
      grep -E "(axios|fetch|http)\.(get|post|put|patch|delete)\|this\.\$http\." "$file" 2>/dev/null | while read -r line; do
        method=$(echo "$line" | sed -nE 's/.*(axios|http)\.(get|post|put|patch|delete).*/\2/p')
        [ -z "$method" ] && method="get"
        path=$(echo "$line" | sed -nE "s/.*\.[a-z]+\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
        [ -z "$path" ] && continue
        echo "$path" | grep -q '^/' && echo "${method}|${path}|${file}" >> "$TEMP_DIR/frontend.txt"
      done
    done
    ;;
  angular)
    find "$PROJECT_ROOT/$FRONTEND_DIR/src" -name "*.service.ts" -o -name "*.ts" 2>/dev/null | sort | while read -r file; do
      grep -E "this\.http\.(get|post|put|patch|delete)" "$file" 2>/dev/null | while read -r line; do
        method=$(echo "$line" | sed -nE 's/.*this\.http\.(get|post|put|patch|delete).*/\1/p')
        path=$(echo "$line" | sed -nE "s/.*this\.http\.[a-z]+[^(]*\([[:space:]]*['\"\`]([^'\"\`]*)['\"\`].*/\1/p")
        path=$(echo "$path" | sed -E 's/\$\{[^}]*\}/:param/g')
        [ -z "$path" ] && continue
        echo "${method}|${path}|${file}" >> "$TEMP_DIR/frontend.txt"
      done
    done
    ;;
  svelte)
    find "$PROJECT_ROOT/$FRONTEND_DIR/src" \( -name "*.svelte" -o -name "*.ts" -o -name "*.js" \) -not -path "*/node_modules/*" 2>/dev/null | sort | while read -r file; do
      grep -E "(fetch|axios)\.(get|post|put|patch|delete)\|fetch\(" "$file" 2>/dev/null | while read -r line; do
        method=$(echo "$line" | sed -nE 's/.*\.(get|post|put|patch|delete).*/\1/p')
        [ -z "$method" ] && method="get"
        path=$(echo "$line" | sed -nE "s/.*\([[:space:]]*['\"\`]([^'\"\`]*)['\"\`].*/\1/p")
        path=$(echo "$path" | sed -E 's/\$\{[^}]*\}/:param/g')
        [ -z "$path" ] && continue
        echo "$path" | grep -q '^/' && echo "${method}|${path}|${file}" >> "$TEMP_DIR/frontend.txt"
      done
    done
    ;;
esac

TOTAL_FRONTEND=$(wc -l < "$TEMP_DIR/frontend.txt" 2>/dev/null | tr -d ' ')
echo -e "  Found ${GREEN}$TOTAL_FRONTEND${NC} frontend API calls"

# ─── Graceful skip if no endpoints ───
if [ "$TOTAL_BACKEND" -eq 0 ] && [ "$TOTAL_FRONTEND" -eq 0 ]; then
  echo ""
  echo -e "  ${YELLOW}No endpoints found on either side — skipping comparison.${NC}"
  echo ""
  echo "================================"
  echo -e "  Backend endpoints:  ${BOLD}0${NC}"
  echo -e "  Frontend API calls: ${BOLD}0${NC}"
  echo ""
  echo -e "  ${YELLOW}SKIP — Nothing to compare.${NC}"
  echo ""
  exit 0
fi

# ─── Normalize for Comparison ───
echo ""
echo -e "${CYAN}[3/3] Comparing...${NC}"
echo ""

# Normalize backend paths: :paramName → :param
if [ -s "$TEMP_DIR/backend.txt" ]; then
  while IFS='|' read -r method path file; do
    normalized=$(echo "$path" | sed 's/:[a-zA-Z]*/:param/g;s/<[^>]*>/:param/g')
    echo "${method}|${normalized}" >> "$TEMP_DIR/backend_normalized.txt"
    echo "${method}|${normalized}|${path}|${file}" >> "$TEMP_DIR/backend_full.txt"
  done < "$TEMP_DIR/backend.txt"
fi

# Normalize frontend paths: :param already done for templates
if [ -s "$TEMP_DIR/frontend.txt" ]; then
  while IFS='|' read -r method path file; do
    normalized=$(echo "$path" | sed 's/:[a-zA-Z]*/:param/g;s/<[^>]*>/:param/g')
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
