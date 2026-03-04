# Security Review Checklist

> Use before merging any PR that touches auth, data access, or integrations
> Use with /audit or /review skills

## Authentication & Authorization
- [ ] All endpoints have authentication guard
- [ ] Tenant-scoped endpoints have TenantGuard
- [ ] @Roles decorator present on all endpoints
- [ ] RolesGuard included in @UseGuards (roles without guard = IGNORED)
- [ ] Platform/admin endpoints use separate guard chain
- [ ] No endpoints accidentally public

## Data Isolation
- [ ] All findMany() calls include tenantId in where clause
- [ ] All findFirst/findUnique followed by ownership check (record.tenantId === tenantId)
- [ ] All update/delete operations scoped by tenantId
- [ ] No cross-tenant data leakage possible through relations
- [ ] Pagination doesn't expose total counts across tenants

## Input Validation
- [ ] All DTOs have validation decorators
- [ ] String fields have @MaxLength constraints
- [ ] Email fields have @IsEmail validation
- [ ] Optional fields have @IsOptional decorator
- [ ] No unvalidated user input reaches database
- [ ] File uploads validated (type, size, content)

## Injection Prevention
- [ ] No raw SQL with string interpolation ($queryRaw with template literals)
- [ ] No dangerouslySetInnerHTML with user-controlled data
- [ ] No eval() or Function() with user input
- [ ] No shell command execution with user input
- [ ] No unvalidated URLs in server-side fetch (SSRF)

## Secrets & Credentials
- [ ] No hardcoded API keys, passwords, or tokens in code
- [ ] All secrets accessed via environment variables
- [ ] No secrets logged to console or application logs
- [ ] No .env files committed to repository
- [ ] API keys not exposed to frontend code

## Webhooks & Integrations
- [ ] Webhook handlers verify request signatures
- [ ] Webhook processing is idempotent (handles duplicate events)
- [ ] Third-party API errors handled gracefully
- [ ] External URLs validated before server-side requests
- [ ] Rate limiting on webhook endpoints

## Frontend Security
- [ ] No sensitive data in localStorage/sessionStorage
- [ ] API tokens stored securely (httpOnly cookies preferred)
- [ ] No API keys or secrets in client-side code
- [ ] CSP headers configured (if applicable)
- [ ] No sensitive data in URL parameters

## Logging & Monitoring
- [ ] No PII (passwords, tokens, emails) in logs
- [ ] Failed auth attempts logged
- [ ] Data access logged for audit trail
- [ ] Error responses don't leak internal details
