#!/bin/bash
# SaasCode Kit — AST Code Review (wrapper)
# Runs the TypeScript AST review using ts-morph
# Usage: saascode review  OR  bash saascode-kit/scripts/ast-review.sh [--changed-only]

set -e

RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SCRIPT=""
for CANDIDATE in "$PROJECT_ROOT/.saascode/scripts/ast-review.ts" "$PROJECT_ROOT/saascode-kit/scripts/ast-review.ts"; do
  [ -f "$CANDIDATE" ] && SCRIPT="$CANDIDATE" && break
done

if [ -z "$SCRIPT" ]; then
  echo -e "${RED}ast-review.ts not found. Run: saascode init${NC}"
  exit 1
fi

# Check ts-morph is installed
if ! node -e "require('ts-morph')" 2>/dev/null; then
  echo -e "${RED}ts-morph not installed. Run: npm install --save-dev ts-morph${NC}"
  exit 1
fi

# Run with tsx (fast TypeScript execution)
if command -v npx &>/dev/null; then
  npx tsx "$SCRIPT" "$@"
else
  echo -e "${RED}npx not found. Install Node.js 18+${NC}"
  exit 1
fi
