# Test Suite

Universal test runner for saascode-kit — validates all commands against 16 real-world projects.

## Files in Git

| File | Purpose | In Git? |
|------|---------|---------|
| **TEST-SCORECARD.md** | Testing guide, rules, and project catalog | ✅ Yes |
| **TEST-RESULTS.md** | Test results snapshot (proves coverage) | ✅ Yes |
| **run-tests.sh** | Test runner script | ✅ Yes |
| **README.md** | This file | ✅ Yes |
| **projects/** | 16 test projects (22MB) | ❌ No (.gitignore) |
| **results.txt** | Temporary test results | ❌ No (.gitignore) |

## Running Tests

### Option 1: Use Your Own Projects

The test runner works with any project. Just point it at your codebase:

```bash
cd your-project
bash /path/to/saascode-kit/tests/run-tests.sh .
```

### Option 2: Download Test Fixtures

Test fixtures (16 projects, 22MB) are available separately to avoid bloating the git repo.

**Coming soon:** Download link for test-fixtures.zip

For now, you can create minimal test projects yourself following **TEST-SCORECARD.md**.

### Option 3: Skip Testing

The test suite is for contributors/maintainers. Regular users don't need to run tests — just use saascode-kit directly in your projects!

## Test Coverage (Last Run: Feb 13, 2026)

- **16 projects** — TypeScript, Python, Java, Go, JavaScript, PHP, Rust, C, Ruby, Kotlin, HTML
- **9 commands** per project — init, claude, review, parity, check-file, audit, predeploy, sweep, report
- **144 total executions** (16 projects × 9 commands)
- **281/288 score (97.6%)** — Grade A+ 🚀

See **TEST-RESULTS.md** for complete breakdown.
