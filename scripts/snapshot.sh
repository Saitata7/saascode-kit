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

# Read paths from manifest with sensible fallbacks
PROJECT_NAME=$(read_manifest "project.name" "Project")
BACKEND_DIR=$(read_manifest "paths.backend" "apps/api")
FRONTEND_DIR=$(read_manifest "paths.frontend" "apps/portal")
SCHEMA_REL=$(read_manifest "paths.schema" "${BACKEND_DIR}/prisma/schema.prisma")
API_CLIENT_REL=$(read_manifest "paths.api_client" "${FRONTEND_DIR}/src/lib/api")
COMPONENTS_REL=$(read_manifest "paths.components" "${FRONTEND_DIR}/src/components")

BE_FW="${BACKEND_FRAMEWORK:-$(read_manifest "stack.backend.framework" "nestjs")}"
FE_FW="${FRONTEND_FRAMEWORK:-$(read_manifest "stack.frontend.framework" "nextjs")}"
ORM_NAME="${ORM:-$(read_manifest "stack.backend.orm" "prisma")}"
LANG="${LANGUAGE:-$(read_manifest "stack.language" "typescript")}"
SRC_EXT="$(get_source_extensions 2>/dev/null || echo 'ts|tsx')"

# Build absolute paths
SCHEMA="$PROJECT_ROOT/$SCHEMA_REL"
CONTROLLERS_DIR="$PROJECT_ROOT/$BACKEND_DIR/src/modules"
PAGES_DIR="$PROJECT_ROOT/$FRONTEND_DIR/src/app/(dashboard)"
COMPONENTS_DIR="$PROJECT_ROOT/$COMPONENTS_REL"
API_CLIENT_DIR="$PROJECT_ROOT/$API_CLIENT_REL"

# Fallback: detect common structures if primary paths don't exist
if [ ! -d "$CONTROLLERS_DIR" ]; then
  for CANDIDATE in "$PROJECT_ROOT/$BACKEND_DIR/src/controllers" "$PROJECT_ROOT/src/modules" "$PROJECT_ROOT/src/controllers" "$PROJECT_ROOT/$BACKEND_DIR/app/controllers" "$PROJECT_ROOT/$BACKEND_DIR/src"; do
    [ -d "$CANDIDATE" ] && CONTROLLERS_DIR="$CANDIDATE" && break
  done
fi

if [ ! -d "$PAGES_DIR" ]; then
  for CANDIDATE in "$PROJECT_ROOT/$FRONTEND_DIR/src/app" "$PROJECT_ROOT/$FRONTEND_DIR/src/pages" "$PROJECT_ROOT/src/app" "$PROJECT_ROOT/src/pages" "$PROJECT_ROOT/$FRONTEND_DIR/src/routes"; do
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
echo -e "${YELLOW}[1/6] Extracting models...${NC}"
echo "## Models" >> "$OUTPUT"

case "$ORM_NAME" in
  prisma)
    if [ -f "$SCHEMA" ]; then
      awk '
        /^model / { model=$2; fields=""; next }
        /^}/ { if(model) { print model ": " substr(fields, 2); model="" } }
        model && /^\s+\w/ {
          if ($0 ~ /@@/ || $0 ~ /^\s+\/\//) next
          field=$1; type=$2
          if (field ~ /^@@/) next
          if (field == "") next
          gsub(/\?/, "?", type); gsub(/\[\]/, "[]", type)
          fields = fields "," field
        }
      ' "$SCHEMA" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
      MODEL_COUNT=$(grep -c "^model " "$SCHEMA" 2>/dev/null || echo "0")
      echo -e "  ${GREEN}Found $MODEL_COUNT models${NC}"
    else
      echo "(No Prisma schema found at $SCHEMA_REL)" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
    fi
    ;;
  typeorm)
    ENTITY_FILES=$(find "$PROJECT_ROOT/$BACKEND_DIR/src" -name "*.entity.ts" 2>/dev/null)
    if [ -n "$ENTITY_FILES" ]; then
      echo "$ENTITY_FILES" | while read -r file; do
        name=$(grep -oE 'class\s+\w+' "$file" 2>/dev/null | head -1 | sed 's/class //')
        rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
        [ -n "$name" ] && echo "- $name ($rel)" >> "$OUTPUT"
      done
      MODEL_COUNT=$(echo "$ENTITY_FILES" | wc -l | tr -d ' ')
      echo -e "  ${GREEN}Found $MODEL_COUNT entities${NC}"
    else
      echo "(No TypeORM entities found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  django)
    MODEL_FILES=$(find "$PROJECT_ROOT/$BACKEND_DIR" -name "models.py" 2>/dev/null)
    if [ -n "$MODEL_FILES" ]; then
      echo "$MODEL_FILES" | while read -r file; do
        grep -oE 'class\s+\w+\(.*models\.Model' "$file" 2>/dev/null | while read -r line; do
          name=$(echo "$line" | sed 's/class //;s/(.*$//')
          rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
          echo "- $name ($rel)" >> "$OUTPUT"
        done
      done
      MODEL_COUNT=$(grep -rcoE 'class\s+\w+\(.*models\.Model' --include="models.py" "$PROJECT_ROOT/$BACKEND_DIR/" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}')
      echo -e "  ${GREEN}Found $MODEL_COUNT models${NC}"
    else
      echo "(No Django models found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  sqlalchemy)
    SA_FILES=$(grep -rl 'Base\|DeclarativeBase' --include="*.py" "$PROJECT_ROOT/$BACKEND_DIR/" 2>/dev/null | head -20)
    if [ -n "$SA_FILES" ]; then
      echo "$SA_FILES" | while read -r file; do
        grep -oE 'class\s+\w+\(' "$file" 2>/dev/null | sed 's/class //;s/(//' | while read -r name; do
          rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
          echo "- $name ($rel)" >> "$OUTPUT"
        done
      done
      echo -e "  ${GREEN}Found SQLAlchemy models${NC}"
    else
      echo "(No SQLAlchemy models found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  sequelize)
    SEQ_FILES=$(find "$PROJECT_ROOT/$BACKEND_DIR/src" -name "*.model.ts" -o -name "*.model.js" 2>/dev/null)
    if [ -n "$SEQ_FILES" ]; then
      echo "$SEQ_FILES" | while read -r file; do
        name=$(grep -oE 'class\s+\w+' "$file" 2>/dev/null | head -1 | sed 's/class //')
        rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
        [ -n "$name" ] && echo "- $name ($rel)" >> "$OUTPUT"
      done
      echo -e "  ${GREEN}Found Sequelize models${NC}"
    else
      echo "(No Sequelize models found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  mongoose)
    MONGOOSE_FILES=$(grep -rl 'new Schema\|mongoose\.model' --include="*.ts" --include="*.js" "$PROJECT_ROOT/$BACKEND_DIR/src/" 2>/dev/null | head -20)
    if [ -n "$MONGOOSE_FILES" ]; then
      echo "$MONGOOSE_FILES" | while read -r file; do
        name=$(grep -oE "mongoose\.model\(['\"][^'\"]+['\"]" "$file" 2>/dev/null | head -1 | sed "s/mongoose.model(['\"]//;s/['\"]//")
        [ -z "$name" ] && name=$(basename "$file" | sed 's/\.\(ts\|js\)$//')
        rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
        echo "- $name ($rel)" >> "$OUTPUT"
      done
      echo -e "  ${GREEN}Found Mongoose schemas${NC}"
    else
      echo "(No Mongoose schemas found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  drizzle)
    DRIZZLE_FILES=$(grep -rl 'pgTable\|mysqlTable\|sqliteTable' --include="*.ts" "$PROJECT_ROOT/$BACKEND_DIR/src/" 2>/dev/null | head -20)
    if [ -n "$DRIZZLE_FILES" ]; then
      echo "$DRIZZLE_FILES" | while read -r file; do
        grep -oE '\w+\s*=\s*(pgTable|mysqlTable|sqliteTable)' "$file" 2>/dev/null | sed 's/\s*=.*$//' | while read -r name; do
          rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
          echo "- $name ($rel)" >> "$OUTPUT"
        done
      done
      echo -e "  ${GREEN}Found Drizzle tables${NC}"
    else
      echo "(No Drizzle tables found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  *)
    # Fallback: look for type/interface definitions or classes
    TYPES_FOUND=$(grep -rn 'export\s\+\(interface\|type\|class\)\s' --include="*.ts" --include="*.py" --include="*.java" --include="*.rb" --include="*.go" "$PROJECT_ROOT/$BACKEND_DIR/src/" 2>/dev/null | head -20)
    if [ -n "$TYPES_FOUND" ]; then
      echo "$TYPES_FOUND" | while read -r line; do
        name=$(echo "$line" | sed -nE 's/.*export\s+(interface|type|class)\s+([A-Za-z_]+).*/\2/p')
        file=$(echo "$line" | cut -d: -f1 | sed "s|$PROJECT_ROOT/||")
        [ -n "$name" ] && echo "- $name ($file)" >> "$OUTPUT"
      done
    else
      echo "(No models/types found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
esac

# ─── 2. Enums ───
echo -e "${YELLOW}[2/6] Extracting enums...${NC}"
if [ -f "$SCHEMA" ] && [ "$ORM_NAME" = "prisma" ]; then
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
echo -e "${YELLOW}[3/6] Extracting endpoints...${NC}"
echo "## Endpoints" >> "$OUTPUT"

case "$BE_FW" in
  nestjs)
    if [ -d "$CONTROLLERS_DIR" ]; then
      find "$CONTROLLERS_DIR" -name "*.controller.ts" -not -path "*/platform/*" | sort | while read -r file; do
        module=$(basename "$(dirname "$file")")
        controller_path=$(grep -oP "@Controller\(['\"]([^'\"]*)['\"]" "$file" 2>/dev/null | head -1 | sed "s/@Controller(['\"]//;s/['\"]//")
        if [ -n "$controller_path" ]; then
          echo "${controller_path}:" >> "$OUTPUT"
        else
          echo "${module}:" >> "$OUTPUT"
        fi
        grep -nE "@(Get|Post|Put|Patch|Delete)" "$file" 2>/dev/null | while read -r line; do
          method=$(echo "$line" | grep -oP "@(Get|Post|Put|Patch|Delete)" | sed 's/@//')
          path=$(echo "$line" | grep -oP "\(['\"]([^'\"]*)['\"]" | sed "s/[('\"')]//g")
          line_num=$(echo "$line" | cut -d: -f1)
          roles_line=$(sed -n "$((line_num-2)),$((line_num+2))p" "$file" | grep -oP "@Roles\(([^)]*)\)" | head -1)
          roles=$(echo "$roles_line" | sed 's/@Roles(//;s/)//;s/TenantRole\.//g;s/ //g')
          [ -z "$roles" ] && roles="ANY"
          method_upper=$(echo "$method" | tr '[:lower:]' '[:upper:]')
          echo "  ${method_upper} /${path} → ${roles}" >> "$OUTPUT"
        done
        echo "" >> "$OUTPUT"
      done
      CTRL_COUNT=$(find "$CONTROLLERS_DIR" -name "*.controller.ts" -not -path "*/platform/*" | wc -l | tr -d ' ')
      echo -e "  ${GREEN}Found $CTRL_COUNT controllers${NC}"
    fi
    ;;
  express|fastify|hono)
    ROUTE_FILES=$(find "$PROJECT_ROOT/$BACKEND_DIR/src" \( -name "*.route.ts" -o -name "*.routes.ts" -o -name "*.route.js" -o -name "*.routes.js" -o -name "router.*" \) 2>/dev/null | sort)
    if [ -n "$ROUTE_FILES" ]; then
      echo "$ROUTE_FILES" | while read -r file; do
        rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
        echo "${rel}:" >> "$OUTPUT"
        grep -nE "router\.(get|post|put|patch|delete)\(" "$file" 2>/dev/null | while read -r line; do
          method=$(echo "$line" | sed -E 's/.*router\.(get|post|put|patch|delete).*/\1/' | tr '[:lower:]' '[:upper:]')
          path=$(echo "$line" | sed -nE "s/.*router\.[a-z]+\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
          echo "  ${method} ${path}" >> "$OUTPUT"
        done
        echo "" >> "$OUTPUT"
      done
      CTRL_COUNT=$(echo "$ROUTE_FILES" | wc -l | tr -d ' ')
      echo -e "  ${GREEN}Found $CTRL_COUNT route files${NC}"
    else
      echo "(No route files found)" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
    fi
    ;;
  django)
    URL_FILES=$(find "$PROJECT_ROOT/$BACKEND_DIR" -name "urls.py" 2>/dev/null | sort)
    if [ -n "$URL_FILES" ]; then
      echo "$URL_FILES" | while read -r file; do
        rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
        echo "${rel}:" >> "$OUTPUT"
        grep -nE "path\(|re_path\(" "$file" 2>/dev/null | while read -r line; do
          path=$(echo "$line" | sed -nE "s/.*path\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
          [ -n "$path" ] && echo "  ${path}" >> "$OUTPUT"
        done
        echo "" >> "$OUTPUT"
      done
      echo -e "  ${GREEN}Found $(echo "$URL_FILES" | wc -l | tr -d ' ') url files${NC}"
    else
      echo "(No urls.py files found)" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
    fi
    ;;
  flask)
    FLASK_FILES=$(grep -rl '@.*\.route(' --include="*.py" "$PROJECT_ROOT/$BACKEND_DIR/" 2>/dev/null | sort)
    if [ -n "$FLASK_FILES" ]; then
      echo "$FLASK_FILES" | while read -r file; do
        rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
        echo "${rel}:" >> "$OUTPUT"
        grep -nE '@.*\.route\(' "$file" 2>/dev/null | while read -r line; do
          path=$(echo "$line" | sed -nE "s/.*\.route\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
          methods=$(echo "$line" | sed -nE "s/.*methods=\[([^]]*)\].*/\1/p" | tr -d "'\"" )
          [ -z "$methods" ] && methods="GET"
          [ -n "$path" ] && echo "  ${methods} ${path}" >> "$OUTPUT"
        done
        echo "" >> "$OUTPUT"
      done
      echo -e "  ${GREEN}Found Flask routes${NC}"
    else
      echo "(No Flask routes found)" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
    fi
    ;;
  rails)
    ROUTES_FILE="$PROJECT_ROOT/$BACKEND_DIR/config/routes.rb"
    if [ -f "$ROUTES_FILE" ]; then
      echo "config/routes.rb:" >> "$OUTPUT"
      grep -nE '(get|post|put|patch|delete|resources|resource)\s' "$ROUTES_FILE" 2>/dev/null | while read -r line; do
        echo "  $(echo "$line" | sed 's/^[0-9]*://')" >> "$OUTPUT"
      done
      echo "" >> "$OUTPUT"
      echo -e "  ${GREEN}Found Rails routes${NC}"
    else
      echo "(No routes.rb found)" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
    fi
    ;;
  spring)
    CTRL_FILES=$(find "$PROJECT_ROOT/$BACKEND_DIR/src" \( -name "*Controller.java" -o -name "*Controller.kt" \) 2>/dev/null | sort)
    if [ -n "$CTRL_FILES" ]; then
      echo "$CTRL_FILES" | while read -r file; do
        name=$(basename "$file" | sed 's/\.\(java\|kt\)$//')
        echo "${name}:" >> "$OUTPUT"
        grep -nE "@(Get|Post|Put|Patch|Delete|Request)Mapping" "$file" 2>/dev/null | while read -r line; do
          method=$(echo "$line" | sed -E 's/.*@(Get|Post|Put|Patch|Delete|Request)Mapping.*/\1/' | tr '[:lower:]' '[:upper:]')
          path=$(echo "$line" | sed -nE 's/.*Mapping\([[:space:]]*"([^"]*)".*/\1/p')
          echo "  ${method} ${path}" >> "$OUTPUT"
        done
        echo "" >> "$OUTPUT"
      done
      CTRL_COUNT=$(echo "$CTRL_FILES" | wc -l | tr -d ' ')
      echo -e "  ${GREEN}Found $CTRL_COUNT controllers${NC}"
    else
      echo "(No Spring controllers found)" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
    fi
    ;;
  laravel)
    API_ROUTES="$PROJECT_ROOT/$BACKEND_DIR/routes/api.php"
    if [ -f "$API_ROUTES" ]; then
      echo "routes/api.php:" >> "$OUTPUT"
      grep -nE "Route::(get|post|put|patch|delete)" "$API_ROUTES" 2>/dev/null | while read -r line; do
        method=$(echo "$line" | sed -E 's/.*Route::(get|post|put|patch|delete).*/\1/' | tr '[:lower:]' '[:upper:]')
        path=$(echo "$line" | sed -nE "s/.*Route::[a-z]+\([[:space:]]*['\"]([^'\"]*)['\"].*/\1/p")
        echo "  ${method} ${path}" >> "$OUTPUT"
      done
      echo "" >> "$OUTPUT"
      echo -e "  ${GREEN}Found Laravel routes${NC}"
    else
      echo "(No Laravel routes found)" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
    fi
    ;;
  *)
    # Fallback: look for route files, handlers, or entry points
    ROUTE_FILES=$(find "$PROJECT_ROOT/$BACKEND_DIR" \( -name "*.route.*" -o -name "*.routes.*" -o -name "router.*" -o -name "handler.*" -o -name "urls.py" \) 2>/dev/null | head -20)
    if [ -n "$ROUTE_FILES" ]; then
      echo "$ROUTE_FILES" | while read -r file; do
        echo "- $(echo "$file" | sed "s|$PROJECT_ROOT/||")" >> "$OUTPUT"
      done
    else
      echo "(No controllers or route files found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
esac

# ─── 4. Pages ───
echo -e "${YELLOW}[4/6] Extracting pages...${NC}"
echo "## Pages" >> "$OUTPUT"

case "$FE_FW" in
  nextjs)
    if [ -d "$PAGES_DIR" ]; then
      find "$PAGES_DIR" -name "page.tsx" -o -name "page.jsx" | sort | while read -r file; do
        route=$(echo "$file" | sed "s|$PAGES_DIR||;s|/page\.\(tsx\|jsx\)||")
        [ -z "$route" ] && route="/"
        api_calls=$(grep -oP "(api\w+|apiClient)\.\w+" "$file" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
        if [ -n "$api_calls" ]; then
          echo "${route} → ${api_calls}" >> "$OUTPUT"
        else
          echo "${route}" >> "$OUTPUT"
        fi
      done
      echo "" >> "$OUTPUT"
      PAGE_COUNT=$(find "$PAGES_DIR" \( -name "page.tsx" -o -name "page.jsx" \) | wc -l | tr -d ' ')
      echo -e "  ${GREEN}Found $PAGE_COUNT pages${NC}"
    else
      echo "(No Next.js pages directory found)" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
    fi
    ;;
  react)
    # Look for React Router routes
    ROUTER_FILES=$(grep -rl '<Route\|createBrowserRouter\|createRoutesFromElements' --include="*.tsx" --include="*.jsx" --include="*.ts" "$PROJECT_ROOT/$FRONTEND_DIR/src/" 2>/dev/null | head -5)
    if [ -n "$ROUTER_FILES" ]; then
      echo "$ROUTER_FILES" | while read -r file; do
        rel=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
        echo "Routes in $rel:" >> "$OUTPUT"
        grep -oE "path=['\"]([^'\"]*)['\"]" "$file" 2>/dev/null | sed "s/path=['\"]//;s/['\"]$//" | while read -r path; do
          echo "  ${path}" >> "$OUTPUT"
        done
      done
    else
      echo "(No React Router routes found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  vue)
    ROUTER_FILE=$(find "$PROJECT_ROOT/$FRONTEND_DIR/src" -name "router.ts" -o -name "router.js" -o -name "index.ts" -path "*/router/*" 2>/dev/null | head -1)
    if [ -n "$ROUTER_FILE" ]; then
      echo "Vue Router:" >> "$OUTPUT"
      grep -oE "path:\s*['\"]([^'\"]*)['\"]" "$ROUTER_FILE" 2>/dev/null | sed "s/path:\s*['\"]//;s/['\"]$//" | while read -r path; do
        echo "  ${path}" >> "$OUTPUT"
      done
    else
      echo "(No Vue Router config found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  svelte)
    SVELTE_PAGES=$(find "$PROJECT_ROOT/$FRONTEND_DIR/src/routes" -name "+page.svelte" 2>/dev/null | sort)
    if [ -n "$SVELTE_PAGES" ]; then
      echo "$SVELTE_PAGES" | while read -r file; do
        route=$(echo "$file" | sed "s|$PROJECT_ROOT/$FRONTEND_DIR/src/routes||;s|/+page\.svelte||")
        [ -z "$route" ] && route="/"
        echo "${route}" >> "$OUTPUT"
      done
    else
      echo "(No SvelteKit pages found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  angular)
    ROUTING_FILES=$(find "$PROJECT_ROOT/$FRONTEND_DIR/src" -name "*-routing.module.ts" -o -name "*.routes.ts" 2>/dev/null | head -5)
    if [ -n "$ROUTING_FILES" ]; then
      echo "Angular Routes:" >> "$OUTPUT"
      echo "$ROUTING_FILES" | while read -r file; do
        grep -oE "path:\s*['\"]([^'\"]*)['\"]" "$file" 2>/dev/null | sed "s/path:\s*['\"]//;s/['\"]$//" | while read -r path; do
          echo "  ${path}" >> "$OUTPUT"
        done
      done
    else
      echo "(No Angular routing modules found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
  *)
    # Fallback
    FRONTEND_SRC="$PROJECT_ROOT/$FRONTEND_DIR/src"
    if [ -d "$FRONTEND_SRC" ]; then
      COMP_FILES=$(find "$FRONTEND_SRC" \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" -o -name "*.svelte" \) -not -path "*/node_modules/*" 2>/dev/null | head -20)
      if [ -n "$COMP_FILES" ]; then
        echo "$COMP_FILES" | while read -r file; do
          echo "- $(echo "$file" | sed "s|$PROJECT_ROOT/||")" >> "$OUTPUT"
        done
      else
        echo "(No page files found)" >> "$OUTPUT"
      fi
    else
      echo "(Frontend src directory not found)" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
    ;;
esac

# ─── 5. Components & API Client Files ───
echo -e "${YELLOW}[5/6] Extracting components and API client files...${NC}"

echo "## Reusable Components" >> "$OUTPUT"
if [ -d "$COMPONENTS_DIR" ]; then
  for dir in "$COMPONENTS_DIR"/*/; do
    category=$(basename "$dir")
    files=$(ls "$dir"*.tsx "$dir"*.vue "$dir"*.svelte "$dir"*.jsx 2>/dev/null | xargs -I{} basename {} | sed 's/\.\(tsx\|jsx\|vue\|svelte\)$//' | tr '\n' ',' | sed 's/,$//')
    if [ -n "$files" ]; then
      echo "${category}: ${files}" >> "$OUTPUT"
    fi
  done
  echo "" >> "$OUTPUT"
fi

echo "## API Client Files" >> "$OUTPUT"
if [ -d "$API_CLIENT_DIR" ]; then
  files=$(ls "$API_CLIENT_DIR"/*.ts "$API_CLIENT_DIR"/*.js 2>/dev/null | xargs -I{} basename {} | sed 's/\.\(ts\|js\)$//' | tr '\n' ',' | sed 's/,$//')
  echo "Files: ${files}" >> "$OUTPUT"
  echo "Path: ${API_CLIENT_REL}/[name]" >> "$OUTPUT"
fi

# ─── 6. Files by Directory ───
echo -e "${YELLOW}[6/6] Generating directory overview...${NC}"
echo "" >> "$OUTPUT"
echo "## Files by Directory" >> "$OUTPUT"

# Build file extension filter
FILE_EXT_FILTER=""
case "$LANG" in
  typescript)       FILE_EXT_FILTER='-name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx"' ;;
  javascript)       FILE_EXT_FILTER='-name "*.js" -o -name "*.jsx"' ;;
  python)           FILE_EXT_FILTER='-name "*.py"' ;;
  ruby)             FILE_EXT_FILTER='-name "*.rb"' ;;
  go)               FILE_EXT_FILTER='-name "*.go"' ;;
  java)             FILE_EXT_FILTER='-name "*.java" -o -name "*.kt"' ;;
  php)              FILE_EXT_FILTER='-name "*.php"' ;;
  rust)             FILE_EXT_FILTER='-name "*.rs"' ;;
  *)                FILE_EXT_FILTER='-name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.rb" -o -name "*.go" -o -name "*.java"' ;;
esac

for DIR in "$PROJECT_ROOT/$BACKEND_DIR/src" "$PROJECT_ROOT/$BACKEND_DIR/app" "$PROJECT_ROOT/$FRONTEND_DIR/src"; do
  if [ -d "$DIR" ]; then
    REL_DIR=$(echo "$DIR" | sed "s|$PROJECT_ROOT/||")
    echo "" >> "$OUTPUT"
    echo "### $REL_DIR" >> "$OUTPUT"
    for SUBDIR in "$DIR"/*/; do
      [ -d "$SUBDIR" ] || continue
      SUBNAME=$(basename "$SUBDIR")
      FILE_COUNT=$(eval "find \"$SUBDIR\" \( $FILE_EXT_FILTER \) -not -path '*/node_modules/*' -not -path '*/__pycache__/*' -not -path '*/vendor/*' -not -path '*/target/*'" 2>/dev/null | wc -l | tr -d ' ')
      [ "$FILE_COUNT" -gt 0 ] && echo "- ${SUBNAME}/ ($FILE_COUNT files)" >> "$OUTPUT"
    done
  fi
done
echo "" >> "$OUTPUT"

echo ""
echo -e "${GREEN}Snapshot generated: ${OUTPUT}${NC}"
echo -e "  Models: ${MODEL_COUNT:-0}"
echo -e "  Enums: ${ENUM_COUNT:-0}"
echo -e "  Controllers: ${CTRL_COUNT:-0}"
echo -e "  Pages: ${PAGE_COUNT:-0}"
echo ""
echo -e "${CYAN}Run this after major changes to keep the project map current.${NC}"
