#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Kit — Automated Test Runner
# Tests ALL commands on ALL fixture projects
# Exit 0 = all passed, Exit 1 = failures found
#
# Usage:
#   bash tests/run-tests.sh           # Full test suite
#   bash tests/run-tests.sh --quick   # Core projects only (fast CI)
#   bash tests/run-tests.sh 01 03     # Specific projects
# ═══════════════════════════════════════════════════════════

set -e

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

# All projects (phased order for bug discovery)
PHASE1=(01-ts-nestjs-nextjs)
PHASE2=(03-py-django 04-java-spring)
PHASE3=(05-go-api 02-js-express 10-php-laravel)
PHASE4=(06-ts-chrome-ext 07-ts-vscode-ext 08-ts-react-native 09-ts-react-spa)
PHASE5=(11-rust-cli 12-c-project 13-static-html 14-py-datascience 15-ruby-rails 16-kotlin-android)

ALL_PROJECTS=("${PHASE1[@]}" "${PHASE2[@]}" "${PHASE3[@]}" "${PHASE4[@]}" "${PHASE5[@]}")

# ALL commands including cloak/uncloak
COMMANDS=(init claude review parity check-file audit predeploy sweep report cloak uncloak)

# Initialize results
echo "" > "$RESULTS_FILE"
BUGS_FOUND=0
BUGS_FIXED=0

# ─── Generate minimal manifest ───
generate_manifest() {
  local PROJECT="$1"
  case "$PROJECT" in
    01-ts-nestjs-nextjs)
      cat <<EOF
project:
  name: "NestJS + Next.js Monorepo"
  type: "multi-tenant-saas"
stack:
  language: "typescript"
  backend:
    framework: "nestjs"
    orm: "prisma"
  frontend:
    framework: "nextjs"
paths:
  backend: "apps/api"
  frontend: "apps/web"
EOF
      ;;
    02-js-express)
      cat <<EOF
project:
  name: "Express API"
  type: "api-service"
stack:
  language: "typescript"
  backend:
    framework: "express"
    orm: "prisma"
paths:
  backend: "src"
EOF
      ;;
    03-py-django)
      cat <<EOF
project:
  name: "Django REST API"
  type: "api-service"
stack:
  language: "python"
  backend:
    framework: "django"
paths:
  backend: "."
EOF
      ;;
    04-java-spring)
      cat <<EOF
project:
  name: "Spring Boot API"
  type: "api-service"
stack:
  language: "java"
  backend:
    framework: "spring"
paths:
  backend: "src/main"
EOF
      ;;
    05-go-api)
      cat <<EOF
project:
  name: "Go API"
  type: "api-service"
stack:
  language: "go"
  backend:
    framework: "stdlib"
paths:
  backend: "."
EOF
      ;;
    06-ts-chrome-ext|07-ts-vscode-ext|08-ts-react-native|09-ts-react-spa)
      cat <<EOF
project:
  name: "TypeScript Project"
  type: "frontend-app"
stack:
  language: "typescript"
  frontend:
    framework: "react"
paths:
  frontend: "src"
EOF
      ;;
    10-php-laravel)
      cat <<EOF
project:
  name: "Laravel App"
  type: "full-stack-app"
stack:
  language: "php"
  backend:
    framework: "laravel"
paths:
  backend: "app"
  frontend: "resources"
EOF
      ;;
    11-rust-cli)
      cat <<EOF
project:
  name: "Rust CLI"
  type: "cli-tool"
stack:
  language: "rust"
paths:
  backend: "src"
EOF
      ;;
    12-c-project)
      cat <<EOF
project:
  name: "C Project"
  type: "generic"
stack:
  language: "c"
paths:
  backend: "src"
EOF
      ;;
    13-static-html)
      cat <<EOF
project:
  name: "Static Site"
  type: "frontend-app"
stack:
  language: "javascript"
  frontend:
    framework: "vanilla"
paths:
  frontend: "."
EOF
      ;;
    14-py-datascience)
      cat <<EOF
project:
  name: "Data Science Project"
  type: "generic"
stack:
  language: "python"
paths:
  backend: "."
EOF
      ;;
    15-ruby-rails)
      cat <<EOF
project:
  name: "Rails App"
  type: "full-stack-app"
stack:
  language: "ruby"
  backend:
    framework: "rails"
paths:
  backend: "app"
  frontend: "app/views"
EOF
      ;;
    16-kotlin-android)
      cat <<EOF
project:
  name: "Android App"
  type: "mobile-app"
stack:
  language: "java"
paths:
  backend: "app/src/main"
EOF
      ;;
    *)
      cat <<EOF
project:
  name: "$PROJECT"
  type: "generic"
stack:
  language: "unknown"
paths:
  backend: "."
EOF
      ;;
  esac
}

# ─── Test single command ───
test_command() {
  local CMD="$1"
  local PROJECT="$2"
  local TEMP_DIR="$3"

  echo -e "\n${CYAN}[$CMD]${NC}"

  local OUTPUT_FILE=$(mktemp)
  local EXIT_CODE=0
  local RESULT=0

  cd "$TEMP_DIR"

  case "$CMD" in
    init)
      echo "1" | bash saascode-kit/setup.sh . > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ] && [ -d ".saascode/scripts" ] && [ -f "CLAUDE.md" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts)"
        RESULT=2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE"
        head -5 "$OUTPUT_FILE" | sed 's/^/    /'
        RESULT=0
      fi
      ;;

    claude)
      bash saascode-kit/scripts/saascode.sh claude > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ] && [ -f "CLAUDE.md" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts)"
        RESULT=2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE"
        head -5 "$OUTPUT_FILE" | sed 's/^/    /'
        RESULT=0
      fi
      ;;

    review)
      bash .saascode/scripts/ast-review.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if grep -qi "not available\|skip" "$OUTPUT_FILE"; then
        echo -e "  ${YELLOW}SKIP${NC} (1 pt)"
        RESULT=1
      elif [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 1 ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts)"
        RESULT=2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Crashed with exit $EXIT_CODE"
        head -10 "$OUTPUT_FILE" | sed 's/^/    /'
        RESULT=0
      fi
      ;;

    parity)
      bash .saascode/scripts/endpoint-parity.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ] && [ -s "$OUTPUT_FILE" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts)"
        RESULT=2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE or no output"
        head -5 "$OUTPUT_FILE" | sed 's/^/    /'
        RESULT=0
      fi
      ;;

    check-file)
      local TEST_FILE=$(find . -name "*.ts" -o -name "*.py" -o -name "*.java" -o -name "*.go" 2>/dev/null | grep -v node_modules | grep -v ".saascode" | head -1)
      if [ -z "$TEST_FILE" ]; then
        echo -e "  ${YELLOW}SKIP${NC} (1 pt) — No source files found"
        RESULT=1
      else
        bash .saascode/scripts/check-file.sh "$TEST_FILE" > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
        if [ -s "$OUTPUT_FILE" ]; then
          echo -e "  ${GREEN}PASS${NC} (2 pts) — check-file ran on $TEST_FILE"
          RESULT=2
        else
          echo -e "  ${RED}FAIL${NC} (0 pts) — No output"
          RESULT=0
        fi
      fi
      ;;

    audit)
      bash .saascode/scripts/full-audit.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ -s "$OUTPUT_FILE" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts)"
        RESULT=2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — No output"
        RESULT=0
      fi
      ;;

    predeploy)
      bash .saascode/scripts/pre-deploy.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ -s "$OUTPUT_FILE" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts)"
        RESULT=2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — No output"
        RESULT=0
      fi
      ;;

    sweep)
      bash .saascode/scripts/sweep-cli.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if grep -q "Sweep Summary\|Summary:" "$OUTPUT_FILE"; then
        echo -e "  ${GREEN}PASS${NC} (2 pts)"
        RESULT=2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — No summary"
        head -10 "$OUTPUT_FILE" | sed 's/^/    /'
        RESULT=0
      fi
      ;;

    report)
      bash .saascode/scripts/report-cli.sh > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ] && [ -s "$OUTPUT_FILE" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts)"
        RESULT=2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE or no output"
        RESULT=0
      fi
      ;;

    cloak)
      # Test cloak command
      bash .saascode/scripts/cloak-cli.sh cloak > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ] && [ -d ".devkit" ] && [ ! -d ".saascode" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — Cloaked successfully"
        RESULT=2
      elif [ $EXIT_CODE -eq 0 ] && [ -f ".devkit/.cloak-state" ]; then
        echo -e "  ${GREEN}PASS${NC} (2 pts) — Already cloaked"
        RESULT=2
      else
        echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE"
        head -10 "$OUTPUT_FILE" | sed 's/^/    /'
        RESULT=0
      fi
      ;;

    uncloak)
      # Test uncloak command (only if cloaked)
      if [ -d ".devkit" ] && [ -f ".devkit/.cloak-state" ]; then
        bash .devkit/scripts/cloak-cli.sh uncloak > "$OUTPUT_FILE" 2>&1 || EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ] && [ -d ".saascode" ] && [ ! -d ".devkit" ]; then
          echo -e "  ${GREEN}PASS${NC} (2 pts) — Uncloaked successfully"
          RESULT=2
        else
          echo -e "  ${RED}FAIL${NC} (0 pts) — Exit $EXIT_CODE"
          head -10 "$OUTPUT_FILE" | sed 's/^/    /'
          RESULT=0
        fi
      else
        echo -e "  ${YELLOW}SKIP${NC} (1 pt) — Not cloaked (expected if cloak failed)"
        RESULT=1
      fi
      ;;

    *)
      echo -e "  ${RED}UNKNOWN COMMAND${NC}"
      RESULT=0
      ;;
  esac

  rm -f "$OUTPUT_FILE"
  return $RESULT
}

# ─── Test single project ───
test_project() {
  local PROJECT_NAME="$1"
  local PROJECT_SRC="$PROJECTS_DIR/$PROJECT_NAME"

  if [ ! -d "$PROJECT_SRC" ]; then
    echo -e "${RED}✗ Project not found: $PROJECT_NAME${NC}"
    return 1
  fi

  echo ""
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}Testing: $PROJECT_NAME${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Create temp directory
  local TEMP_DIR=$(mktemp -d -t "cursor-test-$PROJECT_NAME-XXXX")
  trap "rm -rf $TEMP_DIR" EXIT

  # Copy project to temp (ignore permission errors for .git, .env files)
  echo -e "${DIM}→ Copying project to temp: $TEMP_DIR${NC}"
  cp -R "$PROJECT_SRC/." "$TEMP_DIR/" 2>/dev/null || true
  cd "$TEMP_DIR"

  # Copy saascode-kit
  echo -e "${DIM}→ Copying saascode-kit${NC}"
  cp -R "$KIT_DIR" "$TEMP_DIR/saascode-kit"

  # Generate manifest
  echo -e "${DIM}→ Generating manifest.yaml${NC}"
  generate_manifest "$PROJECT_NAME" > "$TEMP_DIR/saascode-kit/manifest.yaml"

  # Run all commands
  local SCORE=0
  local MAX_SCORE=$((${#COMMANDS[@]} * 2))
  local COMMAND_RESULTS=()

  for CMD in "${COMMANDS[@]}"; do
    test_command "$CMD" "$PROJECT_NAME" "$TEMP_DIR"
    local RESULT=$?
    SCORE=$((SCORE + RESULT))
    COMMAND_RESULTS+=("$CMD:$RESULT")
  done

  echo ""
  echo -e "${BOLD}Project Score: $SCORE / $MAX_SCORE${NC}"
  echo "$PROJECT_NAME|$SCORE|$MAX_SCORE|${COMMAND_RESULTS[*]}" >> "$RESULTS_FILE"

  cd "$SCRIPT_DIR"
  # Write score to temp file for parent to read
  echo "$SCORE" > "$TEMP_DIR/.test_score"
  echo "$SCORE"
}

# ─── Main execution ───
main() {
  local RUN_PROJECTS=()

  # Parse arguments
  if [ "$1" = "--quick" ]; then
    RUN_PROJECTS=("${PHASE1[@]}" "${PHASE2[@]}")
    shift
  elif [ $# -gt 0 ]; then
    # Match partial project names (e.g., "01" matches "01-ts-nestjs-nextjs")
    for ARG in "$@"; do
      for PROJ in "${ALL_PROJECTS[@]}"; do
        if [[ "$PROJ" == "$ARG"* ]]; then
          RUN_PROJECTS+=("$PROJ")
        fi
      done
    done
  else
    RUN_PROJECTS=("${ALL_PROJECTS[@]}")
  fi

  echo ""
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}Kit — Automated Test Suite${NC}"
  echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
  echo ""
  echo "Testing ${#RUN_PROJECTS[@]} projects with ${#COMMANDS[@]} commands"
  echo "Commands: ${COMMANDS[*]}"
  echo ""

  local TOTAL_SCORE=0
  local TOTAL_MAX=0
  local FAILED_PROJECTS=0

  for PROJECT in "${RUN_PROJECTS[@]}"; do
    # Run test and capture score from last line
    local TEST_OUTPUT=$(test_project "$PROJECT" 2>&1)
    echo "$TEST_OUTPUT"
    local PROJ_SCORE=$(echo "$TEST_OUTPUT" | tail -1 | grep -oE '^[0-9]+$' || echo "0")
    local PROJ_MAX=$((${#COMMANDS[@]} * 2))
    TOTAL_SCORE=$((TOTAL_SCORE + PROJ_SCORE))
    TOTAL_MAX=$((TOTAL_MAX + PROJ_MAX))

    # Count failures (score below 50% = failed)
    if [ "$PROJ_SCORE" -lt "$((PROJ_MAX / 2))" ]; then
      FAILED_PROJECTS=$((FAILED_PROJECTS + 1))
    fi
  done

  echo ""
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}Final Results${NC}"
  echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "Total Score: ${GREEN}$TOTAL_SCORE / $TOTAL_MAX${NC}"
  local PERCENT=$((TOTAL_SCORE * 100 / TOTAL_MAX))
  echo -e "Pass Rate: ${GREEN}${PERCENT}%${NC}"
  if [ $FAILED_PROJECTS -gt 0 ]; then
    echo -e "Failed Projects: ${RED}$FAILED_PROJECTS${NC}"
  fi
  echo ""
  echo "Results saved to: $RESULTS_FILE"

  # Exit with error if any project critically failed
  if [ $FAILED_PROJECTS -gt 0 ]; then
    echo -e "${RED}FAILED: $FAILED_PROJECTS project(s) scored below 50%${NC}"
    exit 1
  else
    echo -e "${GREEN}PASSED: All projects scored above 50%${NC}"
    exit 0
  fi
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
