# Feature Completion Checklist

> Use this before marking any feature as "done"
> Copy to PR description or use with /build skill

## Database
- [ ] Model has tenantId (for tenant-scoped data)
- [ ] Indexes on frequently queried columns
- [ ] Unique constraints prevent duplicates
- [ ] Relations and cascade deletes configured
- [ ] Migration is additive (no destructive changes without plan)

## Backend
- [ ] Controller has correct guard chain (AuthGuard + TenantGuard + RolesGuard)
- [ ] @Roles decorator on every endpoint
- [ ] All queries scoped by tenantId
- [ ] Ownership verified after findUnique/findFirst
- [ ] DTOs with validation decorators (@IsString, @MaxLength, etc.)
- [ ] Static routes registered before dynamic routes
- [ ] Module registered in AppModule
- [ ] Proper error handling (HttpException, not generic errors)

## Frontend
- [ ] API client functions match backend endpoints 1:1 (parity)
- [ ] Loading state shown during data fetch
- [ ] Empty state when no data exists
- [ ] Error state with retry option
- [ ] Role-based UI visibility (hide actions user can't perform)
- [ ] Toast notifications for create/update/delete actions
- [ ] Form validation with visible error messages
- [ ] Responsive layout (mobile + desktop)

## Security
- [ ] No hardcoded secrets or API keys
- [ ] No dangerouslySetInnerHTML with user input
- [ ] No console.log with sensitive data
- [ ] Input sanitized before database/API calls
- [ ] CORS configured correctly for new endpoints

## Build Verification
- [ ] `npm run typecheck` passes
- [ ] Backend build passes
- [ ] Frontend build passes
- [ ] Existing tests still pass
- [ ] New tests written for critical paths (optional)

## Integration
- [ ] Webhook handlers verify signatures (if applicable)
- [ ] Third-party API calls have error handling + retry
- [ ] Rate limiting on public endpoints (if applicable)
