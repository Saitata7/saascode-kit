# Goals & Vision

## The Problem

AI coding tools (Claude Code, Cursor, Windsurf, Copilot) generate code fast -- but they don't know **your** project. They don't know your auth pattern, your tenant isolation rules, your guard chain order, or which API endpoints already exist.

The result:
- You repeat the same instructions every conversation
- The AI generates code that misses your security patterns
- You spend more time reviewing and fixing than you saved
- Every developer on your team gets different quality from the same AI tool

**SaasCode Kit gives the AI your project's rules upfront, so it gets things right the first time.**

---

## Kit Aims

### 1. Single-Shot Accuracy

The AI should produce correct, pattern-following code on the first try -- not after 3 rounds of "actually, we use guards like this."

**How:** Tiered context system loads the right amount of project knowledge based on task complexity. Simple fixes load nothing. Feature builds load everything.

### 2. Time Savings

Developers should spend time on architecture and product decisions, not boilerplate, pattern enforcement, or explaining the same rules to AI.

**How:** `/build` skill generates full features end-to-end (schema through page). `/recipe` templates for common tasks. Template placeholders replaced automatically from manifest.

### 3. Token Efficiency

Most AI interactions are small fixes that don't need full project context. Loading everything every time wastes tokens and money.

**How:** Message classification (QUICK/MEDIUM/FULL) built into CLAUDE.md. A CSS fix costs ~200 tokens instead of 5000+. Prompt caching on the static CLAUDE.md layer.

### 4. Consistent Code Quality

Every developer's AI should follow the same patterns, regardless of which IDE they use or how they prompt.

**How:** One manifest generates context for Claude Code, Cursor, and Windsurf. Same rules, same patterns, same guard chain -- across the entire team.

### 5. Automated Code Review

Code review shouldn't require expensive per-seat SaaS tools. Pattern-based checks (auth guards, tenant isolation, secrets) can be automated.

**How:** AST-based review with ts-morph parses every controller and service. Catches missing guards, unscoped queries, hardcoded secrets -- with exact line numbers. Free.

### 6. Shift-Left Bug Prevention

Bugs are cheapest to fix when caught while coding, not in PR review, not in staging, not in production.

**How:** 7-layer prevention system -- from IDE context (while coding) through Claude Code hooks (after each edit) to CI/CD (at PR time). Each layer catches what the previous one missed.

### 7. Zero Vendor Lock-In

The kit should work with any AI coding tool, not just one.

**How:** Manifest-driven generation produces output for Claude Code, Cursor, and Windsurf. Semgrep rules work in any IDE. Git hooks and CI work everywhere. No cloud dependency for pattern checks.

### 8. Self-Improving Rules

The kit should get smarter from your project's actual bugs, not just generic best practices.

**How:** `/learn` skill captures real bugs found during development and feeds them back into the kit's rules and patterns. Your real bugs are more valuable than generic community rules.

---

## Use Cases

### Solo Developers / Small Teams

- **Vibe coding sessions** -- `/build phone-numbers` generates a complete feature (schema, service, controller, API client, page) following your project's patterns
- **Quick fixes without waste** -- "fix the div error on line 12" costs minimal tokens because the AI knows when NOT to load context
- **One-person code review** -- `saascode review` gives you a real security audit: guard chains, tenant isolation, secrets -- with exact line numbers

### Growing Teams

- **Onboard new developers** -- `/onboard` generates a project walkthrough from the actual codebase. New devs understand the architecture in minutes
- **Consistent AI output** -- Every developer's AI uses the same CLAUDE.md, same patterns, same guard chain. No more "I didn't know we needed TenantGuard"
- **Replace per-seat review tools** -- AST review + endpoint parity + pre-commit hooks at zero per-seat cost

### Specific Workflows

- **Adding features** -- `/recipe crud` provides fill-in-the-blank templates. Fill in the model name, AI builds all layers
- **Pre-deployment** -- `saascode predeploy` runs build, TypeScript, endpoint parity, and security checks in one command
- **Debugging** -- `/debug` classifies the bug, traces the full request path (frontend -> API client -> controller -> service -> DB), and proposes a fix
- **Database migrations** -- `/migrate plan` analyzes schema changes, warns about breaking changes, generates the migration
- **PR reviews** -- `/review 42` fetches the diff, runs AST analysis, cross-references the project map, and outputs findings with confidence scores

---

## What It Prevents

| Issue | How It's Caught |
|-------|----------------|
| Auth bypass (missing guards) | AST review, Semgrep rules, IDE context |
| Tenant data leaks (unscoped queries) | AST review, service scanning, IDE context |
| Frontend-backend 404s (endpoint mismatch) | Endpoint parity enforcer |
| Secrets in code | Pre-commit hook, AST review |
| Broken deployments | Pre-deploy checks, CI pipeline |
| N+1 queries | check-file.sh, AI review |
| React hook violations | check-file.sh |
| Intent drift (AI did the wrong thing) | Intent tracking via PostToolUse hooks |
| Repeated mistakes | `/learn` feeds findings back into rules |

---

## Pros & Cons

### Strengths

- **Free** -- No per-seat fees, no subscription, no usage limits on core features
- **Project-aware** -- Understands your specific auth chain, tenant isolation, API patterns. Generic tools can't do this
- **Multi-IDE** -- One manifest generates context for Claude Code, Cursor, and Windsurf
- **Local-first** -- Code never leaves your machine for pattern checks. AI review optionally uses external LLMs
- **Layered defense** -- 7 layers from IDE context through CI/CD. Each layer catches what the previous missed
- **Self-improving** -- `/learn` captures real bugs and feeds them back into the kit

### Limitations

- **TypeScript-focused** -- Pattern checks are optimized for TypeScript/JavaScript SaaS stacks. Other languages get basic coverage only
- **SaaS-oriented** -- Built for multi-tenant SaaS patterns (auth guards, tenant isolation, API endpoints). Less useful for other project types
- **Shell-based CLI** -- Requires bash/zsh. No native Windows support (use WSL)
- **No dashboard** -- No web UI or team analytics dashboard. CLI and log files only
- **Manual manifest** -- You fill out `manifest.yaml` once, but it's manual. No auto-detection of your stack

---

## How It Compares

### vs. Cloud-Based Code Review Platforms

Cloud platforms offer PR-level review with inline comments, team dashboards, and multi-language support across 30+ languages. They're strong for large teams that need centralized reporting.

**SaasCode Kit is different:** It works _while you code_, not just at PR time. It knows your project's specific patterns (guard chains, tenant isolation) because you configure them in the manifest. Cloud platforms use generic rules -- they can't know your auth chain order matters or that every query needs `tenantId`.

**Trade-off:** Cloud platforms have broader language coverage and team analytics. SaasCode Kit has deeper project-specific coverage and catches issues 6 steps earlier (while coding vs. at PR).

### vs. IDE Static Analysis Extensions

IDE extensions provide real-time squiggly-line feedback using generic rule sets. They're excellent for standard code quality (unused variables, type errors, common security patterns).

**SaasCode Kit adds a layer on top:** Project-specific rules that no generic extension can provide. "This controller is missing RolesGuard" or "this query isn't scoped by tenantId" -- these are patterns unique to your project.

**Trade-off:** IDE extensions cover more languages and have mature ecosystems. SaasCode Kit handles the patterns that are specific to your project's architecture.

### vs. AI-Powered Review Tools

AI review tools use LLMs to analyze code semantically. They catch logical issues that pattern matching can't, like "this function doesn't handle the edge case where X is null."

**SaasCode Kit includes AI review** (`saascode review --ai`) using free-tier LLMs. But it also adds deterministic checks (AST parsing, pattern matching) that don't depend on LLM quality. A missing guard is a missing guard -- you don't need AI to determine that.

**Trade-off:** Dedicated AI review tools have more sophisticated LLM pipelines and training data. SaasCode Kit combines deterministic + AI approaches at zero cost.

### vs. Building Your Own Rules

You could write custom ESLint rules, Semgrep configs, and shell scripts from scratch. Many teams do.

**SaasCode Kit is that, pre-built.** 5 Semgrep rule sets, 14 skills, git hooks, CI pipeline, and a CLI -- all generated from one manifest. Building this from scratch takes weeks. The kit takes 5 minutes.

**Trade-off:** Custom rules are exactly tailored. The kit provides 80% coverage out of the box, and you can customize the remaining 20%.

---

## What This Kit Is NOT

- **Not a code generator** -- It doesn't scaffold your app. It configures your AI tools and review systems
- **Not a framework** -- It works alongside your existing stack, not instead of it
- **Not opinionated about architecture** -- It adapts to whatever you put in the manifest
- **Not a replacement for tests** -- It's an additional safety layer, not a substitute for unit/integration/e2e tests
- **Not vendor-locked** -- Works with any AI coding tool that reads context files
