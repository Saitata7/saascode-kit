# FOR AI AGENTS — Comprehensive Reference Guide

> **📚 REFERENCE DOCUMENTATION**
> **Note:** Essential rules are auto-loaded in `CLAUDE.md`, `.cursorrules`, and `.windsurfrules`.
> **This file:** Detailed reference when you need more context.

## Quick Navigation

**Start here first (auto-loaded):**
- **Claude Code users** → Read `CLAUDE.md` in project (auto-loaded after `saascode init`)
- **Cursor users** → Read `.cursorrules` in repo root (auto-loaded automatically)
- **Windsurf users** → Read `.windsurfrules` in repo root (auto-loaded automatically)

**Read this file when:**
- You need detailed explanations
- Encountering complex scenarios
- Want to understand the "why" behind rules
- Need troubleshooting guidance

---

## Who This Is For

**You are:**
- An AI coding assistant (Claude Code, Cursor, Windsurf, Aider, etc.)
- Working on a SaaS project with saascode-kit installed
- Looking for detailed guidance beyond auto-loaded rules
- Wanting to understand best practices deeply

**This guide provides:**
- Detailed command documentation
- Complex scenario handling
- Anti-hallucination strategies
- Troubleshooting tips

---

## 🚨 Critical Rules

### 1. File Creation Policy

**❌ NEVER create without asking:**
- Documentation files (*.md) unless explicitly requested
- Test result files (use existing `tests/TEST-RESULTS.md`)
- Temporary analysis files
- Debug/log files in project root
- Duplicate functionality files

**✅ ALWAYS ask first:**
```
"Should I create [filename] for [purpose]?"
```

### 2. Update, Don't Duplicate

| Task | ❌ Wrong | ✅ Right |
|------|---------|---------|
| Document test results | Create TEST-CURSOR-RESULTS.md | Update tests/TEST-RESULTS.md |
| Save temp results | Create cursor-results.txt in root | Use tests/results.txt (gitignored) |
| Add new test | Create new-test-runner.sh | Update tests/run-tests.sh |
| Document capabilities | Create ANALYSIS.md | Update existing docs or ask first |

### 3. Validation Before Commit

**Always run before committing:**
```bash
bash scripts/validate-structure.sh
```

This detects:
- Unwanted documentation files
- Duplicate test results
- Temp/debug files
- Misplaced logs
- Non-script files in scripts/

---

## 📁 Directory Structure (DO NOT modify without permission)

```
saascode-kit/
├── scripts/              # Core scripts only (.sh, .ts, .py, .js)
├── templates/            # Template files only
├── hooks/                # Git hooks only
├── tests/                # Test infrastructure
│   ├── run-tests.sh      # Single test runner (don't create alternates)
│   ├── TEST-RESULTS.md   # Latest results (update this)
│   ├── CLAUDE-TEST-RESULTS.md  # Capabilities doc (don't duplicate)
│   ├── TEST-SCORECARD.md # Testing guide (reference only)
│   └── README.md         # Quick start
├── docs/                 # User documentation only
├── .cursorrules          # Cursor-specific constraints
└── AI-AGENT-GUIDELINES.md  # This file
```

---

## 🛡️ Anti-Hallucination Checklist

Before claiming something exists or works:

- [ ] **Verify the file exists** — Use Read or Bash ls first
- [ ] **Verify the function exists** — Use Grep to search for it
- [ ] **Verify the feature works** — Run a test, don't assume
- [ ] **Check git history** — Don't reference features that were removed
- [ ] **Read existing code** — Don't suggest patterns not used in codebase

---

## 🎯 Cursor-Specific Issues & Fixes

### Issue 1: Creating Unwanted MD Files

**Problem:** Cursor creates TEMP-*.md, ANALYSIS-*.md, TEST-CURSOR-*.md files.

**Fix:**
- Read `.cursorrules` before starting work
- Ask user before creating ANY .md file
- Use existing files for documentation

### Issue 2: Not Following Organization

**Problem:** Files created in wrong directories.

**Fix:**
- Check directory structure above before creating files
- Put scripts in scripts/, tests in tests/, docs in docs/
- When unsure, ask: "Should this go in [directory]?"

### Issue 3: Hallucinating Features

**Problem:** Referencing non-existent commands, files, or capabilities.

**Fix:**
- Use Grep to search before claiming something exists
- Read files before modifying them
- Test commands before documenting them

---

## ✅ Best Practices

### For Testing

```bash
# ✅ Right: Use existing runner
bash tests/run-tests.sh

# ✅ Right: Update existing results
# (Edit tests/TEST-RESULTS.md)

# ❌ Wrong: Create new runner
bash tests/cursor-test.sh  # Don't create this

# ❌ Wrong: Create duplicate results
tests/TEST-CURSOR-RESULTS-FEB-13.md  # Don't create this
```

### For Documentation

```bash
# ✅ Right: Update existing docs
# (Edit README.md, SETUP.md, CONTRIBUTING.md)

# ✅ Right: Ask first for new docs
"Should I create DEPLOYMENT.md for deployment instructions?"

# ❌ Wrong: Create without asking
CURSOR-ANALYSIS.md  # Don't create this
TESTING-NOTES.md    # Don't create this
```

### For Debugging

```bash
# ✅ Right: Use gitignored temp files
echo "debug output" > tests/results.txt  # Gitignored

# ✅ Right: Use stderr or temp directory
echo "debug" >&2
mktemp -d

# ❌ Wrong: Create debug files in root
debug-output.log  # Don't create this
TEMP-ANALYSIS.md  # Don't create this
```

---

## 🔧 Self-Check Questions

Before creating any file, ask yourself:

1. **Does this file already exist?** (Use Read/Grep to check)
2. **Is this the right directory?** (Check structure above)
3. **Will this be committed to git?** (If yes, extra caution needed)
4. **Did the user explicitly request this?** (If no, ask first)
5. **Is this duplicating existing functionality?** (Check for similar files)

---

## 📊 Success Metrics

**Good AI Agent Behavior:**
- ✅ Structure validation passes (`bash scripts/validate-structure.sh`)
- ✅ No duplicate test result files
- ✅ No unwanted MD files in root
- ✅ All created files serve clear purpose
- ✅ Git history is clean (no "cleanup" commits)

**Red Flags:**
- ❌ Multiple *-RESULTS.md files
- ❌ TEMP-*, DEBUG-*, ANALYSIS-* files
- ❌ Files in wrong directories
- ❌ Duplicate functionality
- ❌ User asks "why did you create this file?"

---

## 🚀 Quick Reference

| If you want to... | Do this... |
|-------------------|------------|
| Document test results | Update `tests/TEST-RESULTS.md` |
| Save temp data | Use `tests/results.txt` (gitignored) |
| Add a new test | Update `tests/run-tests.sh` |
| Document a feature | Update existing docs in `docs/` |
| Create a script | Add to `scripts/` (ask first) |
| Debug something | Use stderr or mktemp |
| Anything else | **Ask user first** |

---

## 💡 Remember

**When in doubt, ask the user.**

Creating unwanted files wastes everyone's time:
- User has to review and delete them
- Git history gets cluttered
- Structure validation fails
- Future AI agents get confused by the mess

**Be a good AI citizen:** Keep the codebase clean and organized! 🧹

---

**Last Updated:** February 13, 2026
**Tested With:** Claude Code (Sonnet 4.5), Cursor (Auto mode)
