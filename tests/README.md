# Test Suite

Universal test runner for kit — validates all 11 commands against 16 real-world projects.

**AI-Friendly:** Works with Claude Code, Cursor, or any AI agent with shell access.

## Files

| File | Purpose | In Git? |
|------|---------|---------|
| **run-tests.sh** | Test runner (11 commands × 16 projects) | ✅ Yes |
| **TEST-RESULTS.md** | Latest test results & analysis | ✅ Yes |
| **TEST-SCORECARD.md** | Testing guide & project catalog | ✅ Yes |
| **README.md** | This file | ✅ Yes |
| **.gitignore** | Excludes test fixtures | ✅ Yes |
| **projects/** | 16 test projects (22MB) | ❌ No |
| **results.txt** | Temporary results | ❌ No |

## Running Tests

### Full Test Suite (All 16 Projects)

```bash
bash tests/run-tests.sh
```

Tests all 11 commands:
- `init`, `claude`, `review`, `parity`, `check-file`
- `audit`, `predeploy`, `sweep`, `report`
- `cloak`, `uncloak`

### Single Project Test

```bash
bash tests/run-tests.sh 03-py-django
```

### Test Your Own Project

```bash
cd your-project
bash /path/to/saascode-kit/tests/run-tests.sh .
```

## Test Fixtures

Test fixtures (16 projects, 22MB) are excluded from git to avoid bloat. You can:

1. **Use your own projects** — the test runner works with any codebase
2. **Download fixtures separately** — (link coming soon)
3. **Skip testing** — regular users don't need to run tests

## Latest Results (see TEST-RESULTS.md)

- **337/352 (95.7%)** — Grade A+
- **16 projects** — TS, Python, Java, Go, JS, PHP, Rust, C, Ruby, Kotlin, HTML
- **11 commands** tested per project
- **Zero crashes** across 176 test executions
- **100% cloak/uncloak success**

## For AI Agents (Claude, Cursor, etc.)

This test suite is designed to work with AI coding assistants:

- ✅ **Claude Code** — Full shell access, runs all tests
- ✅ **Cursor** — Auto mode tested, all commands work
- ✅ **Other AIs** — Any agent with bash/shell access can run tests

See **TEST-SCORECARD.md** for token-efficient testing rules ("one proof is enough").
