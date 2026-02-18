---
name: deployment-guide
description: Step-by-step deployment workflow with pre-deploy gates, migrations, and rollback. Use when user says "deploy", "release", "push to production", "rollback", or "/deploy". Do NOT use for CI/CD pipeline setup (configure in manifest instead).
---

# Skill: Deployment Guide

> Trigger: /deploy [environment|"status"|"rollback"]
> Purpose: Step-by-step deployment with verification at every stage

## Modes

- `/deploy` or `/deploy status` — Current state + environment health
- `/deploy [staging|production]` — Full deployment workflow
- `/deploy rollback` — Revert last deployment

## Step 1: Pre-Deploy Gates

```bash
git log --oneline -10
git status
npx prisma migrate status 2>/dev/null
npm test 2>/dev/null
npm run build 2>/dev/null
```

| Gate | Command | Required |
|------|---------|----------|
| Clean git | `git status` — no uncommitted | Yes |
| Tests pass | `npm test` | Yes |
| TypeScript clean | `npm run typecheck` | Yes |
| Build succeeds | `npm run build` | Yes |
| No critical vulns | `npm audit --audit-level=critical` | Yes |
| Migrations ready | `npx prisma migrate status` | If schema changed |
| Env vars set | Compare .env.example vs target | Yes |

All must pass. If any fails → fix it, show what failed and how.

## Step 2: Detect Target

```bash
find . -name "Dockerfile" -o -name "docker-compose*" -o -name "vercel.json" -o -name "fly.toml" -o -name "railway.json" | grep -v node_modules
grep -E "deploy|start:prod" package.json */package.json 2>/dev/null
ls .github/workflows/ 2>/dev/null
```

## Step 3: Deploy Sequence

1. **Backup DB** (production): `pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql`
2. **Run migrations**: `npx prisma migrate deploy` → Verify: `npx prisma migrate status`
3. **Deploy backend** (platform-specific: vercel/railway/docker/pm2)
4. **Verify backend**: `curl -f https://api.example.com/health`
5. **Deploy frontend** (usually auto-deployed by platform)
6. **Verify frontend**: `curl -f https://app.example.com`

## Step 4: Post-Deploy

```markdown
- [ ] Health endpoint returns 200
- [ ] Auth works (can log in)
- [ ] Core feature works (test API call)
- [ ] No error spikes in logs
- [ ] SSL valid
- [ ] Env vars loaded
```

```bash
curl -s https://api.example.com/health | jq .
curl -s -o /dev/null -w "%{http_code}" https://app.example.com
```

## Step 5: Rollback

```bash
# Redeploy previous version
git checkout [previous-tag] && npm run build && [deploy-command]

# Platform rollback
# Vercel: vercel rollback | Railway: railway rollback | Docker: kubectl rollout undo

# DB rollback (only if migration caused issue)
npx prisma migrate resolve --rolled-back [migration-name]
```

## Step 6: Report

```markdown
## Deployment Report
**Environment:** [staging/production] | **Date:** [timestamp]
**Branch:** [name] | **Commits:** [list]
**Migration:** [name or none]

| Check | Status |
|-------|--------|
| Build | PASS |
| Migration | PASS |
| Health check | PASS |
| Auth flow | PASS |
| Error logs | PASS |

**Rollback:** `[specific command]` | Previous: `[commit hash]`
```

## Rules

1. Never deploy on Friday (unless emergency)
2. Always verify after deploy
3. Migrations before code
4. Backup before production migrations
5. One change at a time
6. Rollback plan ready BEFORE deploy
7. Monitor 15 min after production deploy
