#!/bin/bash
# ═══════════════════════════════════════════════════════════
# SaasCode Kit — Cloak / Uncloak
#
# Stealth mode: removes all traces of saascode-kit from
# the project. Nobody can tell you're using it.
#
# Usage:
#   saascode-kit cloak                  # Activate stealth mode
#   saascode-kit cloak --name .devtools # Custom directory name
#   saascode-kit uncloak                # Reverse stealth mode
# ═══════════════════════════════════════════════════════════

set -e

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

# ─── Parse arguments ───
ACTION="${1:-cloak}"
shift 2>/dev/null || true

CLOAK_DIR=".devkit"
SHOW_HELP=false
NEXT_IS=""

for arg in "$@"; do
  if [ -n "$NEXT_IS" ]; then
    case "$NEXT_IS" in
      name) CLOAK_DIR="$arg" ;;
    esac
    NEXT_IS=""
    continue
  fi
  case "$arg" in
    --name|-n) NEXT_IS="name" ;;
    --help|-h) SHOW_HELP=true ;;
  esac
done

# Ensure cloak dir starts with dot
case "$CLOAK_DIR" in
  .*) ;; # already has dot
  *)  CLOAK_DIR=".$CLOAK_DIR" ;;
esac

CLOAK_BASE="${CLOAK_DIR#.}"  # "devkit" (without dot)

if [ "$SHOW_HELP" = true ]; then
  echo ""
  echo "${BOLD}SaasCode Kit — Stealth Mode${NC}"
  echo ""
  echo "Usage:"
  echo "  saascode-kit cloak                  Activate stealth mode (default: .devkit)"
  echo "  saascode-kit cloak --name .tools    Use custom directory name"
  echo "  saascode-kit uncloak                Reverse stealth mode"
  echo ""
  echo "What cloak does:"
  echo "  - Renames .saascode/ to your chosen name"
  echo "  - Strips all 'saascode' from tracked files"
  echo "  - Updates hooks, settings, gitignore, CI"
  echo "  - Removes branding from terminal output"
  echo "  - Stashes dev tool files (.claude/, .cursor/, .cursorrules, etc.)"
  echo "  - Nobody can tell you're using saascode-kit or any AI tools"
  echo ""
  exit 0
fi

# ═══════════════════════════════════════
# CLOAK
# ═══════════════════════════════════════
do_cloak() {
  echo ""
  echo "${BOLD}Activating stealth mode...${NC}"
  echo "${DIM}Replacing 'saascode' → '${CLOAK_BASE}' everywhere${NC}"
  echo ""

  local CHANGED=0

  # ─── Guard: already cloaked? ───
  if [ -f "$ROOT/$CLOAK_DIR/.cloak-state" ]; then
    echo "${YELLOW}Already cloaked as $CLOAK_DIR${NC}"
    exit 0
  fi
  if [ ! -d "$ROOT/.saascode" ]; then
    # Check if cloaked under another name
    for D in "$ROOT"/.*; do
      [ -f "$D/.cloak-state" ] && echo "${YELLOW}Already cloaked as $(basename "$D"). Run uncloak first.${NC}" && exit 1
    done
    echo "${YELLOW}.saascode/ directory not found. Run setup first.${NC}"
    exit 1
  fi

  # ─── 1. Rename directory ───
  mv "$ROOT/.saascode" "$ROOT/$CLOAK_DIR"
  echo "  ${GREEN}✓${NC} .saascode/ → $CLOAK_DIR/"
  CHANGED=$((CHANGED + 1))

  # ─── 2. Update scripts inside the renamed dir ───
  if [ -d "$ROOT/$CLOAK_DIR/scripts" ]; then
    for F in "$ROOT/$CLOAK_DIR/scripts"/*.sh; do
      [ -f "$F" ] || continue
      # Skip cloak-cli.sh — it needs hardcoded .saascode refs for uncloak
      [ "$(basename "$F")" = "cloak-cli.sh" ] && continue
      # Path references
      sed -i.bak \
        -e "s|\.saascode/|$CLOAK_DIR/|g" \
        -e "s|\.saascode|$CLOAK_DIR|g" \
        -e "s|saascode-kit/|$CLOAK_BASE/|g" \
        -e "s|saascode-kit|$CLOAK_BASE|g" \
        -e "s|saascode\.yml|ci-checks.yml|g" \
        -e "s|SaasCode Kit|$CLOAK_BASE|g" \
        -e "s|SaasCode|$CLOAK_BASE|g" \
        -e "s|saascode|$CLOAK_BASE|g" \
        "$F"
      rm -f "${F}.bak"
    done
    echo "  ${GREEN}✓${NC} Updated scripts in $CLOAK_DIR/scripts/"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 3. Update .claude/settings.json ───
  if [ -f "$ROOT/.claude/settings.json" ]; then
    sed -i.bak \
      -e "s|\.saascode/|$CLOAK_DIR/|g" \
      -e "s|\.saascode|$CLOAK_DIR|g" \
      "$ROOT/.claude/settings.json"
    rm -f "$ROOT/.claude/settings.json.bak"
    echo "  ${GREEN}✓${NC} .claude/settings.json"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 4. Update .gitignore ───
  if [ -f "$ROOT/.gitignore" ]; then
    sed -i.bak \
      -e "s|\.saascode/|$CLOAK_DIR/|g" \
      -e "s|\.saascode|$CLOAK_DIR|g" \
      -e "s|saascode-kit/|$CLOAK_BASE/|g" \
      -e "s|saascode-kit|$CLOAK_BASE|g" \
      -e "s|saascode|$CLOAK_BASE|g" \
      "$ROOT/.gitignore"
    rm -f "$ROOT/.gitignore.bak"
    echo "  ${GREEN}✓${NC} .gitignore"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 5. Update git hooks ───
  for HOOK in pre-commit pre-push; do
    if [ -f "$ROOT/.git/hooks/$HOOK" ]; then
      sed -i.bak \
        -e "s|\.saascode/|$CLOAK_DIR/|g" \
        -e "s|\.saascode|$CLOAK_DIR|g" \
        -e "s|saascode-kit/|$CLOAK_BASE/|g" \
        -e "s|saascode-kit|$CLOAK_BASE|g" \
        -e "s|saascode\.yml|ci-checks.yml|g" \
        -e "s|SaasCode Kit — ||g" \
        -e "s|SaasCode ||g" \
        "$ROOT/.git/hooks/$HOOK"
      rm -f "$ROOT/.git/hooks/$HOOK.bak"
      echo "  ${GREEN}✓${NC} .git/hooks/$HOOK"
      CHANGED=$((CHANGED + 1))
    fi
  done

  # ─── 6. Update CLAUDE.md ───
  if [ -f "$ROOT/CLAUDE.md" ]; then
    sed -i.bak \
      -e "s|\.saascode/|$CLOAK_DIR/|g" \
      -e "s|\.saascode|$CLOAK_DIR|g" \
      -e "s|SaasCode Kit|Development Kit|g" \
      -e "s|SaasCode|DevKit|g" \
      -e "s|saascode-kit|$CLOAK_BASE|g" \
      -e "s|saascode |$CLOAK_BASE |g" \
      "$ROOT/CLAUDE.md"
    rm -f "$ROOT/CLAUDE.md.bak"
    echo "  ${GREEN}✓${NC} CLAUDE.md"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 7. Update .cursorrules ───
  if [ -f "$ROOT/.cursorrules" ]; then
    sed -i.bak \
      -e "s|SaasCode Kit|Development Kit|g" \
      -e "s|SaasCode|DevKit|g" \
      -e "s|saascode-kit|$CLOAK_BASE|g" \
      -e "s|saascode|$CLOAK_BASE|g" \
      "$ROOT/.cursorrules"
    rm -f "$ROOT/.cursorrules.bak"
    echo "  ${GREEN}✓${NC} .cursorrules"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 8. Update .windsurfrules ───
  if [ -f "$ROOT/.windsurfrules" ]; then
    sed -i.bak \
      -e "s|SaasCode Kit|Development Kit|g" \
      -e "s|SaasCode|DevKit|g" \
      -e "s|saascode-kit|$CLOAK_BASE|g" \
      -e "s|saascode|$CLOAK_BASE|g" \
      "$ROOT/.windsurfrules"
    rm -f "$ROOT/.windsurfrules.bak"
    echo "  ${GREEN}✓${NC} .windsurfrules"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 9. Update .cursor/rules/ ───
  if [ -d "$ROOT/.cursor/rules" ]; then
    for F in "$ROOT/.cursor/rules"/*.mdc; do
      [ -f "$F" ] || continue
      sed -i.bak \
        -e "s|SaasCode Kit|Development Kit|g" \
        -e "s|SaasCode|DevKit|g" \
        -e "s|saascode-kit|$CLOAK_BASE|g" \
        -e "s|saascode|$CLOAK_BASE|g" \
        "$F"
      rm -f "${F}.bak"
    done
    echo "  ${GREEN}✓${NC} .cursor/rules/"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 10. Rename CI workflow ───
  if [ -f "$ROOT/.github/workflows/saascode.yml" ]; then
    mv "$ROOT/.github/workflows/saascode.yml" "$ROOT/.github/workflows/ci-checks.yml"
    echo "  ${GREEN}✓${NC} .github/workflows/saascode.yml → ci-checks.yml"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 11. Update saascode-kit.yaml filename if present ───
  if [ -f "$ROOT/saascode-kit.yaml" ]; then
    mv "$ROOT/saascode-kit.yaml" "$ROOT/manifest.yaml"
    echo "  ${GREEN}✓${NC} saascode-kit.yaml → manifest.yaml"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 12. Stash dev tool files ───
  # Move all AI/dev tool files into the cloaked dir so they're invisible
  local STASH="$ROOT/$CLOAK_DIR/.stashed"
  mkdir -p "$STASH"
  local STASHED_LIST=""

  # .claude/ directory (settings, skills, context)
  if [ -d "$ROOT/.claude" ]; then
    mv "$ROOT/.claude" "$STASH/dot-claude"
    STASHED_LIST="${STASHED_LIST}dot-claude=.claude\n"
    echo "  ${GREEN}✓${NC} .claude/ → stashed"
    CHANGED=$((CHANGED + 1))
  fi

  # .cursor/ directory (rules)
  if [ -d "$ROOT/.cursor" ]; then
    mv "$ROOT/.cursor" "$STASH/dot-cursor"
    STASHED_LIST="${STASHED_LIST}dot-cursor=.cursor\n"
    echo "  ${GREEN}✓${NC} .cursor/ → stashed"
    CHANGED=$((CHANGED + 1))
  fi

  # .cursorrules
  if [ -f "$ROOT/.cursorrules" ]; then
    mv "$ROOT/.cursorrules" "$STASH/dot-cursorrules"
    STASHED_LIST="${STASHED_LIST}dot-cursorrules=.cursorrules\n"
    echo "  ${GREEN}✓${NC} .cursorrules → stashed"
    CHANGED=$((CHANGED + 1))
  fi

  # .windsurfrules
  if [ -f "$ROOT/.windsurfrules" ]; then
    mv "$ROOT/.windsurfrules" "$STASH/dot-windsurfrules"
    STASHED_LIST="${STASHED_LIST}dot-windsurfrules=.windsurfrules\n"
    echo "  ${GREEN}✓${NC} .windsurfrules → stashed"
    CHANGED=$((CHANGED + 1))
  fi

  # CLAUDE.md
  if [ -f "$ROOT/CLAUDE.md" ]; then
    mv "$ROOT/CLAUDE.md" "$STASH/CLAUDE.md"
    STASHED_LIST="${STASHED_LIST}CLAUDE.md=CLAUDE.md\n"
    echo "  ${GREEN}✓${NC} CLAUDE.md → stashed"
    CHANGED=$((CHANGED + 1))
  fi

  # Save stash manifest
  printf '%b' "$STASHED_LIST" > "$STASH/.manifest"

  # ─── 13. Clean .gitignore of tool mentions ───
  if [ -f "$ROOT/.gitignore" ]; then
    # Remove lines mentioning dev tools (keep everything else)
    sed -i.bak \
      -e '/^\.claude/d' \
      -e '/^\.cursor/d' \
      -e '/^\.cursorrules/d' \
      -e '/^\.windsurfrules/d' \
      -e '/^CLAUDE\.md/d' \
      -e '/^# AI \/ Dev/d' \
      -e '/^# AI tool/d' \
      -e '/^# Claude Code/d' \
      -e '/^# Cursor config/d' \
      -e '/^# Windsurf config/d' \
      -e '/^# SaasCode/d' \
      -e '/^# saascode/d' \
      "$ROOT/.gitignore"
    rm -f "$ROOT/.gitignore.bak"
    echo "  ${GREEN}✓${NC} Cleaned tool mentions from .gitignore"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 14. Save cloak state ───
  cat > "$ROOT/$CLOAK_DIR/.cloak-state" << EOF
cloak_dir=$CLOAK_DIR
cloak_base=$CLOAK_BASE
original_dir=.saascode
cloaked_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
stashed=true
EOF
  echo "  ${GREEN}✓${NC} Saved state to $CLOAK_DIR/.cloak-state"

  echo ""
  echo "  ${GREEN}${BOLD}Stealth mode active. $CHANGED items updated.${NC}"
  echo ""
  echo "  ${DIM}No trace of saascode-kit or AI tools in your repo.${NC}"
  echo "  ${DIM}Dev files stashed in '$CLOAK_DIR/.stashed/'.${NC}"
  echo "  ${DIM}Everything still works — just under '$CLOAK_DIR/'.${NC}"
  echo "  ${DIM}To reverse: run the cloak script with 'uncloak'${NC}"
  echo ""
}

# ═══════════════════════════════════════
# UNCLOAK
# ═══════════════════════════════════════
do_uncloak() {
  echo ""
  echo "${BOLD}Deactivating stealth mode...${NC}"
  echo ""

  # Find the cloak state
  local STATE_FILE=""
  local CLOAKED_DIR=""
  local CLOAKED_BASE=""

  for D in "$ROOT"/.*; do
    if [ -f "$D/.cloak-state" ]; then
      STATE_FILE="$D/.cloak-state"
      CLOAKED_DIR="$(basename "$D")"
      break
    fi
  done

  if [ -z "$STATE_FILE" ]; then
    echo "${YELLOW}Not cloaked. Nothing to do.${NC}"
    exit 0
  fi

  # Read state
  CLOAKED_BASE=$(grep '^cloak_base=' "$STATE_FILE" | cut -d= -f2)

  local CHANGED=0

  # ─── 1. Update scripts — reverse replacements ───
  if [ -d "$ROOT/$CLOAKED_DIR/scripts" ]; then
    for F in "$ROOT/$CLOAKED_DIR/scripts"/*.sh; do
      [ -f "$F" ] || continue
      # Skip cloak-cli.sh — it has hardcoded refs that must stay intact
      [ "$(basename "$F")" = "cloak-cli.sh" ] && continue
      sed -i.bak \
        -e "s|$CLOAKED_DIR/|.saascode/|g" \
        -e "s|$CLOAKED_DIR|.saascode|g" \
        -e "s|${CLOAKED_BASE}/|saascode-kit/|g" \
        -e "s|ci-checks\.yml|saascode.yml|g" \
        -e "s|${CLOAKED_BASE}|saascode|g" \
        "$F"
      rm -f "${F}.bak"
    done
    echo "  ${GREEN}✓${NC} Restored scripts"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 2. Rename directory back ───
  rm -f "$ROOT/$CLOAKED_DIR/.cloak-state"
  mv "$ROOT/$CLOAKED_DIR" "$ROOT/.saascode"
  echo "  ${GREEN}✓${NC} $CLOAKED_DIR/ → .saascode/"
  CHANGED=$((CHANGED + 1))

  # ─── 3. Restore stashed dev tool files (before sed updates) ───
  local STASH="$ROOT/.saascode/.stashed"
  if [ -d "$STASH" ] && [ -f "$STASH/.manifest" ]; then
    while IFS='=' read -r STASH_NAME ORIG_NAME; do
      [ -z "$STASH_NAME" ] && continue
      if [ -d "$STASH/$STASH_NAME" ]; then
        if [ ! -e "$ROOT/$ORIG_NAME" ]; then
          mv "$STASH/$STASH_NAME" "$ROOT/$ORIG_NAME"
          echo "  ${GREEN}✓${NC} Restored $ORIG_NAME"
          CHANGED=$((CHANGED + 1))
        else
          echo "  ${YELLOW}—${NC} $ORIG_NAME already exists, skipped"
        fi
      elif [ -f "$STASH/$STASH_NAME" ]; then
        if [ ! -e "$ROOT/$ORIG_NAME" ]; then
          mv "$STASH/$STASH_NAME" "$ROOT/$ORIG_NAME"
          echo "  ${GREEN}✓${NC} Restored $ORIG_NAME"
          CHANGED=$((CHANGED + 1))
        else
          echo "  ${YELLOW}—${NC} $ORIG_NAME already exists, skipped"
        fi
      fi
    done < "$STASH/.manifest"
    rm -rf "$STASH"
    echo "  ${GREEN}✓${NC} Stash cleaned up"
  fi

  # ─── 4. Update .claude/settings.json ───
  if [ -f "$ROOT/.claude/settings.json" ]; then
    sed -i.bak \
      -e "s|$CLOAKED_DIR/|.saascode/|g" \
      -e "s|$CLOAKED_DIR|.saascode|g" \
      "$ROOT/.claude/settings.json"
    rm -f "$ROOT/.claude/settings.json.bak"
    echo "  ${GREEN}✓${NC} .claude/settings.json"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 5. Update .gitignore ───
  if [ -f "$ROOT/.gitignore" ]; then
    sed -i.bak \
      -e "s|$CLOAKED_DIR/|.saascode/|g" \
      -e "s|$CLOAKED_DIR|.saascode|g" \
      -e "s|${CLOAKED_BASE}/|saascode-kit/|g" \
      -e "s|${CLOAKED_BASE}|saascode|g" \
      "$ROOT/.gitignore"
    rm -f "$ROOT/.gitignore.bak"
    echo "  ${GREEN}✓${NC} .gitignore"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 6. Update git hooks ───
  for HOOK in pre-commit pre-push; do
    if [ -f "$ROOT/.git/hooks/$HOOK" ]; then
      sed -i.bak \
        -e "s|$CLOAKED_DIR/|.saascode/|g" \
        -e "s|$CLOAKED_DIR|.saascode|g" \
        -e "s|${CLOAKED_BASE}/|saascode-kit/|g" \
        -e "s|ci-checks\.yml|saascode.yml|g" \
        -e "s|${CLOAKED_BASE}|saascode|g" \
        "$ROOT/.git/hooks/$HOOK"
      rm -f "$ROOT/.git/hooks/$HOOK.bak"
      echo "  ${GREEN}✓${NC} .git/hooks/$HOOK"
      CHANGED=$((CHANGED + 1))
    fi
  done

  # ─── 7. Rename CI workflow back ───
  if [ -f "$ROOT/.github/workflows/ci-checks.yml" ]; then
    mv "$ROOT/.github/workflows/ci-checks.yml" "$ROOT/.github/workflows/saascode.yml"
    echo "  ${GREEN}✓${NC} ci-checks.yml → saascode.yml"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 8. Rename manifest back ───
  if [ -f "$ROOT/manifest.yaml" ] && ! [ -f "$ROOT/saascode-kit.yaml" ]; then
    echo "  ${DIM}—${NC} manifest.yaml left as-is (was saascode-kit.yaml)"
  fi

  # ─── 9. Fix path refs in restored dev tool files ───
  # Branding stays generic (user should re-run 'saascode-kit claude'/'cursor')
  # but path references (.devkit → .saascode) must be corrected
  if [ -f "$ROOT/CLAUDE.md" ]; then
    sed -i.bak \
      -e "s|$CLOAKED_DIR/|.saascode/|g" \
      -e "s|$CLOAKED_DIR|.saascode|g" \
      -e "s|${CLOAKED_BASE}/|saascode-kit/|g" \
      -e "s|${CLOAKED_BASE}|saascode|g" \
      "$ROOT/CLAUDE.md"
    rm -f "$ROOT/CLAUDE.md.bak"
    echo "  ${GREEN}✓${NC} CLAUDE.md (path refs fixed)"
    CHANGED=$((CHANGED + 1))
  fi

  if [ -f "$ROOT/.cursorrules" ]; then
    sed -i.bak \
      -e "s|${CLOAKED_BASE}/|saascode-kit/|g" \
      -e "s|${CLOAKED_BASE}|saascode|g" \
      "$ROOT/.cursorrules"
    rm -f "$ROOT/.cursorrules.bak"
    echo "  ${GREEN}✓${NC} .cursorrules (path refs fixed)"
    CHANGED=$((CHANGED + 1))
  fi

  if [ -f "$ROOT/.windsurfrules" ]; then
    sed -i.bak \
      -e "s|${CLOAKED_BASE}/|saascode-kit/|g" \
      -e "s|${CLOAKED_BASE}|saascode|g" \
      "$ROOT/.windsurfrules"
    rm -f "$ROOT/.windsurfrules.bak"
    echo "  ${GREEN}✓${NC} .windsurfrules (path refs fixed)"
    CHANGED=$((CHANGED + 1))
  fi

  if [ -d "$ROOT/.cursor/rules" ]; then
    for F in "$ROOT/.cursor/rules"/*.mdc; do
      [ -f "$F" ] || continue
      sed -i.bak \
        -e "s|${CLOAKED_BASE}/|saascode-kit/|g" \
        -e "s|${CLOAKED_BASE}|saascode|g" \
        "$F"
      rm -f "${F}.bak"
    done
    echo "  ${GREEN}✓${NC} .cursor/rules/ (path refs fixed)"
    CHANGED=$((CHANGED + 1))
  fi

  # ─── 10. Restore .gitignore tool entries ───
  if [ -f "$ROOT/.gitignore" ]; then
    # Add back standard dev tool entries if not present
    local NEEDS_TOOLS=false
    grep -q '\.claude/' "$ROOT/.gitignore" 2>/dev/null || NEEDS_TOOLS=true
    if [ "$NEEDS_TOOLS" = true ]; then
      cat >> "$ROOT/.gitignore" << 'GITIGNORE_TOOLS'

# AI / Dev tool configs
.claude/
.cursor/
.cursorrules
.windsurfrules
CLAUDE.md
GITIGNORE_TOOLS
      echo "  ${GREEN}✓${NC} Restored tool entries in .gitignore"
      CHANGED=$((CHANGED + 1))
    fi
  fi

  echo ""
  echo "  ${GREEN}${BOLD}Stealth mode deactivated. $CHANGED items restored.${NC}"
  echo ""
  echo "  ${YELLOW}Note: CLAUDE.md, .cursorrules, and .windsurfrules${NC}"
  echo "  ${YELLOW}have generic branding. Re-run 'saascode-kit claude'${NC}"
  echo "  ${YELLOW}or 'saascode-kit cursor' to restore full branding.${NC}"
  echo ""
}

# ─── Route ───
case "$ACTION" in
  cloak)   do_cloak ;;
  uncloak) do_uncloak ;;
  *)
    echo "${RED}Unknown action: $ACTION${NC}"
    echo "Usage: saascode-kit cloak | saascode-kit uncloak"
    exit 1
    ;;
esac
