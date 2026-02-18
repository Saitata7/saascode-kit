---
name: changelog-generator
description: Generate CHANGELOG from git history with semantic versioning. Use when user says "changelog", "release notes", "what changed", or "/changelog". Do NOT use for commit messages or PR descriptions.
---

# Skill: Changelog Generator

> Trigger: /changelog [version|"unreleased"|"full"]
> Purpose: Auto-generate changelog from git history

**FIRST:** Read `.claude/context/project-map.md` for feature names and module structure.

## Modes

- `/changelog` or `/changelog unreleased` — Changes since last tag
- `/changelog [version]` — Entry for specific version
- `/changelog full` — Rebuild entire CHANGELOG.md

## Step 1: Gather Git History

```bash
git describe --tags --abbrev=0 2>/dev/null || echo "No tags found"
git tag --sort=-creatordate | head -10

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
if [ -n "$LAST_TAG" ]; then
  git log ${LAST_TAG}..HEAD --oneline --no-merges
else
  git log --oneline --no-merges -50
fi

git diff --stat ${LAST_TAG}..HEAD 2>/dev/null || git diff --stat HEAD~20..HEAD
```

## Step 2: Classify Commits

| Prefix/Pattern | Category |
|----------------|----------|
| `feat:`, `add`, `implement`, `new` | Added |
| `fix:`, `bugfix`, `resolve`, `patch` | Fixed |
| `breaking:`, `BREAKING CHANGE` | Breaking |
| `refactor:`, `restructure`, `clean` | Changed |
| `perf:`, `optimize`, `speed` | Improved |
| `docs:`, `readme` | Docs |
| `test:`, `spec`, `coverage` | Tests |
| `ci:`, `deploy`, `pipeline` | DevOps |
| `deps:`, `upgrade`, `bump` | Dependencies |
| `security:`, `vuln`, `cve` | Security |

Non-conventional commits: read the diff, classify manually.

## Step 3: Generate Entry

```markdown
## [version] - YYYY-MM-DD

### Added
- Feature description in plain language (#PR)

### Fixed
- Bug description — what was wrong and what's fixed now (#PR)

### Changed
- What changed and why (#PR)

### Breaking Changes
- What broke and how to migrate (#PR)
```

## Step 4: Update CHANGELOG.md

- Exists → prepend new entry after header
- Doesn't exist → create with Keep a Changelog header

## Step 5: Suggest Version

- Breaking changes → Major (1.0.0 → 2.0.0)
- New features → Minor (1.0.0 → 1.1.0)
- Bug fixes only → Patch (1.0.0 → 1.0.1)

Output: `Suggested version: vX.Y.Z` + `git tag -a vX.Y.Z -m "Release X.Y.Z"`

## Rules

1. User-facing language — "Added dark mode" not "Implemented theme context provider"
2. Every entry starts with a verb — Added, Fixed, Changed, Removed, Improved
3. Group related commits — 5 commits for one feature = 1 entry
4. Breaking changes get migration notes
5. Skip noise — CI tweaks, formatting, internal refactors
6. Link PRs/issues when available
7. Newest version first in CHANGELOG.md
