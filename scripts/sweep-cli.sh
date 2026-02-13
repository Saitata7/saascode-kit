#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — Full Sweep
#
# Runs all checks in sequence: audit → predeploy → review
# Gives a combined pass/fail summary at the end.
#
# Usage:
#   saascode sweep                  # Run all checks (AST review)
#   saascode sweep --ai             # Use AI review instead of AST
#   saascode sweep --skip-review    # Skip review step
#   saascode sweep --skip-predeploy # Skip predeploy step
# ═══════════════════════════════════════════════════════════

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

# ─── Find project root ───
find_root() {
  local DIR="$PWD"
  while [ "$DIR" != "/" ]; do
    [ -d "$DIR/.git" ] && echo "$DIR" && return
    DIR="$(dirname "$DIR")"
  done
  echo "$PWD"
}

ROOT="$(find_root)"
export _LIB_ROOT="$ROOT"

# Source shared library
_LIB="$(dirname "$0")/lib.sh"
[ -f "$_LIB" ] || _LIB="$(cd "$(dirname "$0")/../.." && pwd)/saascode-kit/scripts/lib.sh"
if [ -f "$_LIB" ]; then
  source "$_LIB"
  MANIFEST=""
  for CANDIDATE in "$ROOT/saascode-kit/manifest.yaml" "$ROOT/.saascode/manifest.yaml" "$ROOT/manifest.yaml" "$ROOT/saascode-kit.yaml"; do
    [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
  done
  [ -n "$MANIFEST" ] && load_manifest_vars "$MANIFEST"
fi

SCRIPTS_DIR="$(dirname "$0")"
BE="${BACKEND_PATH:-apps/api}"
FE="${FRONTEND_PATH:-apps/portal}"

# ─── Parse arguments ───
USE_AI=false
SKIP_REVIEW=false
SKIP_PREDEPLOY=false
SHOW_HELP=false
REVIEW_ARGS=""

for arg in "$@"; do
  case "$arg" in
    --ai)             USE_AI=true ;;
    --skip-review)    SKIP_REVIEW=true ;;
    --skip-predeploy) SKIP_PREDEPLOY=true ;;
    --help|-h)        SHOW_HELP=true ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  echo ""
  echo "${BOLD}SaasCode Full Sweep${NC}"
  echo ""
  echo "Runs all checks: audit → predeploy → review"
  echo ""
  echo "Usage:"
  echo "  saascode sweep                  Run all checks (AST review)"
  echo "  saascode sweep --ai             Use AI-powered review"
  echo "  saascode sweep --skip-review    Skip the review step"
  echo "  saascode sweep --skip-predeploy Skip the predeploy step"
  echo ""
  exit 0
fi

# ─── State ───
STEPS_RUN=0
STEPS_PASSED=0
STEPS_WARNED=0
STEPS_FAILED=0
STEPS_SKIPPED=0

# ═══════════════════════════════════════
echo ""
echo "${BOLD}═══════════════════════════════════════════════${NC}"
echo "${BOLD}  SaasCode Full Sweep${NC}"
echo "${BOLD}═══════════════════════════════════════════════${NC}"
echo ""

SWEEP_START=$(date +%s)

# ─── Step 1: Full Audit ───
echo "${CYAN}${BOLD}[1/3] Full Audit${NC}"
echo "${DIM}─────────────────────────────────────────────${NC}"
AUDIT_EXIT=0
if [ -f "$SCRIPTS_DIR/full-audit.sh" ]; then
  bash "$SCRIPTS_DIR/full-audit.sh" "$BE" "$FE"
  AUDIT_EXIT=$?
else
  echo "  ${YELLOW}— Skipped (full-audit.sh not found)${NC}"
  AUDIT_EXIT=127
fi

if [ $AUDIT_EXIT -eq 0 ]; then
  STEPS_PASSED=$((STEPS_PASSED + 1))
elif [ $AUDIT_EXIT -eq 127 ]; then
  STEPS_SKIPPED=$((STEPS_SKIPPED + 1))
else
  STEPS_FAILED=$((STEPS_FAILED + 1))
fi
STEPS_RUN=$((STEPS_RUN + 1))

echo ""

# ─── Step 2: Pre-Deploy ───
echo "${CYAN}${BOLD}[2/3] Pre-Deploy Gates${NC}"
echo "${DIM}─────────────────────────────────────────────${NC}"
PREDEPLOY_EXIT=0
if [ "$SKIP_PREDEPLOY" = true ]; then
  echo "  ${YELLOW}— Skipped (--skip-predeploy)${NC}"
  PREDEPLOY_EXIT=127
  STEPS_SKIPPED=$((STEPS_SKIPPED + 1))
elif [ -f "$SCRIPTS_DIR/pre-deploy.sh" ]; then
  bash "$SCRIPTS_DIR/pre-deploy.sh" "$BE" "$FE"
  PREDEPLOY_EXIT=$?
  if [ $PREDEPLOY_EXIT -eq 0 ]; then
    STEPS_PASSED=$((STEPS_PASSED + 1))
  else
    STEPS_FAILED=$((STEPS_FAILED + 1))
  fi
else
  echo "  ${YELLOW}— Skipped (pre-deploy.sh not found)${NC}"
  PREDEPLOY_EXIT=127
  STEPS_SKIPPED=$((STEPS_SKIPPED + 1))
fi
STEPS_RUN=$((STEPS_RUN + 1))

echo ""

# ─── Step 3: Code Review ───
echo "${CYAN}${BOLD}[3/3] Code Review${NC}"
echo "${DIM}─────────────────────────────────────────────${NC}"
REVIEW_EXIT=0
if [ "$SKIP_REVIEW" = true ]; then
  echo "  ${YELLOW}— Skipped (--skip-review)${NC}"
  REVIEW_EXIT=127
  STEPS_SKIPPED=$((STEPS_SKIPPED + 1))
elif [ "$USE_AI" = true ]; then
  if [ -f "$SCRIPTS_DIR/ai-review.sh" ]; then
    bash "$SCRIPTS_DIR/ai-review.sh"
    REVIEW_EXIT=$?
    if [ $REVIEW_EXIT -eq 0 ]; then
      STEPS_PASSED=$((STEPS_PASSED + 1))
    else
      STEPS_FAILED=$((STEPS_FAILED + 1))
    fi
  else
    echo "  ${YELLOW}— Skipped (ai-review.sh not found)${NC}"
    REVIEW_EXIT=127
    STEPS_SKIPPED=$((STEPS_SKIPPED + 1))
  fi
else
  if [ -f "$SCRIPTS_DIR/ast-review.sh" ]; then
    bash "$SCRIPTS_DIR/ast-review.sh"
    REVIEW_EXIT=$?
    if [ $REVIEW_EXIT -eq 0 ]; then
      STEPS_PASSED=$((STEPS_PASSED + 1))
    else
      STEPS_FAILED=$((STEPS_FAILED + 1))
    fi
  else
    echo "  ${YELLOW}— Skipped (ast-review.sh not found)${NC}"
    REVIEW_EXIT=127
    STEPS_SKIPPED=$((STEPS_SKIPPED + 1))
  fi
fi
STEPS_RUN=$((STEPS_RUN + 1))

echo ""

# ─── Combined Summary ───
SWEEP_END=$(date +%s)
SWEEP_DURATION=$((SWEEP_END - SWEEP_START))

echo "${BOLD}═══════════════════════════════════════════════${NC}"
echo "${BOLD}  Sweep Summary${NC}"
echo "${BOLD}═══════════════════════════════════════════════${NC}"
echo ""

# Per-step results
_step_icon() {
  case "$1" in
    0)   echo "${GREEN}PASS${NC}" ;;
    127) echo "${YELLOW}SKIP${NC}" ;;
    *)   echo "${RED}FAIL${NC}" ;;
  esac
}

printf "  %-22s %b\n" "Full Audit" "$(_step_icon $AUDIT_EXIT)"
printf "  %-22s %b\n" "Pre-Deploy Gates" "$(_step_icon $PREDEPLOY_EXIT)"
printf "  %-22s %b\n" "Code Review" "$(_step_icon $REVIEW_EXIT)"
echo ""
echo "${DIM}  ─────────────────────────────────────────${NC}"
echo "  ${GREEN}Passed: $STEPS_PASSED${NC}  ${RED}Failed: $STEPS_FAILED${NC}  ${YELLOW}Skipped: $STEPS_SKIPPED${NC}"
echo "  ${DIM}Duration: ${SWEEP_DURATION}s${NC}"
echo ""

# Issue log hint
LOG_DIR="$ROOT/.saascode/logs"
TODAY=$(date -u +%Y-%m-%d)
if [ -f "$LOG_DIR/issues-${TODAY}.jsonl" ]; then
  ISSUE_COUNT=$(wc -l < "$LOG_DIR/issues-${TODAY}.jsonl" | tr -d '[:space:]')
  echo "  ${DIM}$ISSUE_COUNT issue(s) logged today → run: saascode-kit report${NC}"
  echo ""
fi

# Final verdict
if [ $STEPS_FAILED -gt 0 ]; then
  echo "  ${RED}${BOLD}SWEEP: FAILED${NC} — $STEPS_FAILED step(s) need attention"
  echo ""
  exit 1
elif [ $STEPS_PASSED -eq 0 ]; then
  echo "  ${YELLOW}${BOLD}SWEEP: INCOMPLETE${NC} — all steps skipped"
  echo ""
  exit 0
else
  echo "  ${GREEN}${BOLD}SWEEP: ALL CLEAR${NC}"
  echo ""
  exit 0
fi
