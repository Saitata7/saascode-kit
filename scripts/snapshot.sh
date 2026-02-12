#!/bin/bash
# SaasCode Kit — Snapshot Generator
# Generates .claude/context/project-map.md from actual codebase
# Usage: saascode snapshot  OR  bash saascode-kit/scripts/snapshot.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Find project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CONTEXT_DIR="$PROJECT_ROOT/.claude/context"
OUTPUT="$CONTEXT_DIR/project-map.md"

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
      /^[a-z]/ && $1 == key":" { val=$0; sub(/^[^:]+:[[:space:]]*/, "", val); gsub(/^"|"$/, "", val); print val; exit }
    ' "$MANIFEST"
  else
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

# Read paths from manifest with sensible fallbacks
PROJECT_NAME=$(read_manifest "project.name" "Project")
BACKEND_PATH=$(read_manifest "paths.backend" "apps/api")
FRONTEND_PATH=$(read_manifest "paths.frontend" "apps/portal")
SCHEMA_REL=$(read_manifest "paths.schema" "${BACKEND_PATH}/prisma/schema.prisma")
API_CLIENT_REL=$(read_manifest "paths.api_client" "${FRONTEND_PATH}/src/lib/api")
COMPONENTS_REL=$(read_manifest "paths.components" "${FRONTEND_PATH}/src/components")

# Build absolute paths
SCHEMA="$PROJECT_ROOT/$SCHEMA_REL"
CONTROLLERS_DIR="$PROJECT_ROOT/$BACKEND_PATH/src/modules"
PAGES_DIR="$PROJECT_ROOT/$FRONTEND_PATH/src/app/(dashboard)"
COMPONENTS_DIR="$PROJECT_ROOT/$COMPONENTS_REL"
API_CLIENT_DIR="$PROJECT_ROOT/$API_CLIENT_REL"

# Fallback: detect common structures if primary paths don't exist
if [ ! -d "$CONTROLLERS_DIR" ]; then
  for CANDIDATE in "$PROJECT_ROOT/$BACKEND_PATH/src/controllers" "$PROJECT_ROOT/src/modules" "$PROJECT_ROOT/src/controllers"; do
    [ -d "$CANDIDATE" ] && CONTROLLERS_DIR="$CANDIDATE" && break
  done
fi

if [ ! -d "$PAGES_DIR" ]; then
  for CANDIDATE in "$PROJECT_ROOT/$FRONTEND_PATH/src/app" "$PROJECT_ROOT/$FRONTEND_PATH/src/pages" "$PROJECT_ROOT/src/app" "$PROJECT_ROOT/src/pages"; do
    [ -d "$CANDIDATE" ] && PAGES_DIR="$CANDIDATE" && break
  done
fi

echo -e "${CYAN}Generating project snapshot...${NC}"
echo ""

mkdir -p "$CONTEXT_DIR"

# Start output
cat > "$OUTPUT" << EOF
# ${PROJECT_NAME} Project Map (auto-generated)

EOF

# ─── 1. Models ───
echo -e "${YELLOW}[1/5] Extracting models from schema...${NC}"
if [ -f "$SCHEMA" ]; then
  echo "## Models" >> "$OUTPUT"
  # Extract model names and their fields in compact format
  awk '
    /^model / { model=$2; fields=""; next }
    /^}/ { if(model) { print model ": " substr(fields, 2); model="" } }
    model && /^\s+\w/ {
      # Skip relation-only lines and @@
      if ($0 ~ /@@/ || $0 ~ /^\s+\/\//) next
      field=$1
      type=$2
      # Skip if field starts with @@ or is empty
      if (field ~ /^@@/) next
      if (field == "") next
      # Clean up type
      gsub(/\?/, "?", type)
      gsub(/\[\]/, "[]", type)
      # Append
      fields = fields "," field
    }
  ' "$SCHEMA" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
  MODEL_COUNT=$(grep -c "^model " "$SCHEMA" 2>/dev/null || echo "0")
  echo -e "  ${GREEN}Found $MODEL_COUNT models${NC}"
else
  echo "## Models" >> "$OUTPUT"
  echo "(schema not found at $SCHEMA_REL)" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
fi

# ─── 2. Enums ───
echo -e "${YELLOW}[2/5] Extracting enums...${NC}"
if [ -f "$SCHEMA" ]; then
  echo "## Enums" >> "$OUTPUT"
  awk '
    /^enum / { enum=$2; values=""; next }
    /^}/ { if(enum) { print enum ": " substr(values, 2); enum="" } }
    enum && /^\s+\w/ {
      if ($1 ~ /^\/\//) next
      values = values "," $1
    }
  ' "$SCHEMA" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
  ENUM_COUNT=$(grep -c "^enum " "$SCHEMA" 2>/dev/null || echo "0")
  echo -e "  ${GREEN}Found $ENUM_COUNT enums${NC}"
fi

# ─── 3. Endpoints ───
echo -e "${YELLOW}[3/5] Extracting endpoints from controllers...${NC}"
echo "## Tenant Endpoints" >> "$OUTPUT"
if [ -d "$CONTROLLERS_DIR" ]; then
  # Find all non-platform controllers
  find "$CONTROLLERS_DIR" -name "*.controller.ts" -not -path "*/platform/*" | sort | while read -r file; do
    module=$(basename "$(dirname "$file")")
    controller_path=$(grep -oP "@Controller\(['\"]([^'\"]*)['\"]" "$file" 2>/dev/null | head -1 | sed "s/@Controller(['\"]//;s/['\"]//")

    if [ -n "$controller_path" ]; then
      echo "${controller_path}:" >> "$OUTPUT"
    else
      echo "${module}:" >> "$OUTPUT"
    fi

    # Extract routes
    grep -nE "@(Get|Post|Put|Patch|Delete)" "$file" 2>/dev/null | while read -r line; do
      method=$(echo "$line" | grep -oP "@(Get|Post|Put|Patch|Delete)" | sed 's/@//')
      path=$(echo "$line" | grep -oP "\(['\"]([^'\"]*)['\"]" | sed "s/[('\"')]//g")

      # Get roles from next few lines
      line_num=$(echo "$line" | cut -d: -f1)
      roles_line=$(sed -n "$((line_num-2)),$((line_num+2))p" "$file" | grep -oP "@Roles\(([^)]*)\)" | head -1)
      roles=$(echo "$roles_line" | sed 's/@Roles(//;s/)//;s/TenantRole\.//g;s/ //g')

      if [ -z "$roles" ]; then
        roles="ANY"
      fi

      method_upper=$(echo "$method" | tr '[:lower:]' '[:upper:]')
      echo "  ${method_upper} /${path} → ${roles}" >> "$OUTPUT"
    done
    echo "" >> "$OUTPUT"
  done
  CTRL_COUNT=$(find "$CONTROLLERS_DIR" -name "*.controller.ts" -not -path "*/platform/*" | wc -l | tr -d ' ')
  echo -e "  ${GREEN}Found $CTRL_COUNT controllers${NC}"
fi

# ─── 4. Pages ───
echo -e "${YELLOW}[4/5] Extracting pages...${NC}"
echo "## Pages" >> "$OUTPUT"
if [ -d "$PAGES_DIR" ]; then
  find "$PAGES_DIR" -name "page.tsx" | sort | while read -r file; do
    # Extract route from file path
    route=$(echo "$file" | sed "s|$PAGES_DIR||;s|/page.tsx||")
    if [ -z "$route" ]; then route="/"; fi

    # Extract API calls
    api_calls=$(grep -oP "(api\w+|apiClient)\.\w+" "$file" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')

    if [ -n "$api_calls" ]; then
      echo "${route} → ${api_calls}" >> "$OUTPUT"
    else
      echo "${route}" >> "$OUTPUT"
    fi
  done
  echo "" >> "$OUTPUT"
  PAGE_COUNT=$(find "$PAGES_DIR" -name "page.tsx" | wc -l | tr -d ' ')
  echo -e "  ${GREEN}Found $PAGE_COUNT pages${NC}"
fi

# ─── 5. Components & API Client Files ───
echo -e "${YELLOW}[5/5] Extracting components and API client files...${NC}"

echo "## Reusable Components" >> "$OUTPUT"
if [ -d "$COMPONENTS_DIR" ]; then
  # List component directories and key files
  for dir in "$COMPONENTS_DIR"/*/; do
    category=$(basename "$dir")
    files=$(ls "$dir"*.tsx 2>/dev/null | xargs -I{} basename {} .tsx | tr '\n' ',' | sed 's/,$//')
    if [ -n "$files" ]; then
      echo "${category}: ${files}" >> "$OUTPUT"
    fi
  done
  echo "" >> "$OUTPUT"
fi

echo "## API Client Files" >> "$OUTPUT"
if [ -d "$API_CLIENT_DIR" ]; then
  files=$(ls "$API_CLIENT_DIR"/*.ts 2>/dev/null | xargs -I{} basename {} .ts | tr '\n' ',' | sed 's/,$//')
  echo "Files: ${files}" >> "$OUTPUT"
  echo "Path: ${API_CLIENT_REL}/[name].ts" >> "$OUTPUT"
  echo "Import: apiClient from @/lib/api-client" >> "$OUTPUT"
fi

echo ""
echo -e "${GREEN}Snapshot generated: ${OUTPUT}${NC}"
echo -e "  Models: ${MODEL_COUNT:-0}"
echo -e "  Enums: ${ENUM_COUNT:-0}"
echo -e "  Controllers: ${CTRL_COUNT:-0}"
echo -e "  Pages: ${PAGE_COUNT:-0}"
echo ""
echo -e "${CYAN}Run this after major changes to keep the project map current.${NC}"
