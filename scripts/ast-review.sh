#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — AST Code Review (language dispatcher)
# Routes to the correct AST reviewer based on project language.
#
# Usage: saascode review  OR  bash ast-review.sh [--changed-only]
#
# Supported languages:
#   typescript  → ast-review.ts (ts-morph)
#   python      → ast-review-python.py (stdlib ast)
#   java        → ast-review-java.sh (grep/awk)
#   javascript  → graceful skip (use check-file/audit)
#   go          → ast-review-go.sh (grep/awk)
#   ruby        → ast-review-ruby.sh (grep/awk)
# ═══════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# ── Resolve script directory ──
SCRIPT_DIR=""
for CANDIDATE in "$PROJECT_ROOT/.saascode/scripts" "$PROJECT_ROOT/saascode-kit/scripts"; do
  [ -d "$CANDIDATE" ] && SCRIPT_DIR="$CANDIDATE" && break
done

if [ -z "$SCRIPT_DIR" ]; then
  # Fall back to same directory as this script
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# ── Detect language from manifest ──
detect_language() {
  local MANIFEST=""
  for CANDIDATE in "$PROJECT_ROOT/saascode-kit/manifest.yaml" \
                   "$PROJECT_ROOT/.saascode/manifest.yaml" \
                   "$PROJECT_ROOT/manifest.yaml" \
                   "$PROJECT_ROOT/saascode-kit.yaml"; do
    [ -f "$CANDIDATE" ] && MANIFEST="$CANDIDATE" && break
  done

  if [ -n "$MANIFEST" ]; then
    local LANG
    LANG=$(awk '
      BEGIN { in_stack=0 }
      /^stack:/ { in_stack=1; next }
      /^[a-z]/ && !/^stack:/ { in_stack=0 }
      in_stack && /^  language:/ {
        val=$0; sub(/^[^:]+:[[:space:]]*/, "", val)
        sub(/[[:space:]]+#.*$/, "", val)
        gsub(/^"|"$/, "", val)
        print val; exit
      }
    ' "$MANIFEST")
    [ -n "$LANG" ] && echo "$LANG" && return
  fi

  # Auto-detect by file presence
  if [ -f "$PROJECT_ROOT/tsconfig.json" ] || find "$PROJECT_ROOT" -maxdepth 2 -name "tsconfig.json" -print -quit 2>/dev/null | grep -q .; then
    echo "typescript"
  elif [ -f "$PROJECT_ROOT/pom.xml" ] || find "$PROJECT_ROOT" -maxdepth 2 -name "pom.xml" -print -quit 2>/dev/null | grep -q .; then
    echo "java"
  elif [ -f "$PROJECT_ROOT/requirements.txt" ] || [ -f "$PROJECT_ROOT/manage.py" ] || [ -f "$PROJECT_ROOT/setup.py" ] || [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
    echo "python"
  elif [ -f "$PROJECT_ROOT/go.mod" ]; then
    echo "go"
  elif [ -f "$PROJECT_ROOT/Gemfile" ] || [ -f "$PROJECT_ROOT/config/routes.rb" ]; then
    echo "ruby"
  elif [ -f "$PROJECT_ROOT/package.json" ]; then
    # JS project (no tsconfig = not TypeScript)
    echo "javascript"
  else
    echo "typescript"  # Default fallback
  fi
}

# ── Parse --json / --sarif flags ──
OUTPUT_FORMAT="table"
PASS_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --json)  OUTPUT_FORMAT="json" ;;
    --sarif) OUTPUT_FORMAT="sarif" ;;
    *)       PASS_ARGS+=("$arg") ;;
  esac
done
set -- "${PASS_ARGS[@]}"
export SAASCODE_OUTPUT_FORMAT="$OUTPUT_FORMAT"

LANG=$(detect_language)

# ── Dispatch to language-specific reviewer ──
case "$LANG" in
  typescript)
    SCRIPT_TS=""
    for CANDIDATE in "$SCRIPT_DIR/ast-review.ts" "$PROJECT_ROOT/.saascode/scripts/ast-review.ts" "$PROJECT_ROOT/saascode-kit/scripts/ast-review.ts"; do
      [ -f "$CANDIDATE" ] && SCRIPT_TS="$CANDIDATE" && break
    done

    if [ -z "$SCRIPT_TS" ]; then
      echo -e "${RED}ast-review.ts not found. Run: saascode init${NC}"
      exit 1
    fi

    # Check ts-morph is installed
    if ! node -e "require('ts-morph')" 2>/dev/null; then
      echo -e "${RED}ts-morph not installed. Run: npm install --save-dev ts-morph${NC}"
      exit 1
    fi

    # Run with tsx
    if command -v npx &>/dev/null; then
      npx tsx "$SCRIPT_TS" "$@"
    else
      echo -e "${RED}npx not found. Install Node.js 18+${NC}"
      exit 1
    fi
    ;;

  python)
    SCRIPT_PY=""
    for CANDIDATE in "$SCRIPT_DIR/ast-review-python.py" "$PROJECT_ROOT/.saascode/scripts/ast-review-python.py" "$PROJECT_ROOT/saascode-kit/scripts/ast-review-python.py"; do
      [ -f "$CANDIDATE" ] && SCRIPT_PY="$CANDIDATE" && break
    done

    if [ -z "$SCRIPT_PY" ]; then
      echo -e "${RED}ast-review-python.py not found. Run: saascode init${NC}"
      exit 1
    fi

    if ! command -v python3 &>/dev/null; then
      echo -e "${RED}python3 not found. Install Python 3.8+${NC}"
      exit 1
    fi

    python3 "$SCRIPT_PY" "$@"
    ;;

  java)
    SCRIPT_JAVA=""
    for CANDIDATE in "$SCRIPT_DIR/ast-review-java.sh" "$PROJECT_ROOT/.saascode/scripts/ast-review-java.sh" "$PROJECT_ROOT/saascode-kit/scripts/ast-review-java.sh"; do
      [ -f "$CANDIDATE" ] && SCRIPT_JAVA="$CANDIDATE" && break
    done

    if [ -z "$SCRIPT_JAVA" ]; then
      echo -e "${RED}ast-review-java.sh not found. Run: saascode init${NC}"
      exit 1
    fi

    bash "$SCRIPT_JAVA" "$@"
    ;;

  javascript)
    echo -e "${CYAN}AST review is not available for JavaScript.${NC}"
    echo ""
    echo "JavaScript lacks the type information needed for deep AST analysis."
    echo "Use these alternatives instead:"
    echo "  saascode check-file <path>   Single-file validator"
    echo "  saascode audit               Full security + quality audit"
    echo "  saascode sweep               Run all checks"
    exit 0
    ;;

  go)
    SCRIPT_GO=""
    for CANDIDATE in "$SCRIPT_DIR/ast-review-go.sh" "$PROJECT_ROOT/.saascode/scripts/ast-review-go.sh" "$PROJECT_ROOT/saascode-kit/scripts/ast-review-go.sh"; do
      [ -f "$CANDIDATE" ] && SCRIPT_GO="$CANDIDATE" && break
    done

    if [ -z "$SCRIPT_GO" ]; then
      echo -e "${RED}ast-review-go.sh not found. Run: saascode init${NC}"
      exit 1
    fi

    bash "$SCRIPT_GO" "$@"
    ;;

  ruby)
    SCRIPT_RUBY=""
    for CANDIDATE in "$SCRIPT_DIR/ast-review-ruby.sh" "$PROJECT_ROOT/.saascode/scripts/ast-review-ruby.sh" "$PROJECT_ROOT/saascode-kit/scripts/ast-review-ruby.sh"; do
      [ -f "$CANDIDATE" ] && SCRIPT_RUBY="$CANDIDATE" && break
    done

    if [ -z "$SCRIPT_RUBY" ]; then
      echo -e "${RED}ast-review-ruby.sh not found. Run: saascode init${NC}"
      exit 1
    fi

    bash "$SCRIPT_RUBY" "$@"
    ;;

  *)
    echo -e "${YELLOW}AST review is not available for language: $LANG${NC}"
    echo ""
    echo "Supported languages: typescript, python, java, go, ruby"
    echo "Use 'saascode audit' or 'saascode check-file' for universal checks."
    exit 0
    ;;
esac
