#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit CLI — Entry point for npx
#
# Usage:
#   npx kit <command> [options]
#
# Examples:
#   npx kit init              # Set up kit in current project
#   npx kit review            # AST code review
#   npx kit audit             # Full security audit
#   npx kit docs --diagrams   # Generate docs with diagrams
#   npx kit help              # Show all commands
# ═══════════════════════════════════════════════════════════

# Resolve symlinks (npx creates symlinks in node_modules/.bin/)
SCRIPT="$0"
while [ -L "$SCRIPT" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT")" && pwd)"
  SCRIPT="$(readlink "$SCRIPT")"
  # Handle relative symlink targets
  [[ "$SCRIPT" != /* ]] && SCRIPT="$SCRIPT_DIR/$SCRIPT"
done
KIT_DIR="$(cd "$(dirname "$SCRIPT")/.." && pwd)"

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
  echo ""
  echo -e "${BOLD}SaasCode Kit${NC} — SaaS development toolkit"
  echo ""
  echo -e "${BOLD}COMMANDS${NC}"
  echo ""
  echo -e "  ${CYAN}Setup:${NC}"
  printf "  %-28s %s\n" "kitinit" "Set up kit in current project"
  printf "  %-28s %s\n" "kitinit /path" "Set up kit in specific project"
  printf "  %-28s %s\n" "kitupdate" "Sync kit source → installed locations"
  printf "  %-28s %s\n" "kitverify" "Verify development environment setup"
  printf "  %-28s %s\n" "kitstatus" "Show kit installation status"
  echo ""
  echo -e "  ${CYAN}IDE Setup:${NC}"
  printf "  %-28s %s\n" "kitclaude" "Install Claude Code config (CLAUDE.md, skills, hooks)"
  printf "  %-28s %s\n" "kitcursor" "Install Cursor config (.cursorrules, rules)"
  printf "  %-28s %s\n" "kitwindsurf" "Install Windsurf config (.windsurfrules)"
  printf "  %-28s %s\n" "kitantigravity" "Install Google Antigravity config"
  printf "  %-28s %s\n" "kitcline" "Install Cline config (.clinerules)"
  printf "  %-28s %s\n" "kitcontinue" "Install Continue config (.continue/rules/)"
  printf "  %-28s %s\n" "kitcopilot" "Install GitHub Copilot config"
  printf "  %-28s %s\n" "kitaider" "Install Aider config (CONVENTIONS.md)"
  echo ""
  echo -e "  ${CYAN}Code Review:${NC}"
  printf "  %-28s %s\n" "kitreview" "AST-based code review (ts-morph)"
  printf "  %-28s %s\n" "kitreview --ai" "AI-powered review (auto-detects provider)"
  printf "  %-28s %s\n" "kitcheck-file <path>" "Single-file validator"
  echo ""
  echo -e "  ${CYAN}Analysis:${NC}"
  printf "  %-28s %s\n" "kitaudit" "Run full security + quality audit"
  printf "  %-28s %s\n" "kitparity" "Check frontend-backend endpoint parity"
  printf "  %-28s %s\n" "kitsnapshot" "Generate project-map.md from codebase"
  printf "  %-28s %s\n" "kitdocs" "Quick project overview (directory tree + stack)"
  printf "  %-28s %s\n" "kitdocs --full" "Full docs (models, endpoints, pages, components)"
  printf "  %-28s %s\n" "kitdocs --diagrams" "Add Mermaid architecture diagrams"
  printf "  %-28s %s\n" "kitdocs --prd" "Product Brief from existing project"
  printf "  %-28s %s\n" "kitdocs --prd \"idea\"" "Product Brief from new idea"
  echo ""
  echo -e "  ${CYAN}Deployment:${NC}"
  printf "  %-28s %s\n" "kitpredeploy" "Run pre-deployment gates"
  printf "  %-28s %s\n" "kitchecklist [name]" "Show a checklist"
  echo ""
  echo -e "  ${CYAN}Info:${NC}"
  printf "  %-28s %s\n" "kitrules" "List installed Semgrep rules"
  printf "  %-28s %s\n" "kitskills" "List installed Claude Code skills"
  printf "  %-28s %s\n" "kitintent" "View AI edit intent log"
  printf "  %-28s %s\n" "kithelp" "This help message"
  echo ""
  echo -e "${DIM}Docs: https://github.com/Saitata7/saascode-kit${NC}"
  echo ""
}

cmd_init() {
  local TARGET="${1:-.}"
  TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || {
    echo -e "${RED}Error: Directory not found: $1${NC}"
    exit 1
  }

  local MANIFEST_IN_PROJECT="$TARGET/saascode-kit.yaml"

  echo ""
  echo -e "${BOLD}SaasCode Kit — Init${NC}"
  echo -e "${DIM}Target: $TARGET${NC}"
  echo ""

  # Step 1: If no manifest in user's project, create one and stop
  if [ ! -f "$MANIFEST_IN_PROJECT" ]; then
    if [ -f "$KIT_DIR/manifest.example.yaml" ]; then
      cp "$KIT_DIR/manifest.example.yaml" "$MANIFEST_IN_PROJECT"
      echo -e "  ${GREEN}+${NC} Created saascode-kit.yaml from template"
      echo ""
      echo -e "  ${CYAN}Next steps:${NC}"
      echo "  1. Edit saascode-kit.yaml with your project details"
      echo "  2. Run npx kit init again"
      echo ""
      exit 0
    else
      echo -e "${RED}Error: manifest.example.yaml not found in kit${NC}"
      exit 1
    fi
  fi

  # Step 2: Manifest exists in project — copy it into kit dir so setup.sh can find it
  cp "$MANIFEST_IN_PROJECT" "$KIT_DIR/manifest.yaml"

  # Run setup
  bash "$KIT_DIR/setup.sh" "$TARGET"
}

# ─── Route command ───
export SAASCODE_KIT_DIR="$KIT_DIR"

COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  init)           cmd_init "$@" ;;
  help|--help|-h) show_help ;;
  *)
    # Delegate everything else to saascode.sh
    exec bash "$KIT_DIR/scripts/saascode.sh" "$COMMAND" "$@"
    ;;
esac
