---
name: developer-onboarding
description: Generate developer setup and onboarding guide by detecting stack and creating verification script. Use when user says "onboard", "setup guide", "new developer", or "/onboard". Do NOT use for end-user onboarding flows.
---

# Skill: Developer Onboarding

> Trigger: /onboard [action]
> Purpose: Generate setup instructions for new developers

## Modes

- `/onboard` — Generate full onboarding guide
- `/onboard verify` — Run all checks on current setup
- `/onboard [tool]` — Setup guide for one tool (docker, postgres, etc.)

## Step 1: Detect Stack

```bash
ls package.json pnpm-lock.yaml yarn.lock package-lock.json bun.lockb 2>/dev/null
cat .node-version .nvmrc .tool-versions 2>/dev/null
ls Dockerfile docker-compose* 2>/dev/null
grep -E "postgresql|mysql|mongodb|redis" package.json */package.json 2>/dev/null
find . -name "schema.prisma" | grep -v node_modules | head -1 | xargs grep "provider" 2>/dev/null
ls .env.example apps/*/.env.example 2>/dev/null
ls apps/ packages/ 2>/dev/null
grep -rE "clerk|auth0|firebase|supabase|nextauth" package.json */package.json 2>/dev/null
```

## Step 2: Generate Prerequisites

```markdown
## Prerequisites
| Tool | Version | Install | Verify |
|------|---------|---------|--------|
| Node.js | >= 18 | `brew install node` | `node -v` |
| PostgreSQL | >= 14 | `brew install postgresql@14` | `psql --version` |
```

## Step 3: Generate Setup Guide

Generate step-by-step with verify command after each step:

1. **Clone & Install** → Verify: `ls node_modules/.package-lock.json`
2. **Environment Setup** → Copy .env.example files, document each variable (where to get it, example value) → Verify: `grep -c "xxx\|CHANGE_ME" .env` = 0
3. **Database Setup** → createdb + prisma migrate dev → Verify: `npx prisma migrate status`
4. **Start Development** → npm run dev → Verify: `curl localhost:4000/health` + open `localhost:3000`
5. **Run Tests** → npm test → Verify: all pass

## Step 4: Verification Script

Generate `verify-setup.sh`:

```bash
#!/bin/bash
echo "Checking development environment..."
node -v >/dev/null 2>&1 && echo "✓ Node.js $(node -v)" || echo "✗ Node.js not installed"
npm -v >/dev/null 2>&1 && echo "✓ npm $(npm -v)" || echo "✗ npm not installed"
psql --version >/dev/null 2>&1 && echo "✓ PostgreSQL installed" || echo "✗ PostgreSQL not installed"
[ -d "node_modules" ] && echo "✓ Dependencies installed" || echo "✗ Run: npm install"
[ -f ".env" ] && echo "✓ Root .env exists" || echo "✗ Missing .env"
[ -f "apps/api/.env" ] && echo "✓ API .env exists" || echo "✗ Missing apps/api/.env"
npx prisma migrate status >/dev/null 2>&1 && echo "✓ Database connected" || echo "✗ Database not connected"
[ -d "node_modules/.prisma" ] && echo "✓ Prisma client generated" || echo "✗ Run: npx prisma generate"
```

## Step 5: Project Notes

```bash
grep -E "\"dev|\"start|\"build|\"test" package.json | head -10
ls -d apps/* packages/* 2>/dev/null
grep -r "REDIS\|RABBITMQ\|S3_" .env.example 2>/dev/null
```

Add: architecture overview (what each app does), common tasks, troubleshooting.

## Output

Write to `docs/onboarding.md` + `.saascode/scripts/verify-setup.sh`.

```markdown
## Onboarding Generated
| File | Purpose |
|------|---------|
| docs/onboarding.md | Full setup guide |
| .saascode/scripts/verify-setup.sh | Verification script |
Detected: [stack summary]
Steps: X | Estimated: ~20 min
```

## Rules

1. Every step has a verify command
2. Detect from code — don't assume the stack
3. Commands must be copy-paste ready
4. Secrets never in docs — use placeholders
5. Keep setup under 30 minutes
