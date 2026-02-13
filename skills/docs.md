# Skill: Documentation Organizer

> Trigger: /docs [feature-name|"full"|"init"]
> Purpose: Organize project documentation into standard SaaS structure

## Modes

- `/docs init` — Create docs structure from existing files + code
- `/docs full` — Full scan, deduplicate, restructure
- `/docs [feature]` — Single feature doc

## File Decision Rules

| Action | Files | Rule |
|--------|-------|------|
| **NEVER move** | `README.md`, `CONTRIBUTING.md`, `LICENSE`, `.github/*.md`, app-level `SETUP.md` | Serves its directory — stays in place |
| **MOVE to docs/** | Random `.md` in root, `.md` in non-standard locations, research docs | Orphaned knowledge → `docs/notes/` |
| **MERGE** | 2+ files covering same topic | Pick most complete as base, extract unique content, archive originals |
| **FLAG outdated** | References removed code/packages/endpoints, >6 months stale | Present to user — never auto-delete |
| **CONVERT** | `.txt` → `.md`, `.rst` → `.md`, inline README sections >50 lines | Convert format, move to `docs/notes/` |

**Never auto-delete.** Show overlaps, ask user which to keep.

## Execution

### Step 1: Scan

```bash
# All doc files
find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.next/*"
find . \( -name "*.txt" -o -name "*.rst" \) -not -path "*/node_modules/*" | grep -iv "license\|requirements\|package"

# Extract from code (always do this)
cat package.json */package.json 2>/dev/null

# Database schemas (framework-agnostic)
find . \( -name "*.schema.*" -o -name "schema.*" -o -name "*.prisma" \) -not -path "*/node_modules/*"

# API endpoints / routes (detect project type)
# If NestJS: scan controllers
grep -rn "@\(Get\|Post\|Put\|Patch\|Delete\|All\)\|@Controller" --include="*.controller.ts" 2>/dev/null
# If Express/Fastify: scan route files
find . \( -name "*.route.*" -o -name "*.routes.*" -o -name "router.*" \) -not -path "*/node_modules/*" 2>/dev/null

# Module/feature structure
find . -path "*/src/modules/*" -name "*.module.ts" -not -path "*/node_modules/*" 2>/dev/null
find . -path "*/src/*" \( -name "index.ts" -o -name "index.js" \) -not -path "*/node_modules/*" 2>/dev/null | head -20
```

### Step 2: Classify Every File

Build catalog — show to user before executing:

```markdown
| Action | From | To | Reason |
|--------|------|----|--------|
| KEEP | README.md | — | Root README |
| MOVE | random-notes.md | docs/notes/ | Orphaned |
| MERGE | auth.md + AUTH_NOTES.md | docs/security.md | Duplicate topic |
| OUTDATED | old-api.md | docs/_archive/outdated/ | References removed endpoints |
```

Wait for user confirmation before moving/merging.

### Step 3: Create Structure

```
docs/
├── architecture.md          # System design + tech stack
├── data-model.md            # DB schema + relations (Mermaid ER)
├── api-reference.md         # All endpoints by module
├── integrations.md          # Third-party services
├── security.md              # Auth model, guard chain
├── deployment.md            # Setup, environments, CI/CD
├── testing.md               # Strategy, how to run
├── features/                # One file per feature
│   └── _TEMPLATE.md
├── diagrams/mermaid/        # Text-based diagrams
├── notes/                   # Research, spikes, converted .txt
└── _archive/                # Safety net (duplicates/ + outdated/)
    ├── duplicates/_INDEX.md # What was merged, where, when
    └── outdated/_INDEX.md   # Why each file is outdated
```

Create only dirs that have content. Archived files go to `_archive/` with `_INDEX.md` tracking why.

### Step 4: Populate

**From existing files:** merge/move per catalog.
**From code (if no files):**
- `architecture.md` ← package.json + module structure + auth setup
- `data-model.md` ← schema files (Prisma, TypeORM, Mongoose, etc.) → Mermaid erDiagram
- `api-reference.md` ← controllers (NestJS), route files (Express/Fastify), or handler files
- `features/` ← one per backend module/feature directory
- `security.md` ← guard/middleware chain or auth middleware
- `integrations.md` ← third-party imports

### Step 5: Diagrams (Mermaid)

Auto-generate: system overview, auth flow, ER diagram, request lifecycle.
Inline when <20 lines, separate file when complex.

### Step 6: Execute

```bash
mkdir -p docs/notes docs/features docs/_archive/duplicates docs/_archive/outdated
git mv old/path/file.md docs/notes/file.md  # Preserve history
```

For merges: pick best file → extract unique content from others → archive originals.

### Step 7: Report

```markdown
## Docs Report
| Action | Count | Details |
|--------|-------|---------|
| Kept in place | X | README.md, etc |
| Moved | X | → docs/notes/, docs/features/ |
| Merged | X | Duplicates combined |
| Created from code | X | architecture.md, data-model.md, etc |
| Archived | X | → docs/_archive/ |
| Diagrams generated | X | Mermaid inline |
```

## Feature Template

```markdown
# Feature: [Name]
## Status: Draft | Active | Deprecated
## Overview: [2-3 sentences]
## Roles & Permissions
| Role | Access |
## API Endpoints
| Method | Route | Description | Roles |
## Data Model: [tables, fields, relations]
## Dependencies: [connected features/services]
## Edge Cases: [known quirks, limits]
```

## Rules

1. README stays where it is — never move
2. Duplicates get merged, not deleted — archive originals
3. Outdated files get flagged, not deleted — user decides
4. Code is documentation — generate from code if no files exist
5. `git mv` for moves — preserve history
6. Never delete without asking
