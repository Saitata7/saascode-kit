#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode CLI — Quick access to all kit commands
#
# Usage:
#   saascode-kit <command> [options]
#
# Also available via shell alias:
#   alias saascode='.saascode/scripts/saascode.sh'
# ═══════════════════════════════════════════════════════════

set -e

# Source shared library
_LIB="$(dirname "$0")/lib.sh"
[ -f "$_LIB" ] || _LIB="$(cd "$(dirname "$0")/../.." && pwd)/saascode-kit/scripts/lib.sh"
source "$_LIB"

ROOT="$(find_root)"
export _LIB_ROOT="$ROOT"
SCRIPTS_DIR="$ROOT/.saascode/scripts"
CHECKLISTS_DIR="$ROOT/.saascode/checklists"
RULES_DIR="$ROOT/.saascode/rules"

# Fallback: if not installed yet, use kit's own directories
if [ -n "$SAASCODE_KIT_DIR" ]; then
  [ ! -d "$SCRIPTS_DIR" ] && SCRIPTS_DIR="$SAASCODE_KIT_DIR/scripts"
  [ ! -d "$CHECKLISTS_DIR" ] && CHECKLISTS_DIR="$SAASCODE_KIT_DIR/checklists"
  [ ! -d "$RULES_DIR" ] && RULES_DIR="$SAASCODE_KIT_DIR/rules"
fi

# ─── Commands ───

cmd_init() {
  local KIT="$ROOT/saascode-kit"
  local DRY_RUN=false
  for arg in "$@"; do
    [ "$arg" = "--dry-run" ] && DRY_RUN=true
  done

  if [ "$DRY_RUN" = true ]; then
    echo -e "${BOLD}Dry Run — Preview of what would be generated:${NC}"
    echo ""
    echo -e "  ${CYAN}IDE Context:${NC}"
    echo "    CLAUDE.md                     (from templates/CLAUDE.md.template)"
    echo "    .cursorrules                  (from templates/cursorrules.template)"
    echo "    .windsurfrules                (from templates/windsurfrules.template)"
    echo "    .cursor/rules/*.mdc           (framework-specific cursor rules)"
    echo ""
    echo -e "  ${CYAN}Skills:${NC}"
    local SKILL_COUNT=0
    if [ -d "$KIT/skills" ]; then
      SKILL_COUNT=$(ls "$KIT/skills/"*.md 2>/dev/null | wc -l | tr -d ' ')
    fi
    echo "    .claude/skills/               ($SKILL_COUNT skills)"
    echo ""
    echo -e "  ${CYAN}Rules:${NC}"
    echo "    .saascode/rules/              (Semgrep security rules)"
    echo ""
    echo -e "  ${CYAN}Hooks:${NC}"
    echo "    .git/hooks/pre-commit         (secrets, .env, debug statements)"
    echo "    .git/hooks/pre-push           (typecheck, build, audit)"
    echo ""
    echo -e "  ${CYAN}CI:${NC}"
    echo "    .github/workflows/saascode.yml (language-aware CI pipeline)"
    echo ""
    echo -e "  ${CYAN}Scripts:${NC}"
    echo "    .saascode/scripts/            (review, audit, parity, etc.)"
    echo ""
    echo -e "${DIM}Run without --dry-run to actually generate files.${NC}"
    return
  fi

  if [ -f "$KIT/setup.sh" ]; then
    bash "$KIT/setup.sh" "$ROOT"
  else
    echo -e "${RED}Error: saascode-kit/setup.sh not found${NC}"
    echo ""
    echo "Make sure the saascode-kit directory is in your project root."
    exit 1
  fi
}

cmd_audit() {
  echo "${BOLD}Running Full Audit...${NC}"
  echo ""
  if [ -f "$SCRIPTS_DIR/full-audit.sh" ]; then
    source "$_LIB"
    local BE=$(read_manifest "paths.backend" "apps/api")
    local FE=$(read_manifest "paths.frontend" "apps/portal")
    bash "$SCRIPTS_DIR/full-audit.sh" "$BE" "$FE"
  else
    echo "${RED}Error: full-audit.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_review() {
  # Route flags to specialized reviewers
  local HAS_AI=false
  local HAS_INTENT=false
  local HAS_REPO=false
  local INTENT_ARGS=()
  local PASS_ARGS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --ai) HAS_AI=true ;;
      --repo) HAS_REPO=true ;;
      --verify-intent) HAS_INTENT=true; shift; INTENT_ARGS+=(--intent "$1") ;;
      --intent-file) HAS_INTENT=true; INTENT_ARGS+=(--intent-file "$2"); shift ;;
      *) PASS_ARGS+=("$1") ;;
    esac
    shift
  done

  if [ "$HAS_REPO" = true ]; then
    if [ -f "$SCRIPTS_DIR/repo-review.sh" ]; then
      bash "$SCRIPTS_DIR/repo-review.sh" "${PASS_ARGS[@]}"
    else
      echo "${RED}Error: repo-review.sh not found at $SCRIPTS_DIR${NC}"
      exit 1
    fi
    return
  fi

  if [ "$HAS_INTENT" = true ]; then
    if [ -f "$SCRIPTS_DIR/verify-intent.sh" ]; then
      bash "$SCRIPTS_DIR/verify-intent.sh" "${INTENT_ARGS[@]}"
    else
      echo "${RED}Error: verify-intent.sh not found at $SCRIPTS_DIR${NC}"
      exit 1
    fi
    return
  fi

  if [ "$HAS_AI" = true ]; then
    if [ -f "$SCRIPTS_DIR/ai-review.sh" ]; then
      bash "$SCRIPTS_DIR/ai-review.sh" "${PASS_ARGS[@]}"
    else
      echo "${RED}Error: ai-review.sh not found at $SCRIPTS_DIR${NC}"
      exit 1
    fi
    return
  fi

  # Default: AST review
  if [ -f "$SCRIPTS_DIR/ast-review.sh" ]; then
    bash "$SCRIPTS_DIR/ast-review.sh" "${PASS_ARGS[@]}"
  else
    echo "${RED}Error: ast-review.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_parity() {
  echo "${BOLD}Checking Endpoint Parity...${NC}"
  echo ""
  if [ -f "$SCRIPTS_DIR/endpoint-parity.sh" ]; then
    bash "$SCRIPTS_DIR/endpoint-parity.sh"
  else
    echo "${RED}Error: endpoint-parity.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_predeploy() {
  echo "${BOLD}Running Pre-Deploy Checks...${NC}"
  echo ""
  if [ -f "$SCRIPTS_DIR/pre-deploy.sh" ]; then
    source "$_LIB"
    local BE=$(read_manifest "paths.backend" "apps/api")
    local FE=$(read_manifest "paths.frontend" "apps/portal")
    bash "$SCRIPTS_DIR/pre-deploy.sh" "$BE" "$FE"
  else
    echo "${RED}Error: pre-deploy.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_verify() {
  echo "${BOLD}Verifying Development Environment...${NC}"
  echo ""
  if [ -f "$SCRIPTS_DIR/verify-setup.sh" ]; then
    bash "$SCRIPTS_DIR/verify-setup.sh"
  else
    # Inline basic verify
    source "$_LIB"
    local LANG=$(read_manifest "stack.language" "typescript")
    local DB=$(read_manifest "stack.backend.database" "")

    echo "Checking environment..."
    echo "  Stack: $LANG"
    echo ""

    # Language runtime & package manager
    case "$LANG" in
      typescript|javascript)
        node -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Node.js $(node -v)" || echo "  ${RED}✗${NC} Node.js not installed"
        if [ -f "$ROOT/pnpm-lock.yaml" ]; then
          pnpm -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} pnpm $(pnpm -v)" || echo "  ${RED}✗${NC} pnpm not installed"
        elif [ -f "$ROOT/yarn.lock" ]; then
          yarn -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} yarn $(yarn -v)" || echo "  ${RED}✗${NC} yarn not installed"
        else
          npm -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} npm $(npm -v)" || echo "  ${RED}✗${NC} npm not installed"
        fi
        [ -d "$ROOT/node_modules" ] && echo "  ${GREEN}✓${NC} Dependencies installed" || echo "  ${RED}✗${NC} Run: npm install"
        ;;
      python)
        python3 --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Python $(python3 --version 2>&1 | awk '{print $2}')" || echo "  ${RED}✗${NC} Python3 not installed"
        pip3 --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} pip $(pip3 --version 2>&1 | awk '{print $2}')" || echo "  ${RED}✗${NC} pip not installed"
        if [ -f "$ROOT/Pipfile" ]; then
          pipenv --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} pipenv installed" || echo "  ${YELLOW}—${NC} pipenv not installed (Pipfile found)"
        elif [ -f "$ROOT/poetry.lock" ]; then
          poetry --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} poetry installed" || echo "  ${YELLOW}—${NC} poetry not installed (poetry.lock found)"
        fi
        [ -d "$ROOT/venv" ] || [ -d "$ROOT/.venv" ] && echo "  ${GREEN}✓${NC} Virtual environment found" || echo "  ${YELLOW}—${NC} No venv found"
        ;;
      go)
        go version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Go $(go version 2>&1 | awk '{print $3}')" || echo "  ${RED}✗${NC} Go not installed"
        [ -f "$ROOT/go.mod" ] && echo "  ${GREEN}✓${NC} go.mod found" || echo "  ${YELLOW}—${NC} No go.mod"
        ;;
      java)
        java -version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Java $(java -version 2>&1 | head -1 | awk -F'\"' '{print $2}')" || echo "  ${RED}✗${NC} JDK not installed"
        if [ -f "$ROOT/pom.xml" ] || find "$ROOT" -maxdepth 2 -name "pom.xml" -print -quit 2>/dev/null | grep -q .; then
          mvn -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Maven $(mvn -v 2>&1 | head -1 | awk '{print $3}')" || echo "  ${RED}✗${NC} Maven not installed (pom.xml found)"
        elif [ -f "$ROOT/build.gradle" ] || [ -f "$ROOT/build.gradle.kts" ]; then
          gradle -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Gradle installed" || echo "  ${RED}✗${NC} Gradle not installed (build.gradle found)"
        fi
        ;;
      ruby)
        ruby -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Ruby $(ruby -v 2>&1 | awk '{print $2}')" || echo "  ${RED}✗${NC} Ruby not installed"
        bundle -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Bundler $(bundle -v 2>&1 | awk '{print $3}')" || echo "  ${RED}✗${NC} Bundler not installed"
        [ -f "$ROOT/Gemfile.lock" ] && echo "  ${GREEN}✓${NC} Gems locked" || echo "  ${YELLOW}—${NC} No Gemfile.lock"
        ;;
      rust)
        rustc --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Rust $(rustc --version 2>&1 | awk '{print $2}')" || echo "  ${RED}✗${NC} Rust not installed"
        cargo --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Cargo $(cargo --version 2>&1 | awk '{print $2}')" || echo "  ${RED}✗${NC} Cargo not installed"
        [ -f "$ROOT/Cargo.lock" ] && echo "  ${GREEN}✓${NC} Cargo.lock found" || echo "  ${YELLOW}—${NC} No Cargo.lock"
        ;;
      php)
        php -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} PHP $(php -v 2>&1 | head -1 | awk '{print $2}')" || echo "  ${RED}✗${NC} PHP not installed"
        composer --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Composer $(composer --version 2>&1 | awk '{print $3}')" || echo "  ${RED}✗${NC} Composer not installed"
        [ -f "$ROOT/vendor/autoload.php" ] && echo "  ${GREEN}✓${NC} Dependencies installed" || echo "  ${RED}✗${NC} Run: composer install"
        ;;
      *)
        echo "  ${YELLOW}—${NC} Unknown language: $LANG"
        ;;
    esac

    # Database check based on manifest
    case "$DB" in
      postgresql|postgres)
        psql --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} PostgreSQL installed" || echo "  ${RED}✗${NC} PostgreSQL not installed"
        ;;
      mysql)
        mysql --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} MySQL installed" || echo "  ${RED}✗${NC} MySQL not installed"
        ;;
      mongodb)
        mongosh --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} MongoDB installed" || echo "  ${RED}✗${NC} MongoDB not installed"
        ;;
      sqlite)
        sqlite3 --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} SQLite installed" || echo "  ${RED}✗${NC} SQLite not installed"
        ;;
      "")
        echo "  ${YELLOW}—${NC} No database configured in manifest"
        ;;
      *)
        echo "  ${YELLOW}—${NC} Database: $DB (manual verification needed)"
        ;;
    esac

    [ -f "$ROOT/.env" ] && echo "  ${GREEN}✓${NC} Root .env exists" || echo "  ${YELLOW}—${NC} No root .env"
    git -C "$ROOT" status >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Git repository" || echo "  ${RED}✗${NC} Not a git repo"
    echo ""
  fi
}

cmd_checklist() {
  local NAME="${1:-feature-complete}"
  local FILE="$CHECKLISTS_DIR/${NAME}.md"
  if [ -f "$FILE" ]; then
    echo "${BOLD}Checklist: ${NAME}${NC}"
    echo ""
    cat "$FILE"
  else
    echo "${RED}Checklist not found: ${NAME}${NC}"
    echo ""
    echo "Available checklists:"
    ls "$CHECKLISTS_DIR"/*.md 2>/dev/null | while read f; do
      basename "$f" .md
    done
  fi
}

cmd_rules() {
  echo "${BOLD}Semgrep Rules:${NC}"
  echo ""
  if [ -d "$RULES_DIR" ]; then
    for RULE in "$RULES_DIR"/*.yaml; do
      NAME=$(basename "$RULE" .yaml)
      COUNT=$(grep -c "id:" "$RULE" 2>/dev/null || echo "0")
      echo "  ${GREEN}●${NC} ${NAME} ${DIM}(${COUNT} rules)${NC}"
    done
    echo ""
    echo "${DIM}Run with Semgrep: semgrep --config $RULES_DIR${NC}"
  else
    echo "${RED}No rules found at $RULES_DIR${NC}"
  fi
}

cmd_skills() {
  echo "${BOLD}Claude Code Skills:${NC}"
  echo ""
  local SKILLS_DIR="$ROOT/.claude/skills"
  if [ -d "$SKILLS_DIR" ]; then
    for SKILL in "$SKILLS_DIR"/*.md; do
      NAME=$(basename "$SKILL" .md)
      TRIGGER=$(grep "Trigger:" "$SKILL" 2>/dev/null | head -1 | sed 's/.*Trigger: //')
      PURPOSE=$(grep "Purpose:" "$SKILL" 2>/dev/null | head -1 | sed 's/.*Purpose: //')
      printf "  ${CYAN}%-12s${NC} %s\n" "/$NAME" "$PURPOSE"
    done
  else
    echo "  ${YELLOW}No skills installed. Run setup.sh first.${NC}"
  fi
}

cmd_update() {
  echo "${BOLD}Updating SaasCode Kit...${NC}"
  echo ""
  local KIT="$ROOT/saascode-kit"
  local UPDATED=0

  # Version check
  if [ -f "$KIT/package.json" ]; then
    local LOCAL_VER
    LOCAL_VER=$(grep '"version"' "$KIT/package.json" 2>/dev/null | head -1 | sed 's/.*: *"//; s/".*//')
    local LATEST_VER
    LATEST_VER=$(npm view saascode-kit version 2>/dev/null || echo "")
    if [ -n "$LATEST_VER" ] && [ "$LOCAL_VER" != "$LATEST_VER" ]; then
      echo -e "  ${YELLOW}!${NC} Local version: $LOCAL_VER, Latest: $LATEST_VER"
      echo -e "  ${DIM}Run: npm update saascode-kit${NC}"
      echo ""
    elif [ -n "$LATEST_VER" ]; then
      echo -e "  ${GREEN}✓${NC} Kit is up to date (v$LOCAL_VER)"
      echo ""
    fi
  fi

  # Skills → .claude/skills/
  if [ -d "$KIT/skills" ]; then
    mkdir -p "$ROOT/.claude/skills"
    for f in "$KIT"/skills/*.md; do
      cp "$f" "$ROOT/.claude/skills/$(basename "$f")"
      UPDATED=$((UPDATED + 1))
    done
    echo "  ${GREEN}✓${NC} Skills: $(ls "$KIT"/skills/*.md 2>/dev/null | wc -l | tr -d ' ') files → .claude/skills/"
  fi

  # Rules → .saascode/rules/
  if [ -d "$KIT/rules" ]; then
    mkdir -p "$ROOT/.saascode/rules"
    for f in "$KIT"/rules/*.yaml; do
      cp "$f" "$ROOT/.saascode/rules/$(basename "$f")"
      UPDATED=$((UPDATED + 1))
    done
    echo "  ${GREEN}✓${NC} Rules: $(ls "$KIT"/rules/*.yaml 2>/dev/null | wc -l | tr -d ' ') files → .saascode/rules/"
  fi

  # Cursor rules → .cursor/rules/ (conditional by manifest)
  if [ -d "$ROOT/.cursor" ] && [ -d "$KIT/cursor-rules" ]; then
    mkdir -p "$ROOT/.cursor/rules"
    local AI_ENABLED
    AI_ENABLED=$(read_manifest "ai.enabled" "false")

    for f in "$KIT"/cursor-rules/*.mdc; do
      local RULE_NAME
      RULE_NAME=$(basename "$f")

      # Skip ai-security.mdc if ai.enabled is not true
      if [ "$RULE_NAME" = "ai-security.mdc" ] && [ "$AI_ENABLED" != "true" ]; then
        # Remove if previously installed
        [ -f "$ROOT/.cursor/rules/ai-security.mdc" ] && rm "$ROOT/.cursor/rules/ai-security.mdc"
        echo "  ${YELLOW}—${NC} .cursor/rules/ai-security.mdc (skipped — ai.enabled=false)"
        continue
      fi

      cp "$f" "$ROOT/.cursor/rules/$RULE_NAME"
      UPDATED=$((UPDATED + 1))
    done
    echo "  ${GREEN}✓${NC} Cursor rules → .cursor/rules/"
  fi

  # Scripts → .saascode/scripts/ (both .sh and .ts)
  if [ -d "$KIT/scripts" ]; then
    mkdir -p "$ROOT/.saascode/scripts"
    for f in "$KIT"/scripts/*.sh; do
      cp "$f" "$ROOT/.saascode/scripts/$(basename "$f")"
      chmod +x "$ROOT/.saascode/scripts/$(basename "$f")"
      UPDATED=$((UPDATED + 1))
    done
    for f in "$KIT"/scripts/*.ts; do
      [ -f "$f" ] || continue
      cp "$f" "$ROOT/.saascode/scripts/$(basename "$f")"
      UPDATED=$((UPDATED + 1))
    done
    for f in "$KIT"/scripts/*.py; do
      [ -f "$f" ] || continue
      cp "$f" "$ROOT/.saascode/scripts/$(basename "$f")"
      UPDATED=$((UPDATED + 1))
    done
    echo "  ${GREEN}✓${NC} Scripts: $(ls "$KIT"/scripts/*.sh "$KIT"/scripts/*.ts "$KIT"/scripts/*.py 2>/dev/null | wc -l | tr -d ' ') files → .saascode/scripts/"
  fi

  # Checklists → .saascode/checklists/
  if [ -d "$KIT/checklists" ]; then
    mkdir -p "$ROOT/.saascode/checklists"
    for f in "$KIT"/checklists/*.md; do
      cp "$f" "$ROOT/.saascode/checklists/$(basename "$f")"
      UPDATED=$((UPDATED + 1))
    done
    echo "  ${GREEN}✓${NC} Checklists: $(ls "$KIT"/checklists/*.md 2>/dev/null | wc -l | tr -d ' ') files → .saascode/checklists/"
  fi

  # Hooks → .git/hooks/
  if [ -d "$ROOT/.git/hooks" ] && [ -d "$KIT/hooks" ]; then
    for f in "$KIT"/hooks/*; do
      cp "$f" "$ROOT/.git/hooks/$(basename "$f")"
      chmod +x "$ROOT/.git/hooks/$(basename "$f")"
      UPDATED=$((UPDATED + 1))
    done
    echo "  ${GREEN}✓${NC} Hooks: $(ls "$KIT"/hooks/* 2>/dev/null | wc -l | tr -d ' ') files → .git/hooks/"
  fi

  # CI → .github/workflows/
  if [ -d "$ROOT/.github/workflows" ] && [ -f "$KIT/ci/github-action.yml" ]; then
    cp "$KIT/ci/github-action.yml" "$ROOT/.github/workflows/saascode.yml"
    UPDATED=$((UPDATED + 1))
    echo "  ${GREEN}✓${NC} CI: github-action.yml → .github/workflows/saascode.yml"
  fi

  # Claude Code hooks → .claude/settings.json
  local SETTINGS="$ROOT/.claude/settings.json"
  mkdir -p "$ROOT/.claude"
  cat > "$SETTINGS" << 'HOOKS_EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path // .tool_input.filePath // empty' | xargs -I{} .saascode/scripts/check-file.sh {}",
            "timeout": 10
          },
          {
            "type": "command",
            "command": ".saascode/scripts/intent-log.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
HOOKS_EOF
  UPDATED=$((UPDATED + 1))
  echo "  ${GREEN}✓${NC} Claude Code hooks → .claude/settings.json"

  echo ""
  echo "  ${GREEN}${BOLD}Updated $UPDATED files.${NC}"
}

cmd_docs_prd() {
  local IDEA="$1"

  local PROJECT_ROOT
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  local PRD_DIR="$PROJECT_ROOT/docs/product"
  local PRD_FILE="$PRD_DIR/product-brief.md"

  if [ -f "$PRD_FILE" ]; then
    echo ""
    echo "  ${YELLOW}⚠${NC}  Already exists: $PRD_FILE"
    echo "  ${DIM}Delete it first to regenerate.${NC}"
    echo ""
    return
  fi

  mkdir -p "$PRD_DIR"

  if [ -n "$IDEA" ]; then
    cat > "$PRD_FILE" << EOF
# Product Brief

> ${IDEA}

## Structure — generate each section IN ORDER:

1. **Problem & Solution** — Pain points per actor, solution per problem, lifecycle in one line
2. **Entities & Fields** — What things exist? What data do they hold? (camelCase fields, UPPER_SNAKE enums, ? for optional, **bold** for important)
3. **Relationships** — How do they connect? (1:1, 1:many, many:many with context in parentheses)
4. **Domain Rules** — What MUST be true? Grouped by category (constraints, access rules, timing rules)
5. **State Machine** — ASCII diagram + transition table (| From | To | Who | Trigger |) for every status field
6. **Core Flow** — Happy path: 3-column format (Actor | Platform | Actor) with arrows
7. **Build Order** — Implementation sequence respecting dependencies (Auth first, Admin last)

> Replace this file with the generated Product Brief.
EOF
  else
    cat > "$PRD_FILE" << EOF
# Product Brief

> Analyze this project's codebase and generate the Product Brief.

## Structure — generate each section IN ORDER:

1. **Problem & Solution** — What pain does this solve? For whom?
2. **Entities & Fields** — Extract from database schemas (Prisma, TypeORM, SQL, etc.)
3. **Relationships** — Extract from foreign keys and associations
4. **Domain Rules** — Extract from validation logic, guards, middleware
5. **State Machine** — Extract from status/enum fields and transition logic (ASCII diagram + table)
6. **Core Flow** — Extract from route handlers and page navigation (3-column format)
7. **Build Order** — Dependency order for implementation

> Replace this file with the generated Product Brief.
EOF
  fi

  echo ""
  echo "  ${GREEN}✓${NC} $PRD_FILE"
  [ -n "$IDEA" ] && echo "  ${CYAN}Idea:${NC} ${IDEA}"
  echo ""
}

cmd_docs() {
  local MODE="simple"
  local HAS_DIAGRAMS=false
  local HAS_PRD=false
  local PRD_IDEA=""
  for arg in "$@"; do
    case "$arg" in
      --simple)   MODE="simple" ;;
      --full)     MODE="full" ;;
      --diagrams) HAS_DIAGRAMS=true ;;
      --prd)      HAS_PRD=true ;;
      *)          [ "$HAS_PRD" = true ] && [ -z "$PRD_IDEA" ] && PRD_IDEA="$arg" ;;
    esac
  done

  # ── PRD mode: generate product brief ──
  if [ "$HAS_PRD" = true ]; then
    cmd_docs_prd "$PRD_IDEA"
    return
  fi

  local PROJECT_ROOT
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  local CONTEXT_DIR="$PROJECT_ROOT/.claude/context"
  mkdir -p "$CONTEXT_DIR"

  if [ "$MODE" = "simple" ]; then
    # ── Simple mode: lightweight directory tree + key file listing ──
    echo "${BOLD}Generating Simple Project Docs...${NC}"
    echo ""

    local OUTPUT="$CONTEXT_DIR/project-overview.md"
    source "$_LIB"
    local PROJECT_NAME=$(read_manifest "project.name" "Project")
    local BE=$(read_manifest "paths.backend" "apps/api")
    local FE=$(read_manifest "paths.frontend" "apps/portal")

    cat > "$OUTPUT" << EOF
# ${PROJECT_NAME} — Project Overview (auto-generated)

EOF

    # Directory structure (depth 3)
    echo "## Directory Structure" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    if command -v tree >/dev/null 2>&1; then
      tree -L 3 -I 'node_modules|.git|dist|.next|.turbo|coverage' --dirsfirst "$PROJECT_ROOT" >> "$OUTPUT" 2>/dev/null
    else
      # Fallback without tree
      find "$PROJECT_ROOT" -maxdepth 3 \
        -not -path '*/node_modules/*' \
        -not -path '*/.git/*' \
        -not -path '*/dist/*' \
        -not -path '*/.next/*' \
        -not -path '*/.turbo/*' \
        -not -path '*/coverage/*' \
        -type d 2>/dev/null | sed "s|$PROJECT_ROOT|.|" | sort >> "$OUTPUT"
    fi
    echo '```' >> "$OUTPUT"
    echo "" >> "$OUTPUT"

    # Key files
    echo "## Key Files" >> "$OUTPUT"
    for f in package.json tsconfig.json .env.example saascode-kit.yaml CLAUDE.md .cursorrules; do
      [ -f "$PROJECT_ROOT/$f" ] && echo "- $f" >> "$OUTPUT"
    done
    echo "" >> "$OUTPUT"

    # Stack summary from manifest
    local LANG=$(read_manifest "stack.language" "")
    local BF=$(read_manifest "stack.backend.framework" "")
    local FF=$(read_manifest "stack.frontend.framework" "")
    local DB=$(read_manifest "stack.backend.database" "")

    if [ -n "$BF" ] || [ -n "$FF" ]; then
      echo "## Stack" >> "$OUTPUT"
      [ -n "$LANG" ] && echo "- Language: $LANG" >> "$OUTPUT"
      [ -n "$BF" ] && echo "- Backend: $BF" >> "$OUTPUT"
      [ -n "$FF" ] && echo "- Frontend: $FF" >> "$OUTPUT"
      [ -n "$DB" ] && echo "- Database: $DB" >> "$OUTPUT"
      echo "" >> "$OUTPUT"
    fi

    echo -e "  ${GREEN}✓${NC} Project overview generated: $OUTPUT"
    echo ""

  else
    # ── Full mode: run snapshot.sh for detailed project map ──
    echo "${BOLD}Generating Full Project Documentation...${NC}"
    echo ""

    if [ -f "$SCRIPTS_DIR/snapshot.sh" ]; then
      bash "$SCRIPTS_DIR/snapshot.sh"
    else
      echo "${RED}Error: snapshot.sh not found at $SCRIPTS_DIR${NC}"
      exit 1
    fi
  fi

  # Optionally generate Mermaid diagrams (works with both modes)
  if [ "$HAS_DIAGRAMS" = true ]; then
    echo ""
    echo "${BOLD}Generating Mermaid diagrams...${NC}"
    echo ""

    local DIAGRAMS_FILE="$CONTEXT_DIR/diagrams.md"

    source "$_LIB"
    local BE=$(read_manifest "paths.backend" "apps/api")

    cat > "$DIAGRAMS_FILE" << 'DIAG_HEADER'
# Architecture Diagrams (auto-generated)

DIAG_HEADER

    # Entity-relationship diagram from schema
    local SCHEMA_PATH
    SCHEMA_PATH=$(read_manifest "paths.schema" "$BE/prisma/schema.prisma")
    local SCHEMA="$PROJECT_ROOT/$SCHEMA_PATH"

    if [ -f "$SCHEMA" ]; then
      echo '## Entity Relationship' >> "$DIAGRAMS_FILE"
      echo '```mermaid' >> "$DIAGRAMS_FILE"
      echo 'erDiagram' >> "$DIAGRAMS_FILE"
      awk '
        /^model / { model=$2 }
        model && /^\s+\w/ {
          if ($0 ~ /@@/ || $0 ~ /^\s+\/\//) next
          field=$1; type=$2
          if (field ~ /^@@/) next
          gsub(/\?/, "", type); gsub(/\[\]/, "", type)
          # Detect relations
          if (type ~ /^[A-Z]/) {
            printf "  %s ||--o{ %s : has\n", model, type
          }
        }
        /^}/ { model="" }
      ' "$SCHEMA" | sort -u >> "$DIAGRAMS_FILE"
      echo '```' >> "$DIAGRAMS_FILE"
      echo "" >> "$DIAGRAMS_FILE"
      echo -e "  ${GREEN}✓${NC} ER diagram generated"
    fi

    # High-level architecture diagram
    echo '## System Architecture' >> "$DIAGRAMS_FILE"
    echo '```mermaid' >> "$DIAGRAMS_FILE"
    echo 'graph TD' >> "$DIAGRAMS_FILE"
    echo '  Client[Browser/Client] --> Frontend[Frontend]' >> "$DIAGRAMS_FILE"
    echo '  Frontend --> API[Backend API]' >> "$DIAGRAMS_FILE"
    echo '  API --> DB[(Database)]' >> "$DIAGRAMS_FILE"

    local AUTH_PROVIDER
    AUTH_PROVIDER=$(read_manifest "auth.provider" "")
    [ -n "$AUTH_PROVIDER" ] && echo "  API --> Auth[$AUTH_PROVIDER]" >> "$DIAGRAMS_FILE"

    local CACHE
    CACHE=$(read_manifest "stack.backend.cache" "")
    [ -n "$CACHE" ] && [ "$CACHE" != "none" ] && echo "  API --> Cache[$CACHE]" >> "$DIAGRAMS_FILE"

    echo '```' >> "$DIAGRAMS_FILE"
    echo "" >> "$DIAGRAMS_FILE"

    echo -e "  ${GREEN}✓${NC} Architecture diagram generated"
    echo ""
    echo -e "${GREEN}Diagrams written to: $DIAGRAMS_FILE${NC}"
  fi
}

cmd_snapshot() {
  echo "${BOLD}Generating Project Snapshot...${NC}"
  echo ""
  if [ -f "$SCRIPTS_DIR/snapshot.sh" ]; then
    bash "$SCRIPTS_DIR/snapshot.sh"
  else
    echo "${RED}Error: snapshot.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_intent() {
  if [ -f "$SCRIPTS_DIR/intent-cli.sh" ]; then
    bash "$SCRIPTS_DIR/intent-cli.sh" "$@"
  else
    echo "${RED}Error: intent-cli.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_report() {
  if [ -f "$SCRIPTS_DIR/report-cli.sh" ]; then
    bash "$SCRIPTS_DIR/report-cli.sh" "$@"
  else
    echo "${RED}Error: report-cli.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_sweep() {
  if [ -f "$SCRIPTS_DIR/sweep-cli.sh" ]; then
    bash "$SCRIPTS_DIR/sweep-cli.sh" "$@"
  else
    echo "${RED}Error: sweep-cli.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_cloak() {
  if [ -f "$SCRIPTS_DIR/cloak-cli.sh" ]; then
    bash "$SCRIPTS_DIR/cloak-cli.sh" cloak "$@"
  else
    echo "${RED}Error: cloak-cli.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_uncloak() {
  if [ -f "$SCRIPTS_DIR/cloak-cli.sh" ]; then
    bash "$SCRIPTS_DIR/cloak-cli.sh" uncloak "$@"
  else
    echo "${RED}Error: cloak-cli.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_check_file() {
  local FILE="${1}"
  if [ -z "$FILE" ]; then
    echo "Usage: saascode-kit check-file <filepath>"
    exit 1
  fi
  bash "$SCRIPTS_DIR/check-file.sh" "$FILE"
}

cmd_doctor() {
  echo -e "${BOLD}SaasCode Kit Doctor${NC}"
  echo "========================================"
  echo ""

  local ISSUES=0
  local PASS=0

  # Check 1: manifest.yaml exists
  local HAS_MANIFEST=false
  for CANDIDATE in "$ROOT/saascode-kit/manifest.yaml" "$ROOT/.saascode/manifest.yaml" "$ROOT/manifest.yaml" "$ROOT/saascode-kit.yaml"; do
    [ -f "$CANDIDATE" ] && HAS_MANIFEST=true && break
  done
  if [ "$HAS_MANIFEST" = true ]; then
    echo -e "  ${GREEN}✓${NC} manifest.yaml found"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} manifest.yaml not found"
    echo -e "    ${DIM}Fix: cp saascode-kit/manifest.example.yaml saascode-kit/manifest.yaml${NC}"
    ISSUES=$((ISSUES + 1))
  fi

  # Check 2: CLAUDE.md exists
  if [ -f "$ROOT/CLAUDE.md" ]; then
    echo -e "  ${GREEN}✓${NC} CLAUDE.md found"
    PASS=$((PASS + 1))
  else
    echo -e "  ${YELLOW}!${NC} CLAUDE.md not found (run: saascode init or saascode claude)"
    ISSUES=$((ISSUES + 1))
  fi

  # Check 3: Git hooks installed
  if [ -f "$ROOT/.git/hooks/pre-commit" ]; then
    echo -e "  ${GREEN}✓${NC} pre-commit hook installed"
    PASS=$((PASS + 1))
  else
    echo -e "  ${YELLOW}!${NC} pre-commit hook not installed (run: saascode init)"
    ISSUES=$((ISSUES + 1))
  fi

  # Check 4: Scripts directory exists
  if [ -d "$SCRIPTS_DIR" ] && [ -f "$SCRIPTS_DIR/check-file.sh" ]; then
    echo -e "  ${GREEN}✓${NC} Scripts installed ($SCRIPTS_DIR)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} Scripts not found at $SCRIPTS_DIR"
    echo -e "    ${DIM}Fix: saascode init${NC}"
    ISSUES=$((ISSUES + 1))
  fi

  # Check 5: Node.js available (for TS review)
  if command -v node &>/dev/null; then
    local NODE_VER
    NODE_VER=$(node --version 2>/dev/null)
    echo -e "  ${GREEN}✓${NC} Node.js $NODE_VER"
    PASS=$((PASS + 1))
  else
    echo -e "  ${YELLOW}!${NC} Node.js not found (needed for TypeScript AST review)"
    ISSUES=$((ISSUES + 1))
  fi

  # Check 6: Python available (for Python review)
  if command -v python3 &>/dev/null; then
    local PY_VER
    PY_VER=$(python3 --version 2>/dev/null)
    echo -e "  ${GREEN}✓${NC} $PY_VER"
    PASS=$((PASS + 1))
  else
    echo -e "  ${DIM}-${NC} Python not found (optional — needed for Python AST review)"
  fi

  # Check 7: Git repo
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Git repository"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} Not a git repository"
    ISSUES=$((ISSUES + 1))
  fi

  # Check 8: Semgrep rules installed
  local RULE_COUNT=0
  if [ -d "$RULES_DIR" ]; then
    RULE_COUNT=$(ls "$RULES_DIR"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ "$RULE_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} $RULE_COUNT Semgrep rule files"
    PASS=$((PASS + 1))
  else
    echo -e "  ${YELLOW}!${NC} No Semgrep rules installed (run: saascode init)"
    ISSUES=$((ISSUES + 1))
  fi

  # Check 9: IDE configs
  local IDE_COUNT=0
  [ -f "$ROOT/CLAUDE.md" ] && IDE_COUNT=$((IDE_COUNT + 1))
  [ -f "$ROOT/.cursorrules" ] && IDE_COUNT=$((IDE_COUNT + 1))
  [ -f "$ROOT/.windsurfrules" ] && IDE_COUNT=$((IDE_COUNT + 1))
  [ -f "$ROOT/.github/copilot-instructions.md" ] && IDE_COUNT=$((IDE_COUNT + 1))
  [ -d "$ROOT/.agent/rules" ] && IDE_COUNT=$((IDE_COUNT + 1))
  [ -f "$ROOT/CONVENTIONS.md" ] && IDE_COUNT=$((IDE_COUNT + 1))
  echo -e "  ${GREEN}✓${NC} $IDE_COUNT IDE configs detected"

  # Check 10: Kit version
  local KIT_DIR=""
  for CANDIDATE in "$ROOT/saascode-kit" "$ROOT/.saascode"; do
    [ -d "$CANDIDATE" ] && KIT_DIR="$CANDIDATE" && break
  done
  if [ -n "$KIT_DIR" ] && [ -f "$KIT_DIR/package.json" ]; then
    local KIT_VER
    KIT_VER=$(grep '"version"' "$KIT_DIR/package.json" 2>/dev/null | head -1 | sed 's/.*: *"//; s/".*//')
    echo -e "  ${GREEN}✓${NC} Kit version: $KIT_VER"
    PASS=$((PASS + 1))
  fi

  echo ""
  echo "========================================"
  if [ "$ISSUES" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}All checks passed ($PASS/$PASS)${NC}"
  else
    echo -e "  ${YELLOW}${BOLD}$PASS passed, $ISSUES issues found${NC}"
  fi
  echo ""
}

cmd_status() {
  echo "${BOLD}SaasCode Kit Status${NC}"
  echo ""

  # Skills
  local SKILLS_DIR="$ROOT/.claude/skills"
  local SKILL_COUNT=0
  if [ -d "$SKILLS_DIR" ]; then
    SKILL_COUNT=$(ls "$SKILLS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  ${CYAN}Skills:${NC}     $SKILL_COUNT installed"

  # Rules
  local RULE_COUNT=0
  if [ -d "$RULES_DIR" ]; then
    RULE_COUNT=$(ls "$RULES_DIR"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  ${CYAN}Rules:${NC}      $RULE_COUNT Semgrep rule files"

  # Scripts
  local SCRIPT_COUNT=0
  if [ -d "$SCRIPTS_DIR" ]; then
    SCRIPT_COUNT=$(ls "$SCRIPTS_DIR"/*.sh "$SCRIPTS_DIR"/*.ts 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  ${CYAN}Scripts:${NC}    $SCRIPT_COUNT scripts"

  # Checklists
  local CL_COUNT=0
  if [ -d "$CHECKLISTS_DIR" ]; then
    CL_COUNT=$(ls "$CHECKLISTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  ${CYAN}Checklists:${NC} $CL_COUNT checklists"

  # Hooks
  local HOOKS=0
  [ -f "$ROOT/.git/hooks/pre-commit" ] && HOOKS=$((HOOKS + 1))
  [ -f "$ROOT/.git/hooks/pre-push" ] && HOOKS=$((HOOKS + 1))
  echo "  ${CYAN}Git Hooks:${NC}  $HOOKS active"

  # Claude Code hooks
  local CC_HOOKS=0
  if [ -f "$ROOT/.claude/settings.json" ]; then
    CC_HOOKS=$(grep -c '"type": "command"' "$ROOT/.claude/settings.json" 2>/dev/null || echo "0")
  fi
  echo "  ${CYAN}CC Hooks:${NC}   $CC_HOOKS Claude Code hooks"

  # CI
  local CI="None"
  [ -f "$ROOT/.github/workflows/saascode.yml" ] && CI="GitHub Actions"
  echo "  ${CYAN}CI:${NC}         $CI"

  # Cursor rules
  local CURSOR=0
  if [ -d "$ROOT/.cursor/rules" ]; then
    CURSOR=$(ls "$ROOT/.cursor/rules"/*.mdc 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  ${CYAN}Cursor:${NC}     $CURSOR rule files"

  # CLAUDE.md
  [ -f "$ROOT/CLAUDE.md" ] && echo "  ${CYAN}CLAUDE.md:${NC}  Present" || echo "  ${CYAN}CLAUDE.md:${NC}  ${YELLOW}Missing${NC}"
  echo ""
}

# ─── IDE Setup Commands ───

cmd_claude() {
  echo -e "${BOLD}Installing Claude Code config...${NC}"
  echo ""

  local KIT_DIR
  KIT_DIR="$(find_kit_dir "$ROOT")"
  local MANIFEST="$KIT_DIR/manifest.yaml"

  # If manifest not in kit dir, check project root (npx re-installs to fresh dirs)
  if [ ! -f "$MANIFEST" ] && [ -f "$ROOT/saascode-kit.yaml" ]; then
    cp "$ROOT/saascode-kit.yaml" "$MANIFEST"
  fi

  if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: manifest.yaml not found${NC}"
    echo ""
    echo "Run first:  npx saascode-kit init"
    echo "Then edit:  saascode-kit.yaml"
    echo "Then retry: npx saascode-kit claude"
    exit 1
  fi

  load_manifest_vars "$MANIFEST"
  local INSTALLED=0

  # CLAUDE.md from template
  if [ -f "$KIT_DIR/templates/CLAUDE.md.template" ]; then
    cp "$KIT_DIR/templates/CLAUDE.md.template" "$ROOT/CLAUDE.md"
    replace_placeholders "$ROOT/CLAUDE.md"
    echo -e "  ${GREEN}✓${NC} CLAUDE.md"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "  ${RED}✗${NC} templates/CLAUDE.md.template not found"
  fi

  # Skills → .claude/skills/
  if [ -d "$KIT_DIR/skills" ]; then
    mkdir -p "$ROOT/.claude/skills"
    for f in "$KIT_DIR"/skills/*.md; do
      [ -f "$f" ] || continue
      cp "$f" "$ROOT/.claude/skills/$(basename "$f")"
      replace_placeholders "$ROOT/.claude/skills/$(basename "$f")"
      INSTALLED=$((INSTALLED + 1))
    done
    echo -e "  ${GREEN}✓${NC} Skills → .claude/skills/"
  fi

  # Claude Code hooks → .claude/settings.json
  mkdir -p "$ROOT/.claude"
  cat > "$ROOT/.claude/settings.json" << 'HOOKS_EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path // .tool_input.filePath // empty' | xargs -I{} .saascode/scripts/check-file.sh {}",
            "timeout": 10
          },
          {
            "type": "command",
            "command": ".saascode/scripts/intent-log.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
HOOKS_EOF
  echo -e "  ${GREEN}✓${NC} .claude/settings.json (hooks)"
  INSTALLED=$((INSTALLED + 1))

  echo ""
  echo -e "  ${GREEN}${BOLD}Installed $INSTALLED files for Claude Code.${NC}"
}

cmd_cursor() {
  echo -e "${BOLD}Installing Cursor config...${NC}"
  echo ""

  local KIT_DIR
  KIT_DIR="$(find_kit_dir "$ROOT")"
  local MANIFEST="$KIT_DIR/manifest.yaml"

  if [ ! -f "$MANIFEST" ] && [ -f "$ROOT/saascode-kit.yaml" ]; then
    cp "$ROOT/saascode-kit.yaml" "$MANIFEST"
  fi

  if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: manifest.yaml not found${NC}"
    echo "Run first: npx saascode-kit init"
    exit 1
  fi

  load_manifest_vars "$MANIFEST"
  local INSTALLED=0

  # .cursorrules from template
  if [ -f "$KIT_DIR/templates/cursorrules.template" ]; then
    cp "$KIT_DIR/templates/cursorrules.template" "$ROOT/.cursorrules"
    replace_placeholders "$ROOT/.cursorrules"
    echo -e "  ${GREEN}✓${NC} .cursorrules"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "  ${RED}✗${NC} templates/cursorrules.template not found"
  fi

  # Cursor rules → .cursor/rules/
  if [ -d "$KIT_DIR/cursor-rules" ]; then
    mkdir -p "$ROOT/.cursor/rules"
    local AI_ENABLED
    AI_ENABLED=$(read_manifest "ai.enabled" "false")

    for f in "$KIT_DIR"/cursor-rules/*.mdc; do
      [ -f "$f" ] || continue
      local RULE_NAME
      RULE_NAME=$(basename "$f")

      # Skip ai-security.mdc if ai.enabled is not true
      if [ "$RULE_NAME" = "ai-security.mdc" ] && [ "$AI_ENABLED" != "true" ]; then
        [ -f "$ROOT/.cursor/rules/ai-security.mdc" ] && rm "$ROOT/.cursor/rules/ai-security.mdc"
        echo -e "  ${YELLOW}—${NC} .cursor/rules/ai-security.mdc (skipped — ai.enabled=false)"
        continue
      fi

      cp "$f" "$ROOT/.cursor/rules/$RULE_NAME"
      replace_placeholders "$ROOT/.cursor/rules/$RULE_NAME"
      INSTALLED=$((INSTALLED + 1))
    done
    echo -e "  ${GREEN}✓${NC} Cursor rules → .cursor/rules/"
  fi

  echo ""
  echo -e "  ${GREEN}${BOLD}Installed $INSTALLED files for Cursor.${NC}"
}

cmd_windsurf() {
  echo -e "${BOLD}Installing Windsurf config...${NC}"
  echo ""

  local KIT_DIR
  KIT_DIR="$(find_kit_dir "$ROOT")"
  local MANIFEST="$KIT_DIR/manifest.yaml"

  if [ ! -f "$MANIFEST" ] && [ -f "$ROOT/saascode-kit.yaml" ]; then
    cp "$ROOT/saascode-kit.yaml" "$MANIFEST"
  fi

  if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: manifest.yaml not found${NC}"
    echo "Run first: npx saascode-kit init"
    exit 1
  fi

  load_manifest_vars "$MANIFEST"
  local INSTALLED=0

  # .windsurfrules from template
  if [ -f "$KIT_DIR/templates/windsurfrules.template" ]; then
    cp "$KIT_DIR/templates/windsurfrules.template" "$ROOT/.windsurfrules"
    replace_placeholders "$ROOT/.windsurfrules"
    echo -e "  ${GREEN}✓${NC} .windsurfrules"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "  ${RED}✗${NC} templates/windsurfrules.template not found"
  fi

  echo ""
  echo -e "  ${GREEN}${BOLD}Installed $INSTALLED files for Windsurf.${NC}"
}

cmd_antigravity() {
  echo -e "${BOLD}Installing Google Antigravity config...${NC}"
  echo ""

  local KIT_DIR
  KIT_DIR="$(find_kit_dir "$ROOT")"
  local MANIFEST="$KIT_DIR/manifest.yaml"

  if [ ! -f "$MANIFEST" ] && [ -f "$ROOT/saascode-kit.yaml" ]; then
    cp "$ROOT/saascode-kit.yaml" "$MANIFEST"
  fi

  if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: manifest.yaml not found${NC}"
    echo "Run first: npx saascode-kit init"
    exit 1
  fi

  load_manifest_vars "$MANIFEST"
  local INSTALLED=0

  # .agent/rules/ from template
  if [ -f "$KIT_DIR/templates/antigravity-rules.md.template" ]; then
    mkdir -p "$ROOT/.agent/rules"
    cp "$KIT_DIR/templates/antigravity-rules.md.template" "$ROOT/.agent/rules/project-rules.md"
    replace_placeholders "$ROOT/.agent/rules/project-rules.md"
    process_conditionals "$ROOT/.agent/rules/project-rules.md"
    echo -e "  ${GREEN}✓${NC} .agent/rules/project-rules.md"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "  ${RED}✗${NC} templates/antigravity-rules.md.template not found"
  fi

  echo ""
  echo -e "  ${GREEN}${BOLD}Installed $INSTALLED files for Google Antigravity.${NC}"
}

cmd_copilot() {
  echo -e "${BOLD}Installing GitHub Copilot config...${NC}"
  echo ""

  local KIT_DIR
  KIT_DIR="$(find_kit_dir "$ROOT")"
  local MANIFEST="$KIT_DIR/manifest.yaml"

  if [ ! -f "$MANIFEST" ] && [ -f "$ROOT/saascode-kit.yaml" ]; then
    cp "$ROOT/saascode-kit.yaml" "$MANIFEST"
  fi

  if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: manifest.yaml not found${NC}"
    echo "Run first: npx saascode-kit init"
    exit 1
  fi

  load_manifest_vars "$MANIFEST"
  local INSTALLED=0

  # .github/copilot-instructions.md from template
  if [ -f "$KIT_DIR/templates/copilot-instructions.md.template" ]; then
    mkdir -p "$ROOT/.github"
    cp "$KIT_DIR/templates/copilot-instructions.md.template" "$ROOT/.github/copilot-instructions.md"
    replace_placeholders "$ROOT/.github/copilot-instructions.md"
    process_conditionals "$ROOT/.github/copilot-instructions.md"
    echo -e "  ${GREEN}✓${NC} .github/copilot-instructions.md"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "  ${RED}✗${NC} templates/copilot-instructions.md.template not found"
  fi

  echo ""
  echo -e "  ${GREEN}${BOLD}Installed $INSTALLED files for GitHub Copilot.${NC}"
}

cmd_aider() {
  echo -e "${BOLD}Installing Aider config...${NC}"
  echo ""

  local KIT_DIR
  KIT_DIR="$(find_kit_dir "$ROOT")"
  local MANIFEST="$KIT_DIR/manifest.yaml"

  if [ ! -f "$MANIFEST" ] && [ -f "$ROOT/saascode-kit.yaml" ]; then
    cp "$ROOT/saascode-kit.yaml" "$MANIFEST"
  fi

  if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: manifest.yaml not found${NC}"
    echo "Run first: npx saascode-kit init"
    exit 1
  fi

  load_manifest_vars "$MANIFEST"
  local INSTALLED=0

  # CONVENTIONS.md from template (Aider reads this file)
  if [ -f "$KIT_DIR/templates/aider-conventions.md.template" ]; then
    cp "$KIT_DIR/templates/aider-conventions.md.template" "$ROOT/CONVENTIONS.md"
    replace_placeholders "$ROOT/CONVENTIONS.md"
    process_conditionals "$ROOT/CONVENTIONS.md"
    echo -e "  ${GREEN}✓${NC} CONVENTIONS.md"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "  ${RED}✗${NC} templates/aider-conventions.md.template not found"
  fi

  # .aider.conf.yml
  cat > "$ROOT/.aider.conf.yml" << 'EOF'
# Aider configuration — generated by SaasCode Kit
read: CONVENTIONS.md
auto-commits: false
lint-cmd: saascode review
EOF
  echo -e "  ${GREEN}✓${NC} .aider.conf.yml"
  INSTALLED=$((INSTALLED + 1))

  echo ""
  echo -e "  ${GREEN}${BOLD}Installed $INSTALLED files for Aider.${NC}"
}

cmd_help() {
  echo ""
  echo "${BOLD}SaasCode Kit${NC} — SaaS development toolkit"
  echo ""
  echo "${BOLD}COMMANDS${NC}"
  echo ""
  echo "  ${CYAN}Setup:${NC}"
  printf "  %-28s %s\n" "saascode-kit init" "Run setup.sh to bootstrap kit in project"
  printf "  %-28s %s\n" "saascode-kit update" "Sync kit source → installed locations"
  printf "  %-28s %s\n" "saascode-kit verify" "Verify development environment setup"
  printf "  %-28s %s\n" "saascode-kit init --dry-run" "Preview what would be generated"
  printf "  %-28s %s\n" "saascode-kit doctor" "Diagnose common setup issues"
  printf "  %-28s %s\n" "saascode-kit status" "Show kit installation status"
  echo ""
  echo "  ${CYAN}IDE Setup:${NC}"
  printf "  %-28s %s\n" "saascode-kit claude" "Install Claude Code config (CLAUDE.md, skills, hooks)"
  printf "  %-28s %s\n" "saascode-kit cursor" "Install Cursor config (.cursorrules, rules)"
  printf "  %-28s %s\n" "saascode-kit windsurf" "Install Windsurf config (.windsurfrules)"
  printf "  %-28s %s\n" "saascode-kit antigravity" "Install Google Antigravity config (.agent/rules/)"
  printf "  %-28s %s\n" "saascode-kit copilot" "Install GitHub Copilot config"
  printf "  %-28s %s\n" "saascode-kit aider" "Install Aider config (CONVENTIONS.md)"
  echo ""
  echo "  ${CYAN}Code Review:${NC}"
  printf "  %-28s %s\n" "saascode-kit review" "AST-based code review (ts-morph)"
  printf "  %-28s %s\n" "saascode-kit review --ai" "AI-powered review (auto-detects provider)"
  printf "  %-28s %s\n" "saascode-kit review --ai --provider X" "Use specific provider (groq/openai/claude/gemini/deepseek/kimi/qwen)"
  printf "  %-28s %s\n" "saascode-kit review --ai --model X" "Override default model"
  printf "  %-28s %s\n" "saascode-kit review --ai --file X" "AI review a specific file"
  printf "  %-28s %s\n" "saascode-kit review --repo" "Repo-level cross-module analysis"
  printf "  %-28s %s\n" "saascode-kit review --json" "AST review with JSON output (CI integration)"
  printf "  %-28s %s\n" "saascode-kit review --sarif" "AST review with SARIF output (GitHub Code Scanning)"
  printf "  %-28s %s\n" "saascode-kit review --verify-intent \"desc\"" "Verify changes match stated intent (AI)"
  printf "  %-28s %s\n" "saascode-kit check-file <path>" "Single-file validator (Claude Code hook)"
  echo ""
  echo "  ${CYAN}Analysis:${NC}"
  printf "  %-28s %s\n" "saascode-kit sweep" "Run ALL checks (audit + predeploy + review)"
  printf "  %-28s %s\n" "saascode-kit sweep --ai" "Full sweep with AI review"
  printf "  %-28s %s\n" "saascode-kit audit" "Run full security + quality audit"
  printf "  %-28s %s\n" "saascode-kit parity" "Check frontend-backend endpoint parity"
  printf "  %-28s %s\n" "saascode-kit snapshot" "Generate project-map.md from codebase"
  printf "  %-28s %s\n" "saascode-kit docs" "Quick project overview (directory tree + stack)"
  printf "  %-28s %s\n" "saascode-kit docs --full" "Full docs (models, endpoints, pages, components)"
  printf "  %-28s %s\n" "saascode-kit docs --diagrams" "Add Mermaid architecture diagrams"
  printf "  %-28s %s\n" "saascode-kit docs --prd" "Product Brief from existing project"
  printf "  %-28s %s\n" "saascode-kit docs --prd \"idea\"" "Product Brief from new idea"
  echo ""
  echo "  ${CYAN}Tracking:${NC}"
  printf "  %-28s %s\n" "saascode-kit intent" "View AI edit intent log"
  printf "  %-28s %s\n" "saascode-kit intent --summary" "Session summaries"
  printf "  %-28s %s\n" "saascode-kit report" "View detected issues"
  printf "  %-28s %s\n" "saascode-kit report --github" "File issues to GitHub"
  printf "  %-28s %s\n" "saascode-kit report --summary" "Issue counts by category"
  echo ""
  echo "  ${CYAN}Adaptive Learning:${NC}"
  printf "  %-28s %s\n" "saascode-kit learn" "Analyze warning patterns"
  printf "  %-28s %s\n" "saascode-kit learn suppress" "Auto-suppress noisy warnings"
  printf "  %-28s %s\n" "saascode-kit learn show" "Show current suppressions"
  printf "  %-28s %s\n" "saascode-kit learn reset" "Clear all learned rules"
  echo ""
  echo "  ${CYAN}Stealth:${NC}"
  printf "  %-28s %s\n" "saascode-kit cloak" "Hide all kit + AI tool traces from repo"
  printf "  %-28s %s\n" "saascode-kit cloak --name .tools" "Use custom directory name"
  printf "  %-28s %s\n" "saascode-kit uncloak" "Reverse stealth mode, restore all files"
  echo ""
  echo "  ${CYAN}Deployment:${NC}"
  printf "  %-28s %s\n" "saascode-kit predeploy" "Run pre-deployment gates"
  printf "  %-28s %s\n" "saascode-kit checklist [name]" "Show a checklist (feature-complete, security-review, deploy-ready)"
  echo ""
  echo "  ${CYAN}Info:${NC}"
  printf "  %-28s %s\n" "saascode-kit rules" "List installed Semgrep rules"
  printf "  %-28s %s\n" "saascode-kit skills" "List installed Claude Code skills"
  printf "  %-28s %s\n" "saascode-kit help" "This help message"
  echo ""
  echo "  ${CYAN}Claude Code Skills (use in Claude Code conversation):${NC}"
  printf "  %-28s %s\n" "/audit" "Security + quality scan"
  printf "  %-28s %s\n" "/build" "Build a new feature step-by-step"
  printf "  %-28s %s\n" "/test [feature]" "Write + run tests"
  printf "  %-28s %s\n" "/debug" "Classify + trace bugs"
  printf "  %-28s %s\n" "/docs [init|full|feature]" "Organize documentation"
  printf "  %-28s %s\n" "/prd" "Product Brief from existing project"
  printf "  %-28s %s\n" "/prd [idea]" "Product Brief from new idea"
  printf "  %-28s %s\n" "/api [all|module|postman]" "Generate API reference"
  printf "  %-28s %s\n" "/migrate [plan|apply]" "Database migration workflow"
  printf "  %-28s %s\n" "/deploy [env|rollback]" "Deployment guide"
  printf "  %-28s %s\n" "/changelog [version]" "Generate changelog from git"
  printf "  %-28s %s\n" "/onboard" "Developer onboarding guide"
  printf "  %-28s %s\n" "/learn [finding]" "Capture bug patterns for self-improvement"
  printf "  %-28s %s\n" "/preflight" "Pre-deploy checklist"
  printf "  %-28s %s\n" "/review" "PR review"
  echo ""
  echo "  ${CYAN}Automatic (git hooks):${NC}"
  printf "  %-28s %s\n" "pre-commit" "Secrets, .env, debug statements, large files"
  printf "  %-28s %s\n" "pre-push" "TypeScript, build, security audit"
  echo ""
  echo "  ${CYAN}CI/CD (GitHub Actions):${NC}"
  printf "  %-28s %s\n" "On PR" "TypeScript, build, endpoint parity, secrets"
  echo ""
  echo "${DIM}Also available as: alias saascode='.saascode/scripts/saascode.sh'${NC}"
  echo ""
}

# ─── Route command ───

COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  init)       cmd_init "$@" ;;
  claude)     cmd_claude "$@" ;;
  cursor)     cmd_cursor "$@" ;;
  windsurf)   cmd_windsurf "$@" ;;
  antigravity) cmd_antigravity "$@" ;;
  copilot)    cmd_copilot "$@" ;;
  aider)      cmd_aider "$@" ;;
  review)     cmd_review "$@" ;;
  audit)      cmd_audit "$@" ;;
  parity)     cmd_parity "$@" ;;
  predeploy)  cmd_predeploy "$@" ;;
  verify)     cmd_verify "$@" ;;
  checklist)  cmd_checklist "$@" ;;
  rules)      cmd_rules "$@" ;;
  skills)     cmd_skills "$@" ;;
  docs)       cmd_docs "$@" ;;
  snapshot)   cmd_snapshot "$@" ;;
  update)     cmd_update "$@" ;;
  status)     cmd_status "$@" ;;
  doctor)     cmd_doctor "$@" ;;
  check-file) cmd_check_file "$@" ;;
  intent)     cmd_intent "$@" ;;
  report)     cmd_report "$@" ;;
  sweep)      cmd_sweep "$@" ;;
  cloak)      cmd_cloak "$@" ;;
  uncloak)    cmd_uncloak "$@" ;;
  learn)
    if [ -f "$SCRIPTS_DIR/adaptive-learn.sh" ]; then
      bash "$SCRIPTS_DIR/adaptive-learn.sh" "$@"
    else
      echo "${RED}Error: adaptive-learn.sh not found at $SCRIPTS_DIR${NC}"
      exit 1
    fi
    ;;
  help|--help|-h)  cmd_help ;;
  *)
    echo "${RED}Unknown command: $COMMAND${NC}"
    echo ""
    cmd_help
    exit 1
    ;;
esac
