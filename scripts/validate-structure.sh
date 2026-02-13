#!/bin/bash
# Validates saascode-kit directory structure
# Detects unwanted files created by AI agents

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ISSUES_FOUND=0

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  SaasCode Kit — Structure Validation                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check for unwanted MD files in root (excluding docs/ and tests/)
echo "→ Checking for unwanted documentation files..."
UNWANTED_MD=$(find . -maxdepth 2 -type f \( -name "TEMP*.md" -o -name "ANALYSIS*.md" -o -name "DEBUG*.md" \) ! -path "./tests/*" ! -path "./docs/*" ! -path "./node_modules/*" 2>/dev/null || true)

if [ -n "$UNWANTED_MD" ]; then
  echo -e "  ${RED}✗ Found unwanted MD files:${NC}"
  echo "$UNWANTED_MD" | sed 's/^/    /'
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
  echo -e "  ${GREEN}✓ No unwanted MD files${NC}"
fi

# Check for duplicate test result files in tests/
echo "→ Checking for duplicate test result files..."
EXPECTED_RESULTS="tests/TEST-RESULTS.md tests/TEST-SCORECARD.md tests/CLAUDE-TEST-RESULTS.md tests/README.md"
UNWANTED_RESULTS=$(find tests -maxdepth 1 -type f -name "*.md" 2>/dev/null | while read f; do
  EXPECTED=false
  for expected in $EXPECTED_RESULTS; do
    if [ "$f" = "$expected" ]; then
      EXPECTED=true
      break
    fi
  done
  if [ "$EXPECTED" = false ]; then
    echo "$f"
  fi
done)

if [ -n "$UNWANTED_RESULTS" ]; then
  echo -e "  ${RED}✗ Found unwanted result files:${NC}"
  echo "$UNWANTED_RESULTS" | sed 's/^/    /'
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
  echo -e "  ${GREEN}✓ No duplicate result files${NC}"
fi

# Check for temp/debug files
echo "→ Checking for temp/debug files..."
TEMP_FILES=$(find . -type f \( -name "temp-*" -o -name "debug-*" -o -name "test-output-*" -o -name "*.tmp" -o -name "TEMP*" \) ! -path "./node_modules/*" ! -path "./.git/*" ! -path "./tests/projects/*" 2>/dev/null || true)

if [ -n "$TEMP_FILES" ]; then
  echo -e "  ${YELLOW}⚠ Found temp files (may be ok):${NC}"
  echo "$TEMP_FILES" | sed 's/^/    /'
else
  echo -e "  ${GREEN}✓ No temp files${NC}"
fi

# Check for log files in wrong places
echo "→ Checking for misplaced log files..."
MISPLACED_LOGS=$(find . -maxdepth 2 -type f -name "*.log" ! -path "./tests/.archive/*" 2>/dev/null || true)

if [ -n "$MISPLACED_LOGS" ]; then
  echo -e "  ${YELLOW}⚠ Found log files:${NC}"
  echo "$MISPLACED_LOGS" | sed 's/^/    /'
  echo -e "    ${DIM}(Logs should be gitignored or in tests/.archive/)${NC}"
else
  echo -e "  ${GREEN}✓ No misplaced logs${NC}"
fi

# Check scripts/ for non-script files
echo "→ Checking scripts/ directory..."
NON_SCRIPTS=$(find scripts -type f ! -name "*.sh" ! -name "*.ts" ! -name "*.py" ! -name "*.js" ! -path "*/\__pycache__/*" 2>/dev/null || true)

if [ -n "$NON_SCRIPTS" ]; then
  echo -e "  ${YELLOW}⚠ Found non-script files in scripts/:${NC}"
  echo "$NON_SCRIPTS" | sed 's/^/    /'
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
  echo -e "  ${GREEN}✓ scripts/ contains only scripts${NC}"
fi

# Summary
echo ""
echo "════════════════════════════════════════════════════════════"
if [ $ISSUES_FOUND -eq 0 ]; then
  echo -e "${GREEN}✓ Structure validation passed${NC}"
  echo "No issues found. Directory structure is clean."
  exit 0
else
  echo -e "${RED}✗ Structure validation failed${NC}"
  echo "Found $ISSUES_FOUND issue(s). Please clean up unwanted files."
  echo ""
  echo "To clean up:"
  echo "  1. Review the files listed above"
  echo "  2. Delete unwanted files"
  echo "  3. Run this script again to verify"
  exit 1
fi
