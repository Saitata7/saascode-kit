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

  # Dot-notation aliases used in templates
  export "TMPL_auth.guard_pattern=$GUARD_PATTERN"
  export "TMPL_auth.multi_tenant=${M_auth_multi_tenant:-}"
  export "TMPL_tenancy.enabled=${M_tenancy_enabled:-}"
  export "TMPL_billing.enabled=${M_billing_enabled:-}"
  export "TMPL_ai.enabled=${M_ai_enabled:-}"
  export "TMPL_paths.shared=$SHARED_PATH"
  export "TMPL_billing.webhooks=${M_billing_webhooks:-}"
  export "TMPL_patterns.colors=${M_patterns_colors:-}"
  export "TMPL_stack.backend.framework=$BACKEND_FRAMEWORK"
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
      # Read variable from environment via ENVIRON
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
