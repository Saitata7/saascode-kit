# Deployment Readiness Checklist

> Use before any production deployment
> Use with /preflight skill or scripts/pre-deploy.sh

## Build Gates (ALL must pass)
- [ ] TypeScript compilation passes (`npm run typecheck`)
- [ ] Backend build passes
- [ ] Frontend build passes
- [ ] All tests pass
- [ ] No critical npm audit vulnerabilities

## Database
- [ ] Migrations generated and reviewed
- [ ] Migration is non-destructive (additive only)
- [ ] Rollback migration prepared (if destructive changes)
- [ ] Indexes added for new query patterns
- [ ] Seed data updated (if applicable)

## Environment
- [ ] All new environment variables documented
- [ ] New env vars set in staging/production
- [ ] No hardcoded values that should be env vars
- [ ] Feature flags configured (if applicable)

## API Changes
- [ ] Endpoint parity verified (frontend <-> backend)
- [ ] Breaking changes documented
- [ ] API versioning followed (if applicable)
- [ ] CORS updated for new endpoints
- [ ] Rate limits configured for new public endpoints

## Integration Health
- [ ] API health endpoint returns 200
- [ ] Database connection stable
- [ ] Webhook endpoints respond (401 without signature = correct)
- [ ] Third-party service connections verified
- [ ] Queue workers running (if applicable)

## Smoke Tests
- [ ] Login works for all roles
- [ ] Dashboard loads with correct data
- [ ] Core CRUD operations functional
- [ ] Billing page accessible (owner only)
- [ ] No console errors in browser
- [ ] Pages load in < 3 seconds

## Rollback Plan
- [ ] Previous frontend deployment ID noted
- [ ] Previous backend image/deployment noted
- [ ] Database rollback SQL prepared (if migration applied)
- [ ] Rollback tested or documented
- [ ] Team notified of deployment window

## Post-Deploy
- [ ] Health check passes after deployment
- [ ] Monitor error rates for 15 minutes
- [ ] Verify critical user flows work
- [ ] Check log output for unexpected errors
- [ ] Confirm webhooks still processing
