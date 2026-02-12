#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit CLI — Entry point for npx
#
# Usage:
#   npx saascode-kit init              # Set up kit in current project
#   npx saascode-kit init /path        # Set up kit in specific project
#   npx saascode-kit help              # Show help
# ═══════════════════════════════════════════════════════════

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

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
  echo "Usage:"
  echo "  npx saascode-kit init              Set up kit in current project"
  echo "  npx saascode-kit init /path        Set up kit in specific project"
  echo "  npx saascode-kit help              This help message"
  echo ""
  echo "What it does:"
  echo "  1. Copies manifest.example.yaml for you to configure"
  echo "  2. Runs interactive setup (choose IDE, components)"
  echo "  3. Installs scripts, rules, hooks, skills, CI"
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
      echo "  2. Run npx saascode-kit init again"
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
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  init)         cmd_init "$@" ;;
  help|--help|-h) show_help ;;
  *)
    echo -e "${RED}Unknown command: $COMMAND${NC}"
    echo ""
    show_help
    exit 1
    ;;
esac
