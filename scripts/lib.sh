#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — Shared Library
# Common functions used by setup.sh and saascode.sh
# ═══════════════════════════════════════════════════════════

# Colors (use $'...' so escape codes are interpreted at assignment time)
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

# ─── Find project root (walk up until .git found) ───
find_root() {
  local DIR="$PWD"
  while [ "$DIR" != "/" ]; do
    [ -d "$DIR/.git" ] && echo "$DIR" && return
    DIR="$(dirname "$DIR")"
  done
  echo "$PWD"
}

# ─── Read a single manifest key (section.field) ───
# Usage: read_manifest "project.name" "default_value"
read_manifest() {
  local KEY="$1"
  local DEFAULT="$2"
  local MANIFEST=""
  local ROOT="${_LIB_ROOT:-$(find_root)}"

  for CANDIDATE in "$ROOT/saascode-kit/manifest.yaml" "$ROOT/.saascode/manifest.yaml" "$ROOT/manifest.yaml" "$ROOT/saascode-kit.yaml"; do
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

# ─── Parse manifest.yaml into key=value pairs ───
# Flattens nested YAML using awk (no Python dependency)
parse_manifest() {
  local MANIFEST="$1"
  [ -z "$MANIFEST" ] && echo "" && return

  awk '
  /^#/ { next }
  /^[[:space:]]*$/ { next }
  {
    match($0, /^[[:space:]]*/); indent = RLENGTH / 2
    line = $0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]*#.*$/, "", line)
    if (line ~ /^-/) next
    idx = index(line, ":")
    if (idx == 0) next
    key = substr(line, 1, idx - 1)
    val = substr(line, idx + 1); sub(/^[[:space:]]+/, "", val); sub(/[[:space:]]+$/, "", val)
    gsub(/^"/, "", val); gsub(/"$/, "", val)
    path[indent] = key
    for (i = indent + 1; i <= 10; i++) path[i] = ""
    if (val != "" && val !~ /^\|/) {
      fullpath = ""
      for (i = 0; i <= indent; i++) {
        if (path[i] != "") {
          if (fullpath != "") fullpath = fullpath "_"
          fullpath = fullpath path[i]
        }
      }
      gsub(/"/, "\\\"", val)
      print fullpath "=\"" val "\""
    }
  }
  ' "$MANIFEST"
}

# ─── Load manifest variables into friendly names ───
# Sets PROJECT_NAME, BACKEND_PATH, TENANT_IDENTIFIER, etc.
load_manifest_vars() {
  local MANIFEST="$1"
  [ -z "$MANIFEST" ] || [ ! -f "$MANIFEST" ] && return 1

  eval "$(parse_manifest "$MANIFEST" | sed 's/^/M_/')"

  PROJECT_NAME="${M_project_name:-MyApp}"
  PROJECT_DESC="${M_project_description:-}"
  PROJECT_TYPE="${M_project_type:-}"
  PROJECT_DOMAIN="${M_project_domain:-}"
  PROJECT_PORT="${M_project_port:-4000}"
  FRONTEND_FRAMEWORK="${M_stack_frontend_framework:-}"
  FRONTEND_VERSION="${M_stack_frontend_version:-}"
  UI_LIBRARY="${M_stack_frontend_ui_library:-}"
  CSS="${M_stack_frontend_css:-}"
  BACKEND_FRAMEWORK="${M_stack_backend_framework:-}"
  BACKEND_VERSION="${M_stack_backend_version:-}"
  ORM="${M_stack_backend_orm:-}"
  DATABASE="${M_stack_backend_database:-}"
  CACHE="${M_stack_backend_cache:-none}"
  LANGUAGE="${M_stack_language:-typescript}"
  AUTH_PROVIDER="${M_auth_provider:-}"
  GUARD_PATTERN="${M_auth_guard_pattern:-decorator}"
  TENANT_IDENTIFIER="${M_tenancy_identifier:-tenantId}"
  BILLING_PROVIDER="${M_billing_provider:-}"
  BILLING_MODEL="${M_billing_model:-}"
  FRONTEND_PATH="${M_paths_frontend:-apps/portal}"
  BACKEND_PATH="${M_paths_backend:-apps/api}"
  SHARED_PATH="${M_paths_shared:-}"
  SCHEMA_PATH="${M_paths_schema:-$BACKEND_PATH/prisma/schema.prisma}"
  API_CLIENT_PATH="${M_paths_api_client:-$FRONTEND_PATH/src/lib/api}"
  COMPONENTS_PATH="${M_paths_components:-$FRONTEND_PATH/src/components}"
  FRONTEND_HOST="${M_infra_frontend_host:-}"
  BACKEND_HOST="${M_infra_backend_host:-}"
  CI_PROVIDER="${M_infra_ci_provider:-github}"

  # Export template variables for conditional processing (awk ENVIRON)
  export TMPL_auth_guard_pattern="$GUARD_PATTERN"
  export TMPL_auth_multi_tenant="${M_auth_multi_tenant:-}"
  export TMPL_tenancy_enabled="${M_tenancy_enabled:-}"
  export TMPL_billing_enabled="${M_billing_enabled:-}"
  export TMPL_ai_enabled="${M_ai_enabled:-}"
  export TMPL_paths_shared="$SHARED_PATH"
  export TMPL_billing_webhooks="${M_billing_webhooks:-}"
  export TMPL_patterns_colors="${M_patterns_colors:-}"

  # Also export with nested dots replaced by underscores for deeper keys
  export TMPL_stack_backend_framework="$BACKEND_FRAMEWORK"
}

# ═══════════════════════════════════════════════════════════
# Universal Detection Helpers
# Read from manifest vars with auto-detection fallbacks.
# Call load_manifest_vars() before using these.
# ═══════════════════════════════════════════════════════════

# ─── try_cmd: Run command with graceful skip if tool missing ───
try_cmd() {
  local CMD="$1"; shift
  if command -v "$CMD" >/dev/null 2>&1; then
    "$CMD" "$@"
  else
    echo "SKIP: $CMD not found" >&2
    return 127
  fi
}

# ─── detect_pkg_manager: npm/yarn/pnpm/pip/gem/go/mvn/gradle ───
detect_pkg_manager() {
  local DIR="${1:-.}"
  local ROOT="${_LIB_ROOT:-$(find_root)}"

  # Lockfile detection first (most specific)
  [ -f "$DIR/yarn.lock" ] || [ -f "$ROOT/yarn.lock" ] && echo "yarn" && return
  [ -f "$DIR/pnpm-lock.yaml" ] || [ -f "$ROOT/pnpm-lock.yaml" ] && echo "pnpm" && return
  [ -f "$DIR/package-lock.json" ] || [ -f "$ROOT/package-lock.json" ] && echo "npm" && return
  [ -f "$DIR/Pipfile.lock" ] || [ -f "$DIR/requirements.txt" ] || [ -f "$ROOT/Pipfile.lock" ] || [ -f "$ROOT/requirements.txt" ] && echo "pip" && return
  [ -f "$DIR/Gemfile.lock" ] || [ -f "$ROOT/Gemfile.lock" ] && echo "gem" && return
  [ -f "$DIR/go.sum" ] || [ -f "$ROOT/go.sum" ] && echo "go" && return
  [ -f "$DIR/build.gradle" ] || [ -f "$DIR/build.gradle.kts" ] && echo "gradle" && return
  [ -f "$DIR/pom.xml" ] || [ -f "$ROOT/pom.xml" ] && echo "mvn" && return
  [ -f "$DIR/Cargo.lock" ] || [ -f "$ROOT/Cargo.lock" ] && echo "cargo" && return
  [ -f "$DIR/composer.lock" ] || [ -f "$ROOT/composer.lock" ] && echo "composer" && return

  # Fall back to language from manifest
  case "${LANGUAGE:-}" in
    typescript|javascript) echo "npm" ;;
    python)                echo "pip" ;;
    ruby)                  echo "gem" ;;
    go)                    echo "go" ;;
    java|kotlin)           echo "mvn" ;;
    rust)                  echo "cargo" ;;
    php)                   echo "composer" ;;
    *)                     echo "npm" ;;
  esac
}

# ─── detect_build_cmd: Build command for a path ───
detect_build_cmd() {
  local DIR="${1:-.}"
  local PKG
  PKG="$(detect_pkg_manager "$DIR")"

  case "$PKG" in
    npm)      echo "npm --prefix $DIR run build" ;;
    yarn)     echo "yarn --cwd $DIR build" ;;
    pnpm)     echo "pnpm --dir $DIR run build" ;;
    pip)
      if [ -f "$DIR/setup.py" ] || [ -f "$DIR/pyproject.toml" ]; then
        echo "python -m build --outdir $DIR/dist $DIR"
      else
        echo ""
      fi
      ;;
    go)       echo "go build ./$DIR/..." ;;
    mvn)      echo "mvn -f $DIR/pom.xml package -q" ;;
    gradle)   echo "gradle -p $DIR build" ;;
    cargo)    echo "cargo build --manifest-path $DIR/Cargo.toml" ;;
    gem)      echo "" ;; # Rails doesn't have a build step typically
    composer) echo "" ;;
    *)        echo "" ;;
  esac
}

# ─── detect_test_cmd: Test command for a path ───
detect_test_cmd() {
  local DIR="${1:-.}"
  local PKG
  PKG="$(detect_pkg_manager "$DIR")"

  case "$PKG" in
    npm)      echo "npm --prefix $DIR test" ;;
    yarn)     echo "yarn --cwd $DIR test" ;;
    pnpm)     echo "pnpm --dir $DIR test" ;;
    pip)
      [ -f "$DIR/pytest.ini" ] || [ -f "$DIR/pyproject.toml" ] && echo "pytest $DIR" && return
      echo "python -m pytest $DIR"
      ;;
    go)       echo "go test ./$DIR/..." ;;
    mvn)      echo "mvn -f $DIR/pom.xml test -q" ;;
    gradle)   echo "gradle -p $DIR test" ;;
    cargo)    echo "cargo test --manifest-path $DIR/Cargo.toml" ;;
    gem)      echo "bundle exec rspec" ;;
    composer) echo "php $DIR/vendor/bin/phpunit" ;;
    *)        echo "" ;;
  esac
}

# ─── detect_typecheck_cmd: Type checking (tsc/mypy/go vet) ───
detect_typecheck_cmd() {
  case "${LANGUAGE:-}" in
    typescript)
      local PKG
      PKG="$(detect_pkg_manager)"
      case "$PKG" in
        npm)  echo "npm run typecheck" ;;
        yarn) echo "yarn typecheck" ;;
        pnpm) echo "pnpm typecheck" ;;
        *)    echo "npx tsc --noEmit" ;;
      esac
      ;;
    python)  echo "mypy ." ;;
    go)      echo "go vet ./..." ;;
    java)    echo "" ;; # javac handles this during build
    rust)    echo "cargo check" ;;
    *)       echo "" ;;
  esac
}

# ─── detect_audit_cmd: Security audit command ───
detect_audit_cmd() {
  local PKG
  PKG="$(detect_pkg_manager)"

  case "$PKG" in
    npm)      echo "npm audit --audit-level=critical" ;;
    yarn)     echo "yarn audit --level critical" ;;
    pnpm)     echo "pnpm audit --audit-level critical" ;;
    pip)      command -v pip-audit >/dev/null 2>&1 && echo "pip-audit" && return
              command -v safety >/dev/null 2>&1 && echo "safety check" && return
              echo "" ;;
    gem)      echo "bundle-audit check" ;;
    go)       echo "govulncheck ./..." ;;
    mvn)      echo "mvn org.owasp:dependency-check-maven:check -q" ;;
    gradle)   echo "" ;;
    cargo)    echo "cargo audit" ;;
    composer) echo "composer audit" ;;
    *)        echo "" ;;
  esac
}

# ─── get_source_extensions: File extensions for current language ───
get_source_extensions() {
  case "${LANGUAGE:-typescript}" in
    typescript)       echo 'ts|tsx' ;;
    javascript)       echo 'js|jsx' ;;
    python)           echo 'py' ;;
    ruby)             echo 'rb' ;;
    go)               echo 'go' ;;
    java|kotlin)      echo 'java|kt' ;;
    rust)             echo 'rs' ;;
    php)              echo 'php' ;;
    *)                echo 'ts|tsx|js|jsx' ;;
  esac
}

# ─── get_excluded_dirs: Directories to exclude from searches ───
get_excluded_dirs() {
  local COMMON="node_modules|dist|.git|coverage"
  case "${LANGUAGE:-typescript}" in
    typescript|javascript) echo "${COMMON}|.next|.turbo" ;;
    python)                echo "${COMMON}|__pycache__|venv|.venv|.tox|*.egg-info" ;;
    ruby)                  echo "${COMMON}|vendor/bundle|tmp" ;;
    go)                    echo "${COMMON}|vendor" ;;
    java|kotlin)           echo "${COMMON}|target|build|.gradle" ;;
    rust)                  echo "${COMMON}|target" ;;
    php)                   echo "${COMMON}|vendor" ;;
    *)                     echo "$COMMON" ;;
  esac
}

# ─── log_issue: Append issue to daily JSONL log ───
# Usage: log_issue "source" "severity" "category" "message" ["file"] ["line"] ["detail"]
# severity: critical | warning | info
# source: check-file | full-audit | pre-deploy | pre-commit | pre-push
log_issue() {
  local _ROOT="${_LIB_ROOT:-$(find_root)}"
  local _DIR="$_ROOT/.saascode/logs"
  mkdir -p "$_DIR" 2>/dev/null
  local _FILE="$_DIR/issues-$(date -u +%Y-%m-%d).jsonl"
  jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg source "$1" --arg severity "$2" --arg category "$3" \
    --arg message "$4" --arg file "${5:-}" --arg line "${6:-}" \
    --arg detail "${7:-}" \
    '{ts:$ts,source:$source,severity:$severity,category:$category,message:$message,file:$file,line:$line,detail:$detail}' \
    >> "$_FILE" 2>/dev/null
}

# ─── get_test_file_patterns: Test file glob patterns ───
get_test_file_patterns() {
  case "${LANGUAGE:-typescript}" in
    typescript)       echo '*.test.ts|*.spec.ts|*.test.tsx|*.spec.tsx' ;;
    javascript)       echo '*.test.js|*.spec.js|*.test.jsx|*.spec.jsx' ;;
    python)           echo 'test_*.py|*_test.py' ;;
    ruby)             echo '*_spec.rb|*_test.rb' ;;
    go)               echo '*_test.go' ;;
    java|kotlin)      echo '*Test.java|*Tests.java|*Test.kt' ;;
    rust)             echo '' ;; # Tests are inline in Rust
    php)              echo '*Test.php|*_test.php' ;;
    *)                echo '*.test.*|*.spec.*' ;;
  esac
}

# ─── get_debug_patterns: Debug statement patterns ───
get_debug_patterns() {
  case "${LANGUAGE:-typescript}" in
    typescript|javascript) echo 'console\.log\|console\.debug\|debugger' ;;
    python)                echo 'breakpoint()\|pdb\.set_trace()\|print(' ;;
    ruby)                  echo 'binding\.pry\|byebug\|puts \|pp ' ;;
    go)                    echo 'fmt\.Println\|fmt\.Printf\|log\.Print' ;;
    java|kotlin)           echo 'System\.out\.print\|\.printStackTrace()' ;;
    rust)                  echo 'dbg!\|println!' ;;
    php)                   echo 'var_dump(\|print_r(\|dd(' ;;
    *)                     echo 'console\.log\|debugger' ;;
  esac
}

# ─── get_raw_sql_patterns: ORM-aware SQL injection patterns ───
get_raw_sql_patterns() {
  case "${ORM:-}" in
    prisma)      echo '\$queryRaw\s*`\|\$executeRaw\s*`' ;;
    typeorm)     echo '\.query\s*(\s*`\|\.query\s*(\s*".*+' ;;
    sequelize)   echo '\.query\s*(\s*`\|sequelize\.query\s*(' ;;
    drizzle)     echo 'sql\.raw\s*`' ;;
    mongoose)    echo '\$where.*function' ;;
    django)      echo 'cursor\.execute\s*(\s*f"\|\.raw\s*(\s*f"\|\.extra\s*(' ;;
    sqlalchemy)  echo 'text\s*(\s*f"\|execute\s*(\s*f"\|\.from_statement' ;;
    *)
      # Fallback by language
      case "${LANGUAGE:-}" in
        python)     echo 'cursor\.execute\s*(\s*f"\|\.raw\s*(\s*f"' ;;
        ruby)       echo '\.execute\s*(\s*"\|\.where\s*(\s*".*#{' ;;
        go)         echo 'db\.Query\s*(\s*".*+\|db\.Exec\s*(\s*".*+' ;;
        java)       echo 'Statement\.execute\|\.createQuery\s*(\s*".*+' ;;
        php)        echo '->query\s*(\s*"\|mysql_query\s*(' ;;
        *)          echo '\$queryRaw\s*`\|\$executeRaw\s*`' ;;
      esac
      ;;
  esac
}

# ─── get_migration_check_cmd: Migration status command ───
get_migration_check_cmd() {
  local BE="${BACKEND_PATH:-apps/api}"
  case "${ORM:-}" in
    prisma)      echo "cd $BE && npx prisma migrate status" ;;
    typeorm)     echo "cd $BE && npx typeorm migration:show" ;;
    sequelize)   echo "cd $BE && npx sequelize-cli db:migrate:status" ;;
    drizzle)     echo "cd $BE && npx drizzle-kit check" ;;
    django)      echo "python manage.py showmigrations --plan" ;;
    sqlalchemy)  echo "alembic current" ;;
    mongoose)    echo "" ;; # MongoDB has no migrations typically
    *)           echo "" ;;
  esac
}

# ─── Replace template placeholders ───
replace_placeholders() {
  local FILE="$1"

  # Compute dynamic placeholders
  local GENERATED_DATE
  GENERATED_DATE="$(date +%Y-%m-%d)"
  local SCHEMA_RELATIVE_PATH
  SCHEMA_RELATIVE_PATH="$(echo "$SCHEMA_PATH" | sed "s|^$BACKEND_PATH/||")"

  sed -i.bak \
    -e "s|{{project.name}}|$PROJECT_NAME|g" \
    -e "s|{{project.description}}|$PROJECT_DESC|g" \
    -e "s|{{project.type}}|$PROJECT_TYPE|g" \
    -e "s|{{project.domain}}|$PROJECT_DOMAIN|g" \
    -e "s|{{project.port}}|$PROJECT_PORT|g" \
    -e "s|{{stack.frontend.framework}}|$FRONTEND_FRAMEWORK|g" \
    -e "s|{{stack.frontend.version}}|$FRONTEND_VERSION|g" \
    -e "s|{{stack.frontend.ui_library}}|$UI_LIBRARY|g" \
    -e "s|{{stack.frontend.css}}|$CSS|g" \
    -e "s|{{stack.backend.framework}}|$BACKEND_FRAMEWORK|g" \
    -e "s|{{stack.backend.version}}|$BACKEND_VERSION|g" \
    -e "s|{{stack.backend.orm}}|$ORM|g" \
    -e "s|{{stack.backend.database}}|$DATABASE|g" \
    -e "s|{{stack.backend.cache}}|$CACHE|g" \
    -e "s|{{stack.language}}|$LANGUAGE|g" \
    -e "s|{{auth.provider}}|$AUTH_PROVIDER|g" \
    -e "s|{{auth.guard_pattern}}|$GUARD_PATTERN|g" \
    -e "s|{{tenancy.identifier}}|$TENANT_IDENTIFIER|g" \
    -e "s|{{billing.provider}}|$BILLING_PROVIDER|g" \
    -e "s|{{billing.model}}|$BILLING_MODEL|g" \
    -e "s|{{paths.backend}}|$BACKEND_PATH|g" \
    -e "s|{{paths.frontend}}|$FRONTEND_PATH|g" \
    -e "s|{{paths.shared}}|$SHARED_PATH|g" \
    -e "s|{{paths.schema}}|$SCHEMA_PATH|g" \
    -e "s|{{paths.api_client}}|$API_CLIENT_PATH|g" \
    -e "s|{{paths.components}}|$COMPONENTS_PATH|g" \
    -e "s|{{infra.frontend_host}}|$FRONTEND_HOST|g" \
    -e "s|{{infra.backend_host}}|$BACKEND_HOST|g" \
    -e "s|{{generated_date}}|$GENERATED_DATE|g" \
    -e "s|{{schema_relative_path}}|$SCHEMA_RELATIVE_PATH|g" \
    "$FILE"
  rm -f "${FILE}.bak"

  # Process conditional blocks
  process_conditionals "$FILE"
}

# ─── Process template conditional blocks ───
# Handles {{#if VAR}}, {{#if_eq VAR "value"}}, and {{#each VAR}} blocks
process_conditionals() {
  local FILE="$1"
  local TMPFILE="${FILE}.cond_tmp"

  # --- 1. Process {{#if_eq field "value"}}...{{/if_eq}} ---
  # Extract all if_eq blocks and evaluate them
  awk '
  BEGIN { skip=0; depth=0 }
  /\{\{#if_eq / {
    match($0, /\{\{#if_eq ([^ ]+) "([^"]*)"/, arr)
    if (RSTART > 0) {
      var = arr[1]; val = arr[2]
      # Read variable from environment via ENVIRON (dots → underscores)
      gsub(/\./, "_", var)
      actual = ENVIRON["TMPL_" var]
      if (actual == val) {
        # Keep block contents, remove the tag line
        next
      } else {
        skip = 1; depth = 1
        next
      }
    }
  }
  /\{\{\/if_eq\}\}/ {
    if (skip && depth == 1) {
      skip = 0; depth = 0
      next
    }
    if (!skip) next
  }
  skip { next }
  { print }
  ' "$FILE" > "$TMPFILE"
  mv "$TMPFILE" "$FILE"

  # --- 2. Process {{#if field}}...{{/if}} ---
  # Uses simple awk: check if the variable is non-empty and not "false"/"none"
  awk '
  BEGIN { skip=0; depth=0 }
  /\{\{#if [a-zA-Z]/ {
    match($0, /\{\{#if ([a-zA-Z_.]+)/, arr)
    if (RSTART > 0) {
      var = arr[1]
      # Dots → underscores for env var lookup
      gsub(/\./, "_", var)
      actual = ENVIRON["TMPL_" var]
      if (actual != "" && actual != "false" && actual != "none" && actual != "False") {
        next
      } else {
        skip = 1; depth = 1
        next
      }
    }
  }
  /\{\{\/if\}\}/ {
    if (skip && depth == 1) {
      skip = 0; depth = 0
      next
    }
    if (!skip) next
  }
  skip { next }
  { print }
  ' "$FILE" > "$TMPFILE"
  mv "$TMPFILE" "$FILE"

  # --- 3. Remove {{#each ...}}...{{/each}} blocks ---
  # Bash cannot iterate YAML arrays; remove these blocks cleanly
  awk '
  BEGIN { skip=0 }
  /\{\{#each / { skip=1; next }
  /\{\{\/each\}\}/ { skip=0; next }
  skip { next }
  { print }
  ' "$FILE" > "$TMPFILE"
  mv "$TMPFILE" "$FILE"

  # --- 4. Clean up any remaining inline conditionals on single lines ---
  # e.g., {{#if foo}}text{{/if}} on one line
  sed -i.bak \
    -e 's/{{#if [^}]*}}//g' \
    -e 's/{{\/if}}//g' \
    -e 's/{{#if_eq [^}]*}}//g' \
    -e 's/{{\/if_eq}}//g' \
    -e 's/{{#each [^}]*}}//g' \
    -e 's/{{\/each}}//g' \
    -e 's/{{this\.[^}]*}}//g' \
    -e 's/{{this}}//g' \
    "$FILE"
  rm -f "${FILE}.bak"
}

# ─── Find kit directory ───
# Checks: $ROOT/saascode-kit/ (submodule/clone), then falls back to script's own dir
find_kit_dir() {
  local ROOT="${1:-$(find_root)}"

  # Explicit kit dir from environment (set by bin/cli.sh for npx usage)
  if [ -n "$SAASCODE_KIT_DIR" ] && [ -f "$SAASCODE_KIT_DIR/setup.sh" ]; then
    echo "$SAASCODE_KIT_DIR"
    return
  fi

  # Submodule / clone location (check for setup.sh as kit marker)
  if [ -d "$ROOT/saascode-kit" ] && [ -f "$ROOT/saascode-kit/setup.sh" ]; then
    echo "$ROOT/saascode-kit"
    return
  fi

  # Fall back to script's own directory (one level up from scripts/)
  # Only if it looks like a kit dir (has setup.sh)
  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local KIT_CANDIDATE="$(cd "$SCRIPT_DIR/.." && pwd)"
  if [ -f "$KIT_CANDIDATE/setup.sh" ]; then
    echo "$KIT_CANDIDATE"
    return
  fi

  # Last resort — check ROOT/saascode-kit without marker
  echo "$ROOT/saascode-kit"
}
