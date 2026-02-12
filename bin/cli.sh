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

  echo ""
  echo -e "${BOLD}SaasCode Kit — Init${NC}"
  echo -e "${DIM}Kit source: $KIT_DIR${NC}"
  echo -e "${DIM}Target:     $TARGET${NC}"
  echo ""

  # Copy manifest if not present
  if [ ! -f "$KIT_DIR/manifest.yaml" ]; then
    if [ -f "$KIT_DIR/manifest.example.yaml" ]; then
      cp "$KIT_DIR/manifest.example.yaml" "$KIT_DIR/manifest.yaml"
      echo -e "  ${GREEN}+${NC} Created manifest.yaml from template"
      echo ""
      echo -e "  ${CYAN}Edit $KIT_DIR/manifest.yaml with your project details,${NC}"
      echo -e "  ${CYAN}then run this command again.${NC}"
      echo ""
      exit 0
    else
      echo -e "${RED}Error: manifest.example.yaml not found in kit${NC}"
      exit 1
    fi
  fi

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
