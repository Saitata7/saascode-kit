#!/bin/bash
# SaasCode Kit — Universal Test Runner
# Tests all commands against real-world projects
#
# Usage:
#   bash tests/run-tests.sh               # Run all projects (phased order)
#   bash tests/run-tests.sh 03-py-django  # Run single project
#   bash tests/run-tests.sh --command review  # Run single command across all projects

# Don't exit on error - we want to test all commands even if some fail
# set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"
RESULTS_FILE="$SCRIPT_DIR/results.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Test phases (smart sequencing)
PHASE1=(01-ts-nestjs-nextjs)
PHASE2=(03-py-django 04-java-spring)
PHASE3=(05-go-api 02-js-express 10-php-laravel)
PHASE4=(06-ts-chrome-ext 07-ts-vscode-ext 08-ts-react-native 09-ts-react-spa)
PHASE5=(11-rust-cli 12-c-project 13-static-html 14-py-datascience 15-ruby-rails 16-kotlin-android)

ALL_PROJECTS=("${PHASE1[@]}" "${PHASE2[@]}" "${PHASE3[@]}" "${PHASE4[@]}" "${PHASE5[@]}")

# Commands to test (in order)
COMMANDS=(init claude review parity check-file audit predeploy sweep report)

# Test single project
test_project() {
  local PROJECT_NAME="$1"
  local PROJECT_SRC="$PROJECTS_DIR/$PROJECT_NAME"

  if [ ! -d "$PROJECT_SRC" ]; then
    echo -e "${RED}✗ Project not found: $PROJECT_NAME${NC}"
    return 1
  fi

  echo -e "${CYAN}${BOLD}Testing: $PROJECT_NAME${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Create temp directory
  local TEMP_DIR=$(mktemp -d -t "saascode-test-$PROJECT_NAME-XXXX")
  trap "rm -rf $TEMP_DIR" EXIT

  # Copy project to temp (pristine original stays intact)
  echo -e "${DIM}→ Copying to temp: $TEMP_DIR${NC}"
  cp -R "$PROJECT_SRC/." "$TEMP_DIR/"
  cd "$TEMP_DIR"

  # Copy saascode-kit to temp directory
  echo -e "${DIM}→ Copying saascode-kit${NC}"
  cp -R "$KIT_DIR" "$TEMP_DIR/saascode-kit"

  # Generate minimal manifest
  echo -e "${DIM}→ Generating manifest.yaml${NC}"
  generate_manifest "$PROJECT_NAME" > "$TEMP_DIR/saascode-kit/manifest.yaml"

  # Run all 9 commands
  local SCORE=0
  local MAX_SCORE=18

  for CMD in "${COMMANDS[@]}"; do
    test_command "$CMD" "$PROJECT_NAME"
    local RESULT=$?
    SCORE=$((SCORE + RESULT))
  done

  echo ""
  echo -e "${BOLD}Project Score: $SCORE / $MAX_SCORE${NC}"
  echo "$PROJECT_NAME|$SCORE|$MAX_SCORE" >> "$RESULTS_FILE"

  cd "$SCRIPT_DIR"
}

# Test single command
test_command() {
  local CMD="$1"
  local PROJECT="$2"

  echo -e "\n${CYAN}[$CMD]${NC}"

  local OUTPUT_FILE=$(mktemp)
  local EXIT_CODE=0

  case "$CMD" in
    init)
      # Auto-answer "1" (install everything) to avoid interactive prompts
      echo "1" | bash saascode-kit/setup.sh . > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ] && [ -d ".saascode/scripts" ] && [ -f "CLAUDE.md" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — .saascode/ created, CLAUDE.md exists"
        rm "$OUTPUT_FILE"
        return 2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE or missing files"
        head -10 "$OUTPUT_FILE" | sed 's/^/    /'
        rm "$OUTPUT_FILE"
        return 0
      fi
      ;;

    claude)
      bash saascode-kit/scripts/saascode.sh claude > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ] && [ -f "CLAUDE.md" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — CLAUDE.md exists"
        rm "$OUTPUT_FILE"
        return 2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE or CLAUDE.md missing"
        head -10 "$OUTPUT_FILE" | sed 's/^/    /'
        rm "$OUTPUT_FILE"
        return 0
      fi
      ;;

    review)
      bash .saascode/scripts/ast-review.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      # PASS: finds findings (exit 1) or clean (exit 0) or graceful skip (exit 0 with message)
      # FAIL: crash (exit 2) or no output
      if grep -qi "not available\|skip" "$OUTPUT_FILE"; then
        echo -e "  ${YELLOW}SKIP${NC} (1 pt) — Graceful skip message"
        head -5 "$OUTPUT_FILE" | sed 's/^/    /'
        rm "$OUTPUT_FILE"
        return 1
      elif [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 1 ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — AST review ran"
        rm "$OUTPUT_FILE"
        return 2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Crashed with exit $EXIT_CODE"
        head -10 "$OUTPUT_FILE" | sed 's/^/    /'
        rm "$OUTPUT_FILE"
        return 0
      fi
      ;;

    parity)
      bash .saascode/scripts/endpoint-parity.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ] && [ -s "$OUTPUT_FILE" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — Parity check ran"
        rm "$OUTPUT_FILE"
        return 2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE or no output"
        head -10 "$OUTPUT_FILE" | sed 's/^/    /'
        rm "$OUTPUT_FILE"
        return 0
      fi
      ;;

    check-file)
      # Find a source file to test
      local TEST_FILE=$(find . -name "*.ts" -o -name "*.py" -o -name "*.java" -o -name "*.go" | grep -v node_modules | grep -v ".saascode" | head -1)
      if [ -z "$TEST_FILE" ]; then
        echo -e "  ${YELLOW}SKIP${NC} (1 pt) — No source files found"
        rm "$OUTPUT_FILE"
        return 1
      fi
      bash .saascode/scripts/check-file.sh "$TEST_FILE" > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ -s "$OUTPUT_FILE" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — check-file ran on $TEST_FILE"
        rm "$OUTPUT_FILE"
        return 2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — No output"
        rm "$OUTPUT_FILE"
        return 0
      fi
      ;;

    audit)
      bash .saascode/scripts/full-audit.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ -s "$OUTPUT_FILE" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — Audit ran"
        rm "$OUTPUT_FILE"
        return 2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — No output"
        rm "$OUTPUT_FILE"
        return 0
      fi
      ;;

    predeploy)
      bash .saascode/scripts/pre-deploy.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ -s "$OUTPUT_FILE" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — Predeploy ran"
        rm "$OUTPUT_FILE"
        return 2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — No output"
        rm "$OUTPUT_FILE"
        return 0
      fi
      ;;

    sweep)
      bash .saascode/scripts/sweep-cli.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if grep -q "Sweep Summary" "$OUTPUT_FILE"; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — Sweep produced summary"
        rm "$OUTPUT_FILE"
        return 2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — No summary"
        head -10 "$OUTPUT_FILE" | sed 's/^/    /'
        rm "$OUTPUT_FILE"
        return 0
      fi
      ;;

    report)
      bash .saascode/scripts/report-cli.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ] && [ -s "$OUTPUT_FILE" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — Report ran"
        rm "$OUTPUT_FILE"
        return 2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE or no output"
        rm "$OUTPUT_FILE"
        return 0
      fi
      ;;

    *)
      echo -e "  ${RED}ERROR${NC} — Unknown command: $CMD"
      rm "$OUTPUT_FILE"
      return 0
      ;;
  esac
}

# Generate minimal manifest based on project name
generate_manifest() {
  local PROJECT="$1"
  cat <<EOF
project:
  name: "Test-$PROJECT"
  type: "multi-tenant-saas"
  port: 4000
stack:
  language: "typescript"
  frontend:
    framework: "nextjs"
  backend:
    framework: "nestjs"
    orm: "prisma"
    database: "postgresql"
auth:
  provider: "clerk"
  multi_tenant: true
  guard_pattern: "decorator"
tenancy:
  enabled: true
  identifier: "tenantId"
paths:
  frontend: "apps/web"
  backend: "apps/api"
  api_client: "apps/web/src/lib/api"
ai:
  enabled: false
EOF
}

# Main execution
main() {
  echo -e "${BOLD}${CYAN}SaasCode Kit — Universal Test Suite${NC}"
  echo "══════════════════════════════════════════════"
  echo ""

  # Clear results file
  > "$RESULTS_FILE"

  # Check if specific project requested
  if [ $# -gt 0 ]; then
    test_project "$1"
  else
    # Run all projects in phased order
    echo -e "${BOLD}Phase 1: TypeScript Monorepo (deepest coverage)${NC}"
    for P in "${PHASE1[@]}"; do test_project "$P"; done

    echo -e "\n${BOLD}Phase 2: Python & Java (new AST reviewers)${NC}"
    for P in "${PHASE2[@]}"; do test_project "$P"; done

    echo -e "\n${BOLD}Phase 3: Graceful skip testing${NC}"
    for P in "${PHASE3[@]}"; do test_project "$P"; done

    echo -e "\n${BOLD}Phase 4: Extension/Mobile/SPA variants${NC}"
    for P in "${PHASE4[@]}"; do test_project "$P"; done

    echo -e "\n${BOLD}Phase 5: Out-of-scope projects${NC}"
    for P in "${PHASE5[@]}"; do test_project "$P"; done

    # Print summary
    echo ""
    echo "══════════════════════════════════════════════"
    echo -e "${BOLD}FINAL RESULTS${NC}"
    echo "══════════════════════════════════════════════"
    awk -F'|' '{sum+=$2; max+=$3} END {print "Total Score: " sum " / " max " (" int(sum*100/max) "%)"}' "$RESULTS_FILE"
    echo ""
    cat "$RESULTS_FILE"
  fi
}

main "$@"
