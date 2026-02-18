# Kit — Universal Test Scorecard

> Tests kit commands against 16 real-world projects covering every major stack.
> Goal: verify proper output, error messages, and graceful degradation for all project types.

---

## Testing Rules

### Rule 1: Don't Waste Tokens — One Proof Is Enough

If a command works (finds at least 1 error/warning/issue that satisfies its purpose), that proves the detection works. **Do NOT re-verify all findings.** Move on.

| Command | "It works" proof | Stop when |
|---------|-----------------|-----------|
| `init` | Exit 0, `.saascode/` created | Confirmed once |
| `claude` | CLAUDE.md exists with content | Confirmed once |
| `review` | Finds ≥1 finding (any severity) | First finding proves detection works |
| `parity` | Produces output (match or mismatch) | Any output = working |
| `check-file` | Returns result for the file | Any result = working |
| `audit` | Produces ≥1 line of audit output | Any output = working |
| `predeploy` | Runs gates, shows pass/skip/fail | Any gate output = working |
| `sweep` | Produces summary | Any summary = working |
| `report` | Shows issues or "no issues" | Any output = working |

For graceful skips (unsupported languages), verify the skip message appears once. Done.

### Rule 2: Fix-Confirm-Revert Cycle

```
For each project:
  1. COPY to temp dir (originals stay pristine)
  2. Add saascode-kit.yaml manifest
  3. Run all 9 commands
  4. If kit bug found:
     a. Fix bug in saascode-kit source
     b. Re-test SAME project in fresh temp copy
     c. Confirm fix works
  5. Record PASS/SKIP/FAIL in score sheet
  6. DELETE temp copy
  7. Move to next project
```

**Why keep originals pristine:**
- Can re-test with different kit versions
- Can re-test with Cursor, Windsurf, or other tools
- Can run the full suite again after bulk fixes
- No "works on my machine" — always starts from clean clone

### Rule 3: Test Order — Smart Sequencing

Test projects in this order to maximize early bug discovery:

| Phase | Projects | Why first |
|-------|----------|-----------|
| **Phase 1** | `01-ts-nestjs-nextjs` | Deepest coverage — TS monorepo exercises ALL commands fully. Most likely to find kit bugs. |
| **Phase 2** | `03-py-django`, `04-java-spring` | New AST reviewers — untested code, highest bug probability. |
| **Phase 3** | `05-go-api`, `02-js-express`, `10-php-laravel` | Graceful skip testing — verify "not available" messages. |
| **Phase 4** | `06-chrome`, `07-vscode`, `08-react-native`, `09-react-spa` | Extension/mobile/SPA variants — less likely to have new bugs if Phase 1 TS passed. |
| **Phase 5** | `11-rust`, `12-c`, `13-html`, `14-jupyter`, `15-rails`, `16-kotlin` | Out-of-scope projects — pure negative testing. Should all gracefully skip. |

**Rationale:** Fix all bugs in Phase 1-2, so Phase 3-5 are mostly just confirmation runs.

### Rule 4: Fail Fast, Batch Fix

- If a command fails on Project 01, **don't test it on Project 02-16 yet**
- Fix the bug first, re-confirm on 01, then continue
- This prevents 16 identical failures for the same bug

### Rule 5: What Counts as a Bug vs Expected Behavior

| Situation | Bug or Expected? | Action |
|-----------|-------------------|--------|
| Command crashes with stack trace | **BUG** | Fix immediately |
| Command exits non-zero unexpectedly | **BUG** | Fix immediately |
| Command produces no output at all | **BUG** | Fix immediately |
| Command shows wrong language detection | **BUG** | Fix in ast-review.sh dispatcher |
| "AST review not available for Go" | **EXPECTED** | Score as SKIP (1 point) |
| "SKIP: npm not found" during audit | **EXPECTED** | Score as SKIP (1 point) |

### Rule 6: File Creation & Organization (CRITICAL for AI Agents)

**❌ DO NOT CREATE:**
- Extra documentation files (TEMP-*.md, ANALYSIS-*.md, DEBUG-*.md, etc.)
- Duplicate test result files (TEST-CURSOR-RESULTS.md, etc. — use existing TEST-RESULTS.md)
- Temporary analysis files in project root
- Log files outside of tests/.archive/
- Any file not explicitly requested by user

**✅ UPDATE EXISTING FILES ONLY:**
- Update `tests/TEST-RESULTS.md` with new test run data
- Update `tests/results.txt` (temp file, will be gitignored)
- Use `tests/run-tests.sh` (don't create new test runners)

**🔍 Validation:**
```bash
bash scripts/validate-structure.sh  # Run before committing to catch unwanted files
```

**Why this matters:**
- Prevents file bloat (we had 11 files, now have 5 clean files)
- Keeps git history clean
- Follows "single source of truth" principle
- Makes codebase navigable for users

**If in doubt:** Ask user before creating ANY new file.
| Review finds 0 issues on clean code | **EXPECTED** | Score as PASS (2 points) |
| Predeploy skips build (no build tool) | **EXPECTED** | Score as SKIP (1 point) |

---

## Project Inventory

| # | Dir Name | Language | Type | Source Repo | Has FE+BE |
|---|----------|----------|------|-------------|-----------|
| 01 | `01-ts-nestjs-nextjs` | TypeScript | NestJS + Next.js monorepo | ejazahm3d/fullstack-turborepo-starter | Yes |
| 02 | `02-js-express` | TypeScript* | Express + Prisma | gothinkster/node-express-realworld-example-app | Backend only** |
| 03 | `03-py-django` | Python | Django REST | gothinkster/django-realworld-example-app | Backend only |
| 04 | `04-java-spring` | Java | Spring Boot + Gradle | gothinkster/spring-boot-realworld-example-app | Backend only |
| 05 | `05-go-api` | Go | stdlib HTTP + GORM | mingrammer/go-todo-rest-api-example | Backend only |
| 06 | `06-ts-chrome-ext` | TypeScript | Chrome Extension (MV3) | chibat/chrome-extension-typescript-starter | Frontend only |
| 07 | `07-ts-vscode-ext` | TypeScript | VS Code Extension | microsoft/vscode-extension-samples | Frontend only |
| 08 | `08-ts-react-native` | TypeScript | React Native / Expo | obytes/react-native-template-obytes | Mobile only |
| 09 | `09-ts-react-spa` | TypeScript | React + Vite SPA | bartstc/vite-ts-react-template | Frontend only |
| 10 | `10-php-laravel` | PHP | Laravel + Blade | gothinkster/laravel-realworld-example-app | Yes |
| 11 | `11-rust-cli` | Rust | CLI tool (Clap) | alfredodeza/rust-cli-example | Backend only |
| 12 | `12-c-project` | C | Chat server (sockets) | antirez/smallchat | Backend only |
| 13 | `13-static-html` | HTML/CSS/JS | Static website | yenchiah/project-website-template | Frontend only |
| 14 | `14-py-datascience` | Python | Jupyter notebooks | rhiever/Data-Analysis-and-ML-Projects | Notebooks |
| 15 | `15-ruby-rails` | Ruby | Rails full-stack app | learnenough/rails_tutorial_7th_ed | Yes |
| 16 | `16-kotlin-android` | Kotlin | Android native app | csells/min-kotlin-android | Mobile only |

\* Project 02 has tsconfig.json + TypeScript source despite being listed as "JS Express"
\** Some projects have only backend or only frontend — parity check should gracefully skip

---

## Test Categories

### Category A: Supported SaaS Projects (expect full functionality)
Projects: **01, 02, 03, 04, 05, 06, 07, 08, 09, 10**

### Category B: Out-of-Scope Projects (expect graceful degradation)
Projects: **11 (Rust), 12 (C), 13 (Static HTML), 14 (Jupyter), 15 (Ruby), 16 (Kotlin Android)**

---

## Command-by-Command Test Matrix

### `saascode init`

| # | Project | Expected Behavior | Expected Exit | Pass Criteria |
|---|---------|-------------------|---------------|---------------|
| 01 | ts-nestjs-nextjs | Full setup, all components installed | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 02 | js-express | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 03 | py-django | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 04 | java-spring | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 05 | go-api | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 06 | ts-chrome-ext | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 07 | ts-vscode-ext | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 08 | ts-react-native | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 09 | ts-react-spa | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 10 | php-laravel | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 11 | rust-cli | Full setup (generic) | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 12 | c-project | Full setup (generic) | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 13 | static-html | Full setup (generic) | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 14 | py-datascience | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 15 | ruby-rails | Full setup | 0 | `.saascode/scripts/` created, CLAUDE.md exists |
| 16 | kotlin-android | Full setup (generic) | 0 | `.saascode/scripts/` created, CLAUDE.md exists |

**Key test:** `init` should NEVER crash regardless of project type.

---

### `saascode claude`

| # | Project | Expected Behavior | Expected Exit | Pass Criteria |
|---|---------|-------------------|---------------|---------------|
| 01 | ts-nestjs-nextjs | Generates CLAUDE.md with project name | 0 | CLAUDE.md contains project name from manifest |
| 02 | js-express | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 03 | py-django | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 04 | java-spring | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 05 | go-api | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 06 | ts-chrome-ext | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 07 | ts-vscode-ext | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 08 | ts-react-native | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 09 | ts-react-spa | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 10 | php-laravel | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 11 | rust-cli | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 12 | c-project | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 13 | static-html | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 14 | py-datascience | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 15 | ruby-rails | Generates CLAUDE.md | 0 | CLAUDE.md exists |
| 16 | kotlin-android | Generates CLAUDE.md | 0 | CLAUDE.md exists |

**Key test:** `claude` should NEVER crash. Must work even without manifest (uses defaults).

---

### `saascode review` (AST Review)

| # | Project | Language Detected | Expected Behavior | Expected Exit | Expected Message |
|---|---------|-------------------|-------------------|---------------|------------------|
| 01 | ts-nestjs-nextjs | typescript | Runs ts-morph AST review | 0 or 1 | Table with findings OR "APPROVE" |
| 02 | js-express | typescript* | Runs ts-morph (has tsconfig) | 0 or 1 | Table with findings OR "APPROVE" |
| 03 | py-django | python | **Runs Python AST review** | 0 or 1 | Table with findings OR "APPROVE" |
| 04 | java-spring | java | **Runs Java AST review** | 0 or 1 | Table with findings OR "APPROVE" |
| 05 | go-api | go | **Graceful skip** | 0 | "AST review is not available for Go" |
| 06 | ts-chrome-ext | typescript | Runs ts-morph | 0 or 1 | Table with findings OR "APPROVE" |
| 07 | ts-vscode-ext | typescript | Runs ts-morph | 0 or 1 | Table with findings OR "APPROVE" |
| 08 | ts-react-native | typescript | Runs ts-morph | 0 or 1 | Table with findings OR "APPROVE" |
| 09 | ts-react-spa | typescript | Runs ts-morph | 0 or 1 | Table with findings OR "APPROVE" |
| 10 | php-laravel | php | **Graceful skip** | 0 | "AST review is not available for language: php" |
| 11 | rust-cli | rust | **Graceful skip** | 0 | "AST review is not available for language: rust" |
| 12 | c-project | c/unknown | **Graceful skip** | 0 | "AST review is not available for language: ..." |
| 13 | static-html | unknown | **Graceful skip or TS fallback** | 0 | Skip message OR ts-morph attempt |
| 14 | py-datascience | python | Runs Python AST (skips notebooks) | 0 | "APPROVE" or "No Python files found" |
| 15 | ruby-rails | ruby | **Graceful skip** | 0 | "AST review is not available for language: ruby" |
| 16 | kotlin-android | kotlin | **Graceful skip** | 0 | "AST review is not available for language: kotlin" |

**Key tests:**
- TS/PY/Java projects: runs correct language-specific reviewer
- Unsupported languages: shows helpful "not available for {lang}" message with alternatives
- NEVER crashes, NEVER shows raw stack trace

---

### `saascode parity` (Frontend-Backend Endpoint Parity)

| # | Project | Has FE+BE | Expected Behavior | Expected Exit | Expected Message |
|---|---------|-----------|-------------------|---------------|------------------|
| 01 | ts-nestjs-nextjs | Yes | Checks endpoint parity | 0 | Finds matches/mismatches |
| 02 | js-express | BE only | Runs but finds no frontend | 0 | "no frontend" or partial results |
| 03 | py-django | BE only | Runs but finds no frontend | 0 | "no frontend" or partial results |
| 04 | java-spring | BE only | Runs but finds no frontend | 0 | "no frontend" or partial results |
| 05 | go-api | BE only | Runs but finds no frontend | 0 | "no frontend" or partial results |
| 06 | ts-chrome-ext | FE only | Runs but finds no backend | 0 | "no backend" or partial results |
| 07 | ts-vscode-ext | FE only | Runs but finds no backend | 0 | "no backend" or partial results |
| 08 | ts-react-native | Mobile | Runs but finds no backend | 0 | "no backend" or partial results |
| 09 | ts-react-spa | FE only | Runs but finds no backend | 0 | "no backend" or partial results |
| 10 | php-laravel | Yes | Checks endpoint parity | 0 | Finds matches/mismatches |
| 11 | rust-cli | CLI | No web endpoints | 0 | "no endpoints found" or skip |
| 12 | c-project | C app | No web endpoints | 0 | "no endpoints found" or skip |
| 13 | static-html | Static | No dynamic endpoints | 0 | "no endpoints found" or skip |
| 14 | py-datascience | Notebooks | No web endpoints | 0 | "no endpoints found" or skip |
| 15 | ruby-rails | Yes | Checks endpoint parity | 0 | Finds matches/mismatches |
| 16 | kotlin-android | Mobile | No web endpoints | 0 | "no endpoints found" or skip |

**Key test:** Parity should NEVER crash on projects without frontend/backend. Must handle gracefully.

---

### `saascode check-file`

| # | Project | Test File | Expected Behavior | Expected Exit |
|---|---------|-----------|-------------------|---------------|
| 01 | ts-nestjs-nextjs | Any `.ts` file | Finds issues or clean | 0 or non-zero |
| 02 | js-express | Any `.ts` file | Finds issues or clean | 0 or non-zero |
| 03 | py-django | Any `.py` file | Finds issues (debug stmts, etc.) | 0 or non-zero |
| 04 | java-spring | Any `.java` file | Finds issues or clean | 0 or non-zero |
| 05 | go-api | `main.go` | Finds issues or clean | 0 or non-zero |
| 06 | ts-chrome-ext | Any `.ts` file | Finds issues or clean | 0 or non-zero |
| 07 | ts-vscode-ext | Any `.ts` file | Finds issues or clean | 0 or non-zero |
| 08 | ts-react-native | Any `.tsx` file | Finds issues or clean | 0 or non-zero |
| 09 | ts-react-spa | Any `.tsx` file | Finds issues or clean | 0 or non-zero |
| 10 | php-laravel | Any `.php` file | Finds issues or clean | 0 or non-zero |
| 11 | rust-cli | `src/main.rs` | Finds issues or clean | 0 or non-zero |
| 12 | c-project | `smallchat-server.c` | Finds issues or clean | 0 or non-zero |
| 13 | static-html | `index.html` | Finds issues or clean | 0 or non-zero |
| 14 | py-datascience | Any `.py` file | Finds issues or clean | 0 or non-zero |
| 15 | ruby-rails | Any `.rb` file | Finds issues or clean | 0 or non-zero |
| 16 | kotlin-android | Any `.kt` file | Finds issues or clean | 0 or non-zero |

**Key test:** `check-file` should handle ALL file extensions. Never crash on unknown types.

---

### `saascode audit`

| # | Project | Expected Behavior | Expected Exit | Pass Criteria |
|---|---------|-------------------|---------------|---------------|
| 01 | ts-nestjs-nextjs | Full audit (npm audit, secrets, debug) | 0 | Produces output, no crash |
| 02 | js-express | Full audit | 0 | Produces output, no crash |
| 03 | py-django | Audit (pip-audit or skip, secrets, debug) | 0 | Produces output, no crash |
| 04 | java-spring | Audit (OWASP or skip, secrets, debug) | 0 | Produces output, no crash |
| 05 | go-api | Audit (govulncheck or skip, secrets) | 0 | Produces output, no crash |
| 06 | ts-chrome-ext | Full audit | 0 | Produces output, no crash |
| 07 | ts-vscode-ext | Full audit | 0 | Produces output, no crash |
| 08 | ts-react-native | Full audit | 0 | Produces output, no crash |
| 09 | ts-react-spa | Full audit | 0 | Produces output, no crash |
| 10 | php-laravel | Audit (composer audit or skip) | 0 | Produces output, no crash |
| 11 | rust-cli | Audit (cargo audit or skip) | 0 | Produces output, no crash |
| 12 | c-project | Minimal audit (secrets, debug only) | 0 | Produces output, no crash |
| 13 | static-html | Minimal audit | 0 | Produces output, no crash |
| 14 | py-datascience | Audit (secrets, debug) | 0 | Produces output, no crash |
| 15 | ruby-rails | Audit (bundle-audit or skip) | 0 | Produces output, no crash |
| 16 | kotlin-android | Audit (secrets, debug) | 0 | Produces output, no crash |

**Key test:** Audit should skip unavailable scanners gracefully (e.g., "SKIP: pip-audit not found").

---

### `saascode predeploy`

| # | Project | Expected Behavior | Expected Exit | Pass Criteria |
|---|---------|-------------------|---------------|---------------|
| 01 | ts-nestjs-nextjs | Runs all gates (build, test, audit) | 0 | Produces output, no crash |
| 02 | js-express | Runs gates, skips missing tools | 0 | Produces output, no crash |
| 03 | py-django | Runs Python gates | 0 | Produces output, no crash |
| 04 | java-spring | Runs Java gates (mvn/gradle) | 0 | Produces output, no crash |
| 05 | go-api | Runs Go gates (go build, go vet) | 0 | Produces output, no crash |
| 06 | ts-chrome-ext | Runs TS gates | 0 | Produces output, no crash |
| 07 | ts-vscode-ext | Runs TS gates | 0 | Produces output, no crash |
| 08 | ts-react-native | Runs TS/RN gates | 0 | Produces output, no crash |
| 09 | ts-react-spa | Runs TS gates | 0 | Produces output, no crash |
| 10 | php-laravel | Runs PHP gates | 0 | Produces output, no crash |
| 11 | rust-cli | Runs Rust gates (cargo build/test) | 0 | Produces output, no crash |
| 12 | c-project | Minimal gates (no build system detected) | 0 | Produces output, no crash |
| 13 | static-html | Minimal gates | 0 | Produces output, no crash |
| 14 | py-datascience | Python gates | 0 | Produces output, no crash |
| 15 | ruby-rails | Ruby gates (bundle, rspec) | 0 | Produces output, no crash |
| 16 | kotlin-android | Gradle gates or skip | 0 | Produces output, no crash |

**Key test:** Pre-deploy should skip gates when tools are missing (no npm, no mvn, etc.) without crashing.

---

### `saascode sweep`

| # | Project | Expected Behavior | Expected Exit | Pass Criteria |
|---|---------|-------------------|---------------|---------------|
| All | All 16 | Runs all checks (audit + predeploy + review) | 0 | Produces summary, no crash |

**Key test:** Sweep aggregates. If sub-commands handle gracefully, sweep should too.

---

### `saascode report`

| # | Project | Expected Behavior | Expected Exit | Pass Criteria |
|---|---------|-------------------|---------------|---------------|
| All | All 16 | Shows logged issues or "no issues" | 0 | Output produced, no crash |

**Key test:** Report should show "no issues logged" if nothing has been run yet, or display previous findings.

---

## Error Message Verification Checklist

These are the specific error messages we need to verify are correct:

### AST Review — Language Skip Messages

- [ ] **Go project** → `"AST review is not available for Go."` + suggests `go vet`
- [ ] **JS project** → `"AST review is not available for JavaScript."` + suggests `check-file`/`audit`
- [ ] **PHP project** → `"AST review is not available for language: php"` + suggests `audit`
- [ ] **Rust project** → `"AST review is not available for language: rust"` + suggests `audit`
- [ ] **Ruby project** → `"AST review is not available for language: ruby"` + suggests `audit`
- [ ] **Kotlin project** → `"AST review is not available for language: kotlin"` + suggests `audit`
- [ ] **C project** → `"AST review is not available for language: ..."` + suggests `audit`
- [ ] **Static HTML** → Graceful skip or TS fallback (no crash)

### AST Review — Correct Dispatcher Routing

- [ ] **TypeScript** project → routes to `ast-review.ts` (ts-morph)
- [ ] **Python** project → routes to `ast-review-python.py` (stdlib ast)
- [ ] **Java** project → routes to `ast-review-java.sh` (grep/awk)

### Parity — Missing Frontend/Backend Messages

- [ ] Backend-only projects → does not crash, shows "no frontend found" or similar
- [ ] Frontend-only projects → does not crash, shows "no backend found" or similar
- [ ] Non-web projects (CLI, mobile) → does not crash

### Audit — Missing Tool Messages

- [ ] No `npm` → `"SKIP: npm not found"` or similar
- [ ] No `pip-audit` → `"SKIP: pip-audit not found"` or similar
- [ ] No `govulncheck` → `"SKIP: govulncheck not found"` or similar
- [ ] No `cargo audit` → `"SKIP: cargo not found"` or similar

### Check-File — File Extension Handling

- [ ] `.ts` file → runs TypeScript checks
- [ ] `.py` file → runs Python checks
- [ ] `.java` file → runs Java checks
- [ ] `.go` file → runs Go checks
- [ ] `.php` file → runs PHP checks
- [ ] `.rs` file → runs Rust checks
- [ ] `.rb` file → runs Ruby checks
- [ ] `.c` file → runs C checks (or generic)
- [ ] `.html` file → runs HTML checks (or generic)
- [ ] `.kt` file → runs Kotlin checks (or generic)

---

## Scoring

### Per-Project Score

Each project is scored on 9 commands. Each command gets:

| Result | Points | Meaning |
|--------|--------|---------|
| PASS | 2 | Command runs correctly, output matches expectations |
| SKIP | 1 | Command correctly identifies unsupported scenario, shows helpful message |
| FAIL | 0 | Command crashes, wrong exit code, missing/wrong error message |
| ERROR | 0 | Command throws unhandled exception or produces no output |

**Max score per project:** 18 points (9 commands x 2 points)
**Max total score:** 288 points (16 projects x 18 points)

### Scoring Thresholds

| Score Range | Grade | Meaning |
|-------------|-------|---------|
| 270-288 | A+ | Universal support confirmed |
| 252-269 | A | Excellent, minor gaps |
| 230-251 | B | Good, some unsupported paths need work |
| 200-229 | C | Acceptable, several commands fail on edge cases |
| < 200 | D | Needs significant work |

---

## Score Sheet (to be filled during testing)

| # | Project | init | claude | review | parity | check-file | audit | predeploy | sweep | report | Total | /18 |
|---|---------|------|--------|--------|--------|------------|-------|-----------|-------|--------|-------|-----|
| 01 | ts-nestjs-nextjs | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 18 | /18 |
| 02 | js-express | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 18 | /18 |
| 03 | py-django | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 18 | /18 |
| 04 | java-spring | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 18 | /18 |
| 05 | go-api | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 18 | /18 |
| 06 | ts-chrome-ext | | | | | | | | | | | |
| 07 | ts-vscode-ext | | | | | | | | | | | |
| 08 | ts-react-native | | | | | | | | | | | |
| 09 | ts-react-spa | | | | | | | | | | | |
| 10 | php-laravel | 2 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 17 | /18 |
| 11 | rust-cli | | | | | | | | | | | |
| 12 | c-project | | | | | | | | | | | |
| 13 | static-html | | | | | | | | | | | |
| 14 | py-datascience | | | | | | | | | | | |
| 15 | ruby-rails | | | | | | | | | | | |
| 16 | kotlin-android | | | | | | | | | | | |
| | | | | | | | | | | **TOTAL** | | **/288** |

---

## How to Run Tests

### Full test suite (all 16 projects, phased order)
```bash
bash tests/run-tests.sh
```

### Single project
```bash
bash tests/run-tests.sh 03-py-django
```

### Single command across all projects
```bash
bash tests/run-tests.sh --command review
```

### Only out-of-scope projects (negative testing)
```bash
bash tests/run-tests.sh --category B
```

---

## Test Execution Flow (per project)

```
┌─────────────────────────────────────────────┐
│  Original clone (tests/projects/03-py-django)│
│  NEVER MODIFIED — stays pristine             │
└──────────────────┬──────────────────────────┘
                   │ cp -r
                   ▼
┌─────────────────────────────────────────────┐
│  Temp copy (/tmp/saascode-test-XXXX/)        │
│  + saascode-kit.yaml manifest added          │
│  + saascode-kit/ symlinked                   │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  Run 9 commands:                             │
│  init → claude → review → parity →           │
│  check-file → audit → predeploy →            │
│  sweep → report                              │
│                                              │
│  Per command:                                │
│  • Capture exit code + first 20 lines output │
│  • Check: crash? correct message? expected?  │
│  • Score: PASS(2) / SKIP(1) / FAIL(0)       │
│  • Stop checking after first proof of work   │
└──────────────────┬──────────────────────────┘
                   │
              ┌────┴────┐
              │ Bug      │ No bug
              │ found?   │────────────┐
              └────┬─────┘            │
                   │ yes              │
                   ▼                  │
┌──────────────────────────┐          │
│  Fix in saascode-kit/    │          │
│  source (scripts/, etc.) │          │
│  Re-copy, re-test        │          │
│  Confirm fix works       │          │
└──────────────┬───────────┘          │
               │                      │
               ▼                      ▼
┌─────────────────────────────────────────────┐
│  Record scores in score sheet                │
│  DELETE temp copy (rm -rf)                   │
│  Move to next project                        │
└─────────────────────────────────────────────┘
```

---

## Notes

- Original clones use `--depth 1` — minimal disk usage, always reusable
- Temp copies are created fresh per test run — no state leaks between projects
- Manifests are auto-generated based on detected project structure
- The kit directory is **symlinked** into temp copies (not copied) so bug fixes take effect immediately on re-test
- Commands that invoke real tools (npm audit, mvn, etc.) may time out — timeout = SKIP, not FAIL
