---
name: tech-stack-decision
description: Document tech stack choices as Architecture Decision Records with evaluation criteria and comparison matrix. Use when user says "tech stack", "which database", "compare frameworks", "ADR", or "/techstack". Do NOT use for existing stack docs (use /docs) or product requirements (use /prd).
---

# Skill: Tech Stack Decision

> Trigger: /techstack or /techstack [topic]
> Purpose: Document tech stack choices as Architecture Decision Records (ADRs) — evaluate options, recommend one, record the reasoning

**What this generates:** Structured ADR documents that capture WHY a technology was chosen, not just WHAT. Covers evaluation criteria, alternatives considered, and migration paths.

**Output location:** `docs/decisions/[NNN]-[topic].md` (numbered ADR format)

## Input

| Command | What It Produces |
|---------|-----------------|
| `/techstack` | **Full stack audit** — analyze current stack from codebase, identify gaps and recommendations |
| `/techstack [topic]` | **Single decision** — evaluate options for a specific concern (e.g., "auth", "database", "caching", "queue") |
| `/techstack compare [A] vs [B]` | **Head-to-head** — detailed comparison of two specific technologies |

## Step 1: Understand Current Stack

Read the project to establish baseline:

1. **Read manifest** — `saascode-kit.yaml` for declared stack
2. **Read package files** — `package.json`, `requirements.txt`, `go.mod`, `Gemfile`, `pom.xml`, `composer.json`
3. **Check configs** — `tsconfig.json`, `.env.example`, `docker-compose.yml`, CI files
4. **Scan imports** — identify actually-used libraries vs declared dependencies

## Step 2: Generate the Document

### For Full Stack Audit (`/techstack`)

```markdown
# Tech Stack Overview

> Generated: [date]
> Project: [from manifest]

## Current Stack

| Layer | Technology | Version | Status |
|-------|-----------|---------|--------|
| Language | [detected] | [version] | Active |
| Frontend | [framework] | [version] | Active |
| Backend | [framework] | [version] | Active |
| Database | [db] | [version] | Active |
| ORM | [orm] | [version] | Active |
| Auth | [provider] | [version] | Active |
| Cache | [cache] | — | Active/Missing |
| Queue | [queue] | — | Active/Missing |
| Search | [search] | — | Active/Missing |
| CI/CD | [provider] | — | Active |
| Hosting | [infra] | — | Active |

## Dependency Health

| Package | Current | Latest | Risk |
|---------|---------|--------|------|
| [critical-dep] | [ver] | [latest] | Low/Medium/High |

## Gaps & Recommendations

| Gap | Impact | Recommendation | Effort |
|-----|--------|---------------|--------|
| No caching layer | Slow repeated queries | Add Redis/Upstash | Medium |
| No job queue | Can't do background work | Add BullMQ/Celery | Medium |
| No error tracking | Blind to production errors | Add Sentry | Low |
```

### For Single Decision (`/techstack [topic]`)

```markdown
# ADR-[NNN]: [Decision Title]

> Status: Proposed | Accepted | Deprecated | Superseded
> Date: [today]
> Deciders: [team/person]

## Context

[What is the problem or need? Why does this decision need to be made now?]

## Decision Drivers

- [Driver 1: e.g., "Must support multi-tenancy"]
- [Driver 2: e.g., "Team has experience with X"]
- [Driver 3: e.g., "Must work within budget of $Y/month"]
- [Driver 4: e.g., "Must integrate with existing stack"]

## Options Considered

### Option A: [Technology Name]

**What:** [One-line description]
**Pros:**
- [Pro 1]
- [Pro 2]
- [Pro 3]

**Cons:**
- [Con 1]
- [Con 2]

**Cost:** [Free / $X/month / $X/seat]
**Learning curve:** [Low / Medium / High]
**Community:** [Size, activity, enterprise adoption]

### Option B: [Technology Name]

[Same structure as Option A]

### Option C: [Technology Name]

[Same structure as Option A]

## Comparison Matrix

| Criteria | Weight | Option A | Option B | Option C |
|----------|--------|----------|----------|----------|
| Performance | High | [score] | [score] | [score] |
| Developer experience | High | [score] | [score] | [score] |
| Community/support | Medium | [score] | [score] | [score] |
| Cost | Medium | [score] | [score] | [score] |
| Migration effort | Low | [score] | [score] | [score] |

## Decision

**Chosen: [Option X]**

[1-2 sentences: why this option wins given the context and drivers]

## Consequences

**Positive:**
- [What becomes easier/better]

**Negative:**
- [What trade-offs are accepted]

**Migration path:**
- [Steps to implement this decision]

## References

- [Link to docs]
- [Link to benchmarks]
- [Link to similar projects using this]
```

### For Comparison (`/techstack compare [A] vs [B]`)

Use the single-decision format above but with only 2 options, deeper technical comparison, and include:

```markdown
## Technical Deep Dive

### [A] Architecture
[How it works under the hood, scaling model, deployment model]

### [B] Architecture
[How it works under the hood, scaling model, deployment model]

### Benchmark Comparison
| Metric | [A] | [B] | Winner |
|--------|-----|-----|--------|
| Throughput | [val] | [val] | [X] |
| Latency (p50) | [val] | [val] | [X] |
| Memory usage | [val] | [val] | [X] |
| Cold start | [val] | [val] | [X] |

### Ecosystem
| Feature | [A] | [B] |
|---------|-----|-----|
| ORM support | [list] | [list] |
| Auth libraries | [list] | [list] |
| Testing tools | [list] | [list] |
| Deployment options | [list] | [list] |
```

## Step 3: Number the ADR

Check existing ADRs in `docs/decisions/`:
- If directory exists, find the highest number and increment
- If no directory, start at `001`
- Format: `docs/decisions/001-choose-database.md`

## Output Rules

1. **Create `docs/decisions/` directory** if it doesn't exist
2. **Be opinionated** — always recommend one option, don't leave it open-ended
3. **Include real costs** — pricing tiers, scaling costs, hidden costs (data transfer, etc.)
4. **Match project context** — recommendations should fit the team size, budget, and existing stack
5. **No vendor hype** — state trade-offs honestly, every technology has downsides
6. **Link to sources** — reference official docs, benchmarks, community discussions
7. **Consider the manifest** — if `saascode-kit.yaml` declares a stack, respect it as the baseline
