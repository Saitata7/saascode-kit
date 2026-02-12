#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode CLI — Quick access to all kit commands
#
# Usage:
#   saascode <command> [options]
#
# Install:
#   Add to your shell profile (~/.bashrc or ~/.zshrc):
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

# ─── Commands ───

cmd_init() {
  local KIT="$ROOT/saascode-kit"
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
    bash "$SCRIPTS_DIR/full-audit.sh"
  else
    echo "${RED}Error: full-audit.sh not found at $SCRIPTS_DIR${NC}"
    exit 1
  fi
}

cmd_review() {
  # Route --ai flag to AI-powered review
  local HAS_AI=false
  for arg in "$@"; do
    [ "$arg" = "--ai" ] && HAS_AI=true
  done

  if [ "$HAS_AI" = true ]; then
    if [ -f "$SCRIPTS_DIR/ai-review.sh" ]; then
      bash "$SCRIPTS_DIR/ai-review.sh" "$@"
    else
      echo "${RED}Error: ai-review.sh not found at $SCRIPTS_DIR${NC}"
      exit 1
    fi
    return
  fi

  # Default: AST review
  if [ -f "$SCRIPTS_DIR/ast-review.sh" ]; then
    bash "$SCRIPTS_DIR/ast-review.sh" "$@"
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
    bash "$SCRIPTS_DIR/pre-deploy.sh"
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
    echo "Checking environment..."
    echo ""
    node -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} Node.js $(node -v)" || echo "  ${RED}✗${NC} Node.js not installed"
    npm -v >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} npm $(npm -v)" || echo "  ${RED}✗${NC} npm not installed"
    psql --version >/dev/null 2>&1 && echo "  ${GREEN}✓${NC} PostgreSQL installed" || echo "  ${RED}✗${NC} PostgreSQL not installed"
    [ -d "$ROOT/node_modules" ] && echo "  ${GREEN}✓${NC} Dependencies installed" || echo "  ${RED}✗${NC} Run: npm install"
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
    echo "  ${GREEN}✓${NC} Scripts: $(ls "$KIT"/scripts/*.sh "$KIT"/scripts/*.ts 2>/dev/null | wc -l | tr -d ' ') files → .saascode/scripts/"
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

cmd_check_file() {
  local FILE="${1}"
  if [ -z "$FILE" ]; then
    echo "Usage: saascode check-file <filepath>"
    exit 1
  fi
  bash "$SCRIPTS_DIR/check-file.sh" "$FILE"
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

  if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: manifest.yaml not found in $KIT_DIR${NC}"
    echo "Run: cp $KIT_DIR/manifest.example.yaml $KIT_DIR/manifest.yaml"
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

  if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: manifest.yaml not found in $KIT_DIR${NC}"
    echo "Run: cp $KIT_DIR/manifest.example.yaml $KIT_DIR/manifest.yaml"
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

  if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: manifest.yaml not found in $KIT_DIR${NC}"
    echo "Run: cp $KIT_DIR/manifest.example.yaml $KIT_DIR/manifest.yaml"
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

cmd_help() {
  echo ""
  echo "${BOLD}SaasCode CLI${NC} — SaaS development toolkit"
  echo ""
  echo "${BOLD}COMMANDS${NC}"
  echo ""
  echo "  ${CYAN}Setup:${NC}"
  printf "  %-24s %s\n" "saascode init" "Run setup.sh to bootstrap kit in project"
  printf "  %-24s %s\n" "saascode update" "Sync kit source → installed locations"
  printf "  %-24s %s\n" "saascode verify" "Verify development environment setup"
  printf "  %-24s %s\n" "saascode status" "Show kit installation status"
  echo ""
  echo "  ${CYAN}IDE Setup:${NC}"
  printf "  %-24s %s\n" "saascode claude" "Install Claude Code config (CLAUDE.md, skills, hooks)"
  printf "  %-24s %s\n" "saascode cursor" "Install Cursor config (.cursorrules, rules)"
  printf "  %-24s %s\n" "saascode windsurf" "Install Windsurf config (.windsurfrules)"
  echo ""
  echo "  ${CYAN}Code Review:${NC}"
  printf "  %-24s %s\n" "saascode review" "AST-based code review (ts-morph)"
  printf "  %-24s %s\n" "saascode review --ai" "AI-powered review (auto-detects provider)"
  printf "  %-24s %s\n" "saascode review --ai --provider X" "Use specific provider (groq/openai/claude/gemini/deepseek/kimi/qwen)"
  printf "  %-24s %s\n" "saascode review --ai --model X" "Override default model"
  printf "  %-24s %s\n" "saascode review --ai --file X" "AI review a specific file"
  printf "  %-24s %s\n" "saascode check-file <path>" "Single-file validator (Claude Code hook)"
  echo ""
  echo "  ${CYAN}Analysis:${NC}"
  printf "  %-24s %s\n" "saascode audit" "Run full security + quality audit"
  printf "  %-24s %s\n" "saascode parity" "Check frontend-backend endpoint parity"
  printf "  %-24s %s\n" "saascode snapshot" "Generate project-map.md from codebase"
  echo ""
  echo "  ${CYAN}Tracking:${NC}"
  printf "  %-24s %s\n" "saascode intent" "View AI edit intent log"
  printf "  %-24s %s\n" "saascode intent --summary" "Session summaries"
  echo ""
  echo "  ${CYAN}Deployment:${NC}"
  printf "  %-24s %s\n" "saascode predeploy" "Run pre-deployment gates"
  printf "  %-24s %s\n" "saascode checklist [name]" "Show a checklist (feature-complete, security-review, deploy-ready)"
  echo ""
  echo "  ${CYAN}Info:${NC}"
  printf "  %-24s %s\n" "saascode rules" "List installed Semgrep rules"
  printf "  %-24s %s\n" "saascode skills" "List installed Claude Code skills"
  printf "  %-24s %s\n" "saascode help" "This help message"
  echo ""
  echo "  ${CYAN}Claude Code Skills (use in Claude Code conversation):${NC}"
  printf "  %-24s %s\n" "/audit" "Security + quality scan"
  printf "  %-24s %s\n" "/build" "Build a new feature step-by-step"
  printf "  %-24s %s\n" "/test [feature]" "Write + run tests"
  printf "  %-24s %s\n" "/debug" "Classify + trace bugs"
  printf "  %-24s %s\n" "/docs [init|full|feature]" "Organize documentation"
  printf "  %-24s %s\n" "/api [all|module|postman]" "Generate API reference"
  printf "  %-24s %s\n" "/migrate [plan|apply]" "Database migration workflow"
  printf "  %-24s %s\n" "/deploy [env|rollback]" "Deployment guide"
  printf "  %-24s %s\n" "/changelog [version]" "Generate changelog from git"
  printf "  %-24s %s\n" "/onboard" "Developer onboarding guide"
  printf "  %-24s %s\n" "/learn [finding]" "Capture bug patterns for self-improvement"
  printf "  %-24s %s\n" "/preflight" "Pre-deploy checklist"
  printf "  %-24s %s\n" "/review" "PR review"
  echo ""
  echo "  ${CYAN}Automatic (git hooks):${NC}"
  printf "  %-24s %s\n" "pre-commit" "Secrets, .env, debug statements, large files"
  printf "  %-24s %s\n" "pre-push" "TypeScript, build, security audit"
  echo ""
  echo "  ${CYAN}CI/CD (GitHub Actions):${NC}"
  printf "  %-24s %s\n" "On PR" "TypeScript, build, endpoint parity, secrets"
  echo ""
  echo "${DIM}Setup: alias saascode='.saascode/scripts/saascode.sh'${NC}"
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
  review)     cmd_review "$@" ;;
  audit)      cmd_audit "$@" ;;
  parity)     cmd_parity "$@" ;;
  predeploy)  cmd_predeploy "$@" ;;
  verify)     cmd_verify "$@" ;;
  checklist)  cmd_checklist "$@" ;;
  rules)      cmd_rules "$@" ;;
  skills)     cmd_skills "$@" ;;
  snapshot)   cmd_snapshot "$@" ;;
  update)     cmd_update "$@" ;;
  status)     cmd_status "$@" ;;
  check-file) cmd_check_file "$@" ;;
  intent)     cmd_intent "$@" ;;
  help|--help|-h)  cmd_help ;;
  *)
    echo "${RED}Unknown command: $COMMAND${NC}"
    echo ""
    cmd_help
    exit 1
    ;;
esac
