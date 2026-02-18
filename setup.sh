#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — Setup Script
# Reads manifest.yaml and generates project-specific configs
#
# Usage:
#   ./setup.sh                          # Interactive mode
#   ./setup.sh /path/to/target/project  # Direct mode
#   ./setup.sh --help                   # Show help
# ═══════════════════════════════════════════════════════════

set -e

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$KIT_DIR/manifest.yaml"

# Source shared library
source "$KIT_DIR/scripts/lib.sh"

# ─── Help ───
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "${BOLD}SaasCode Kit Setup${NC}"
  echo ""
  echo "Usage:"
  echo "  ./setup.sh                          Interactive mode"
  echo "  ./setup.sh /path/to/project         Direct mode"
  echo "  ./setup.sh --help                   This help"
  echo ""
  echo "Prerequisites:"
  echo "  1. Copy manifest.example.yaml → manifest.yaml"
  echo "  2. Fill in your project details"
  echo "  3. Run this script"
  echo ""
  echo "What it does:"
  echo "  - Generates CLAUDE.md / .cursorrules / .windsurfrules from templates"
  echo "  - Copies Claude Code skills to .claude/skills/"
  echo "  - Copies Semgrep rules to .saascode/rules/"
  echo "  - Installs git hooks (pre-commit, pre-push)"
  echo "  - Copies GitHub Actions workflow"
  echo "  - Copies utility scripts"
  echo "  - Copies checklists"
  exit 0
fi

# ─── Check manifest exists ───
if [ ! -f "$MANIFEST" ]; then
  echo "${RED}Error: manifest.yaml not found at $KIT_DIR${NC}"
  echo ""
  echo "Run these commands first:"
  echo "  cp $KIT_DIR/manifest.example.yaml $KIT_DIR/manifest.yaml"
  echo "  # Edit manifest.yaml with your project details"
  exit 1
fi

# ─── Target project ───
if [ -n "$1" ]; then
  TARGET="$1"
else
  echo "${BOLD}SaasCode Kit Setup${NC}"
  echo ""
  read -p "Target project path: " TARGET
fi

if [ ! -d "$TARGET" ]; then
  echo "${RED}Error: Directory not found: $TARGET${NC}"
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"
echo ""
echo "${CYAN}Kit:    $KIT_DIR${NC}"
echo "${CYAN}Target: $TARGET${NC}"
echo ""

# Parse manifest and load variables via lib.sh
load_manifest_vars "$MANIFEST"

echo "${BOLD}Parsed from manifest:${NC}"
echo "  Project:  $PROJECT_NAME"
echo "  Backend:  $BACKEND_PATH"
echo "  Frontend: $FRONTEND_PATH"
echo "  Tenant:   $TENANT_IDENTIFIER"
echo ""

# ─── Select what to install ───
echo "${BOLD}What to install:${NC}"
echo "  1) Everything (recommended)"
echo "  2) Pick components"
echo ""
read -p "Choice [1]: " CHOICE
CHOICE="${CHOICE:-1}"

INSTALL_TEMPLATES=true
INSTALL_SKILLS=true
INSTALL_RULES=true
INSTALL_HOOKS=true
INSTALL_CI=true
INSTALL_SCRIPTS=true
INSTALL_CHECKLISTS=true

if [ "$CHOICE" = "2" ]; then
  read -p "  IDE context (CLAUDE.md, .cursorrules, .windsurfrules)? [Y/n]: " ANS
  [ "$ANS" = "n" ] || [ "$ANS" = "N" ] && INSTALL_TEMPLATES=false

  read -p "  Claude Code skills (/audit, /build, /preflight, /review, /docs, /debug)? [Y/n]: " ANS
  [ "$ANS" = "n" ] || [ "$ANS" = "N" ] && INSTALL_SKILLS=false

  read -p "  Semgrep rules? [Y/n]: " ANS
  [ "$ANS" = "n" ] || [ "$ANS" = "N" ] && INSTALL_RULES=false

  read -p "  Git hooks (pre-commit, pre-push)? [Y/n]: " ANS
  [ "$ANS" = "n" ] || [ "$ANS" = "N" ] && INSTALL_HOOKS=false

  read -p "  CI pipeline (GitHub Actions)? [Y/n]: " ANS
  [ "$ANS" = "n" ] || [ "$ANS" = "N" ] && INSTALL_CI=false

  read -p "  Shell scripts (audit, parity, deploy)? [Y/n]: " ANS
  [ "$ANS" = "n" ] || [ "$ANS" = "N" ] && INSTALL_SCRIPTS=false

  read -p "  Checklists? [Y/n]: " ANS
  [ "$ANS" = "n" ] || [ "$ANS" = "N" ] && INSTALL_CHECKLISTS=false
fi

echo ""
echo "${CYAN}Installing...${NC}"
echo ""

INSTALLED=0

# ─── 1. IDE Context Templates ───
if [ "$INSTALL_TEMPLATES" = true ]; then
  echo "${YELLOW}[Templates]${NC}"

  # CLAUDE.md — generate if .claude/ directory exists or CLAUDE.md already exists
  if [ -d "$TARGET/.claude" ] || [ -f "$TARGET/CLAUDE.md" ] || [ ! -f "$TARGET/.cursorrules" -a ! -f "$TARGET/.windsurfrules" ]; then
    cp "$KIT_DIR/templates/CLAUDE.md.template" "$TARGET/CLAUDE.md"
    replace_placeholders "$TARGET/CLAUDE.md"
    echo "  ${GREEN}✓${NC} CLAUDE.md"
    INSTALLED=$((INSTALLED + 1))
  fi

  # Golden reference — generate to .claude/context/ for /build skill
  if [ -f "$KIT_DIR/templates/golden-reference.md.template" ]; then
    mkdir -p "$TARGET/.claude/context"
    cp "$KIT_DIR/templates/golden-reference.md.template" "$TARGET/.claude/context/golden-reference.md"
    replace_placeholders "$TARGET/.claude/context/golden-reference.md"
    echo "  ${GREEN}✓${NC} .claude/context/golden-reference.md"
    INSTALLED=$((INSTALLED + 1))
  fi

  # .cursorrules — generate ONLY if .cursor/ directory or .cursorrules already exists
  if [ -d "$TARGET/.cursor" ] || [ -f "$TARGET/.cursorrules" ]; then
    cp "$KIT_DIR/templates/cursorrules.template" "$TARGET/.cursorrules"
    replace_placeholders "$TARGET/.cursorrules"
    echo "  ${GREEN}✓${NC} .cursorrules"
    INSTALLED=$((INSTALLED + 1))
  else
    echo "  ${YELLOW}—${NC} .cursorrules (skipped — no .cursor/ detected)"
  fi

  # .windsurfrules — generate ONLY if .windsurf/ directory or .windsurfrules already exists
  if [ -d "$TARGET/.windsurf" ] || [ -f "$TARGET/.windsurfrules" ]; then
    cp "$KIT_DIR/templates/windsurfrules.template" "$TARGET/.windsurfrules"
    replace_placeholders "$TARGET/.windsurfrules"
    echo "  ${GREEN}✓${NC} .windsurfrules"
    INSTALLED=$((INSTALLED + 1))
  else
    echo "  ${YELLOW}—${NC} .windsurfrules (skipped — no .windsurf/ detected)"
  fi
fi

# ─── 1b. Cursor Rules (file-pattern-specific) ───
if [ -d "$TARGET/.cursor" ] && [ -d "$KIT_DIR/cursor-rules" ]; then
  echo "${YELLOW}[Cursor Rules]${NC}"
  mkdir -p "$TARGET/.cursor/rules"

  for RULE in "$KIT_DIR"/cursor-rules/*.mdc; do
    RULE_NAME=$(basename "$RULE")
    cp "$RULE" "$TARGET/.cursor/rules/$RULE_NAME"
    replace_placeholders "$TARGET/.cursor/rules/$RULE_NAME"
    echo "  ${GREEN}✓${NC} .cursor/rules/$RULE_NAME"
    INSTALLED=$((INSTALLED + 1))
  done

  # Conditional: remove ai-security.mdc if ai.enabled is not true
  AI_ENABLED="${M_ai_enabled:-false}"
  if [ "$AI_ENABLED" != "true" ]; then
    if [ -f "$TARGET/.cursor/rules/ai-security.mdc" ]; then
      rm "$TARGET/.cursor/rules/ai-security.mdc"
      INSTALLED=$((INSTALLED - 1))
      echo "  ${YELLOW}—${NC} .cursor/rules/ai-security.mdc (skipped — ai.enabled=false)"
    fi
  fi

  # Framework-specific cursor rules: keep only the matching framework rule
  FRAMEWORK_RULES="express-controller.mdc django-view.mdc rails-controller.mdc spring-controller.mdc laravel-controller.mdc"
  MATCHING_RULE=""
  case "${LANGUAGE:-typescript}" in
    typescript|javascript)
      case "${BACKEND_FRAMEWORK:-}" in
        express|fastify) MATCHING_RULE="express-controller.mdc" ;;
        nestjs|nest)     MATCHING_RULE="" ;; # Use default backend-controller.mdc (NestJS)
        *)               MATCHING_RULE="express-controller.mdc" ;; # Default for JS/TS
      esac
      ;;
    python)  MATCHING_RULE="django-view.mdc" ;;
    ruby)    MATCHING_RULE="rails-controller.mdc" ;;
    java|kotlin) MATCHING_RULE="spring-controller.mdc" ;;
    php)     MATCHING_RULE="laravel-controller.mdc" ;;
  esac

  # Remove non-matching framework rules, keep the matching one
  for FR in $FRAMEWORK_RULES; do
    if [ "$FR" != "$MATCHING_RULE" ] && [ -f "$TARGET/.cursor/rules/$FR" ]; then
      rm "$TARGET/.cursor/rules/$FR"
      INSTALLED=$((INSTALLED - 1))
    fi
  done

  # For non-NestJS frameworks, remove NestJS-specific backend-controller.mdc
  if [ -n "$MATCHING_RULE" ] && [ -f "$TARGET/.cursor/rules/backend-controller.mdc" ]; then
    rm "$TARGET/.cursor/rules/backend-controller.mdc"
    INSTALLED=$((INSTALLED - 1))
    echo "  ${YELLOW}—${NC} .cursor/rules/backend-controller.mdc (replaced by $MATCHING_RULE)"
  fi

  if [ -n "$MATCHING_RULE" ]; then
    echo "  ${GREEN}✓${NC} .cursor/rules/$MATCHING_RULE (framework-specific)"
  fi
else
  if [ "$INSTALL_TEMPLATES" = true ] && [ ! -d "$TARGET/.cursor" ]; then
    echo "  ${YELLOW}—${NC} .cursor/rules/ (skipped — no .cursor/ detected)"
  fi
fi

# ─── 2. Claude Code Skills ───
if [ "$INSTALL_SKILLS" = true ]; then
  echo "${YELLOW}[Skills]${NC}"
  mkdir -p "$TARGET/.claude/skills"

  for SKILL in "$KIT_DIR"/skills/*.md; do
    SKILL_NAME=$(basename "$SKILL")
    cp "$SKILL" "$TARGET/.claude/skills/$SKILL_NAME"
    replace_placeholders "$TARGET/.claude/skills/$SKILL_NAME"
    echo "  ${GREEN}✓${NC} .claude/skills/$SKILL_NAME"
    INSTALLED=$((INSTALLED + 1))
  done
fi

# ─── 3. Semgrep Rules ───
if [ "$INSTALL_RULES" = true ]; then
  echo "${YELLOW}[Semgrep Rules]${NC}"
  mkdir -p "$TARGET/.saascode/rules"

  # Always install universal rules (security.yaml covers TS/JS + some cross-lang)
  for RULE in "$KIT_DIR"/rules/security.yaml "$KIT_DIR"/rules/auth-guards.yaml "$KIT_DIR"/rules/tenant-isolation.yaml "$KIT_DIR"/rules/input-validation.yaml "$KIT_DIR"/rules/ui-consistency.yaml; do
    if [ -f "$RULE" ]; then
      RULE_NAME=$(basename "$RULE")
      cp "$RULE" "$TARGET/.saascode/rules/$RULE_NAME"
      echo "  ${GREEN}✓${NC} .saascode/rules/$RULE_NAME"
      INSTALLED=$((INSTALLED + 1))
    fi
  done

  # Install language-specific rules based on stackLanguage
  LANG_RULE=""
  case "$LANGUAGE" in
    python)  LANG_RULE="python-security.yaml" ;;
    java)    LANG_RULE="java-security.yaml" ;;
    go)      LANG_RULE="go-security.yaml" ;;
    ruby)    LANG_RULE="ruby-security.yaml" ;;
    php)     LANG_RULE="php-security.yaml" ;;
  esac

  if [ -n "$LANG_RULE" ] && [ -f "$KIT_DIR/rules/$LANG_RULE" ]; then
    cp "$KIT_DIR/rules/$LANG_RULE" "$TARGET/.saascode/rules/$LANG_RULE"
    echo "  ${GREEN}✓${NC} .saascode/rules/$LANG_RULE (language-specific)"
    INSTALLED=$((INSTALLED + 1))
  fi
fi

# ─── 4. Git Hooks ───
if [ "$INSTALL_HOOKS" = true ]; then
  echo "${YELLOW}[Git Hooks]${NC}"

  if [ -d "$TARGET/.git" ]; then
    mkdir -p "$TARGET/.git/hooks"

    cp "$KIT_DIR/hooks/pre-commit" "$TARGET/.git/hooks/pre-commit"
    chmod +x "$TARGET/.git/hooks/pre-commit"
    echo "  ${GREEN}✓${NC} .git/hooks/pre-commit"
    INSTALLED=$((INSTALLED + 1))

    cp "$KIT_DIR/hooks/pre-push" "$TARGET/.git/hooks/pre-push"
    chmod +x "$TARGET/.git/hooks/pre-push"
    echo "  ${GREEN}✓${NC} .git/hooks/pre-push"
    INSTALLED=$((INSTALLED + 1))
  elif [ -d "$TARGET/.husky" ]; then
    cp "$KIT_DIR/hooks/pre-commit" "$TARGET/.husky/pre-commit"
    chmod +x "$TARGET/.husky/pre-commit"
    echo "  ${GREEN}✓${NC} .husky/pre-commit"
    INSTALLED=$((INSTALLED + 1))

    cp "$KIT_DIR/hooks/pre-push" "$TARGET/.husky/pre-push"
    chmod +x "$TARGET/.husky/pre-push"
    echo "  ${GREEN}✓${NC} .husky/pre-push"
    INSTALLED=$((INSTALLED + 1))
  else
    echo "  ${YELLOW}⚠ No .git or .husky directory found — skipping hooks${NC}"
  fi
fi

# ─── 5. CI Pipeline ───
if [ "$INSTALL_CI" = true ]; then
  echo "${YELLOW}[CI Pipeline]${NC}"

  CI_TRIMMED=$(echo "$CI_PROVIDER" | tr -d ' ')
  if [ "$CI_TRIMMED" = "github" ] || [ -z "$CI_TRIMMED" ]; then
    mkdir -p "$TARGET/.github/workflows"
    cp "$KIT_DIR/ci/github-action.yml" "$TARGET/.github/workflows/saascode.yml"

    # Process conditionals first (language-specific blocks), then replace placeholders
    process_conditionals "$TARGET/.github/workflows/saascode.yml"
    replace_placeholders "$TARGET/.github/workflows/saascode.yml"

    echo "  ${GREEN}✓${NC} .github/workflows/saascode.yml (language: $LANGUAGE)"
    INSTALLED=$((INSTALLED + 1))
  else
    echo "  ${YELLOW}⚠ CI provider '$CI_PROVIDER' — only GitHub Actions supported in v1${NC}"
  fi
fi

# ─── 6. Scripts (inside .saascode/) ───
if [ "$INSTALL_SCRIPTS" = true ]; then
  echo "${YELLOW}[Scripts]${NC}"
  mkdir -p "$TARGET/.saascode/scripts"

  for SCRIPT in "$KIT_DIR"/scripts/*.sh; do
    SCRIPT_NAME=$(basename "$SCRIPT")
    cp "$SCRIPT" "$TARGET/.saascode/scripts/$SCRIPT_NAME"
    chmod +x "$TARGET/.saascode/scripts/$SCRIPT_NAME"
    echo "  ${GREEN}✓${NC} .saascode/scripts/$SCRIPT_NAME"
    INSTALLED=$((INSTALLED + 1))
  done

  # Also copy .ts scripts (e.g. ast-review.ts)
  for SCRIPT in "$KIT_DIR"/scripts/*.ts; do
    [ -f "$SCRIPT" ] || continue
    SCRIPT_NAME=$(basename "$SCRIPT")
    cp "$SCRIPT" "$TARGET/.saascode/scripts/$SCRIPT_NAME"
    echo "  ${GREEN}✓${NC} .saascode/scripts/$SCRIPT_NAME"
    INSTALLED=$((INSTALLED + 1))
  done

  # Also copy .py scripts (e.g. ast-review-python.py)
  for SCRIPT in "$KIT_DIR"/scripts/*.py; do
    [ -f "$SCRIPT" ] || continue
    SCRIPT_NAME=$(basename "$SCRIPT")
    cp "$SCRIPT" "$TARGET/.saascode/scripts/$SCRIPT_NAME"
    echo "  ${GREEN}✓${NC} .saascode/scripts/$SCRIPT_NAME"
    INSTALLED=$((INSTALLED + 1))
  done
fi

# ─── 7. Checklists (inside .saascode/) ───
if [ "$INSTALL_CHECKLISTS" = true ]; then
  echo "${YELLOW}[Checklists]${NC}"
  mkdir -p "$TARGET/.saascode/checklists"

  for CHECKLIST in "$KIT_DIR"/checklists/*.md; do
    CL_NAME=$(basename "$CHECKLIST")
    cp "$CHECKLIST" "$TARGET/.saascode/checklists/$CL_NAME"
    echo "  ${GREEN}✓${NC} .saascode/checklists/$CL_NAME"
    INSTALLED=$((INSTALLED + 1))
  done
fi

# ─── 8b. Claude Code hooks (.claude/settings.json) ───
echo "${YELLOW}[Claude Code Hooks]${NC}"
SETTINGS="$TARGET/.claude/settings.json"
mkdir -p "$TARGET/.claude"

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
echo "  ${GREEN}✓${NC} .claude/settings.json (check-file + intent-log hooks)"
INSTALLED=$((INSTALLED + 1))

# ─── 8. .gitignore — personal vs team split ───
echo ""
echo "${YELLOW}[.gitignore]${NC}"
GITIGNORE="$TARGET/.gitignore"

# Compute relative path of kit directory from target project
KIT_RELATIVE=$(python3 -c "import os.path; print(os.path.relpath('$KIT_DIR', '$TARGET'))" 2>/dev/null || echo "saascode-kit")

# For npx installs, the relative path contains _npx or node_modules — use generic pattern
case "$KIT_RELATIVE" in
  *_npx*|*node_modules*)
    KIT_RELATIVE="saascode-kit"
    ;;
esac

# Personal (device-local, each dev uses their own IDE)
# Team-shared files: .saascode/, .github/workflows/ — NOT gitignored
ADDITIONS=(
  ""
  "# SaasCode Kit — personal/IDE-specific (not shared with team)"
  "$KIT_RELATIVE/"
  "CLAUDE.md"
  ".cursorrules"
  ".windsurfrules"
  ".claude/skills/"
  ".cursor/rules/"
  "docs/diagrams/visual/exported/"
)

if [ -f "$GITIGNORE" ]; then
  ADDED=0
  for ENTRY in "${ADDITIONS[@]}"; do
    [ -z "$ENTRY" ] && continue
    if ! grep -qF "$ENTRY" "$GITIGNORE" 2>/dev/null; then
      echo "$ENTRY" >> "$GITIGNORE"
      ADDED=$((ADDED + 1))
    fi
  done
  if [ $ADDED -gt 0 ]; then
    echo "  ${GREEN}✓${NC} Added $ADDED entries to .gitignore"
  else
    echo "  ${GREEN}✓${NC} .gitignore already up to date"
  fi
else
  printf '%s\n' "${ADDITIONS[@]}" > "$GITIGNORE"
  echo "  ${GREEN}✓${NC} Created .gitignore"
fi

echo ""
echo "  ${CYAN}Committed (team shares):${NC}"
echo "    .saascode/             (rules, scripts, checklists)"
echo "    .github/workflows/     (CI pipeline)"
echo "    .claude/settings.json  (Claude Code hooks — consistent across team)"
echo ""
echo "  ${CYAN}Gitignored (personal):${NC}"
echo "    CLAUDE.md          (Claude Code users)"
echo "    .cursorrules       (Cursor users)"
echo "    .claude/skills/    (Claude Code users)"
echo "    $KIT_RELATIVE/     (kit source)"

# ─── Summary ───
echo ""
echo "═══════════════════════════════════════════════"
echo "${GREEN}${BOLD}  Setup Complete!${NC}"
echo "═══════════════════════════════════════════════"
echo "  Installed: ${BOLD}$INSTALLED${NC} files to $TARGET"
echo ""
echo "${CYAN}  CLI setup (one-time):${NC}"
echo "  Add to your ~/.zshrc or ~/.bashrc:"
echo "    alias saascode='.saascode/scripts/saascode.sh'"
echo "  Then: source ~/.zshrc"
echo ""
echo "${CYAN}  Next steps:${NC}"
echo "  1. Review generated CLAUDE.md — remove sections that don't apply"
echo "  2. Install Semgrep for IDE integration: pip install semgrep"
echo "  3. Test hooks: git add . && git commit -m 'test'"
echo "  4. Try: saascode help"
echo ""
echo "${CYAN}  Shell commands:${NC}"
echo "    saascode init             Bootstrap kit in project"
echo "    saascode review --ai      AI-powered code review (Groq)"
echo "    saascode review           AST-based code review"
echo "    saascode check-file <f>   Single-file validator"
echo "    saascode audit            Full security + quality audit"
echo "    saascode parity           Frontend-backend endpoint parity"
echo "    saascode snapshot         Generate project-map.md"
echo "    saascode intent           View AI edit intent log"
echo "    saascode intent --summary Session summaries"
echo "    saascode predeploy        Pre-deployment gates"
echo "    saascode verify           Check dev environment setup"
echo "    saascode update           Sync kit → installed locations"
echo "    saascode status           Kit installation status"
echo "    saascode help             All commands"
echo ""
echo "${CYAN}  Claude Code skills:${NC}"
echo "    /audit  /build  /test  /debug  /docs  /api"
echo "    /migrate  /deploy  /changelog  /onboard"
echo "    /learn  /preflight  /review"
echo ""
