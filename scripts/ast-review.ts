#!/usr/bin/env npx tsx
/**
 * SaasCode Kit — AST-Based Code Review
 * Uses ts-morph to parse controllers and services for:
 *   - Missing guard chains
 *   - Missing @Roles or @Public on endpoints
 *   - Missing tenant scoping in services
 *   - Unused parameter decorators
 *   - Empty catch blocks
 *   - Console.log in production code
 *
 * Usage: npx tsx saascode-kit/scripts/ast-review.ts [--changed-only]
 *   --changed-only: Only scan files changed in git (for PR reviews)
 */

import { Project, SyntaxKind, Node, ClassDeclaration, MethodDeclaration, SourceFile } from 'ts-morph';
import * as path from 'path';
import { execSync } from 'child_process';

// ─── Config ───

const PROJECT_ROOT = execSync('git rev-parse --show-toplevel', { encoding: 'utf-8' }).trim();
const API_SRC = path.join(PROJECT_ROOT, 'apps/api/src');
const TSCONFIG = path.join(PROJECT_ROOT, 'apps/api/tsconfig.json');

const COLORS = {
  red: '\x1b[0;31m',
  green: '\x1b[0;32m',
  yellow: '\x1b[1;33m',
  cyan: '\x1b[0;36m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  nc: '\x1b[0m',
};

interface Finding {
  file: string;
  line: number;
  severity: 'CRITICAL' | 'WARNING';
  confidence: number;
  issue: string;
  fix: string;
}

// ─── Decorator Helpers ───

function getDecoratorNames(node: ClassDeclaration | MethodDeclaration): string[] {
  return node.getDecorators().map(d => d.getName());
}

function getDecoratorArgs(node: ClassDeclaration | MethodDeclaration, name: string): string[] {
  const decorator = node.getDecorators().find(d => d.getName() === name);
  if (!decorator) return [];
  const args = decorator.getArguments();
  return args.map(a => a.getText());
}

function getUseGuardsArgs(node: ClassDeclaration): string[] {
  const decorator = node.getDecorators().find(d => d.getName() === 'UseGuards');
  if (!decorator) return [];
  return decorator.getArguments().map(a => a.getText());
}

function hasDecorator(node: ClassDeclaration | MethodDeclaration, name: string): boolean {
  return node.getDecorators().some(d => d.getName() === name);
}

function getHttpMethod(method: MethodDeclaration): string | null {
  const httpDecorators = ['Get', 'Post', 'Put', 'Patch', 'Delete'];
  for (const dec of method.getDecorators()) {
    if (httpDecorators.includes(dec.getName())) {
      return dec.getName();
    }
  }
  return null;
}

function getParameterDecorators(method: MethodDeclaration): string[] {
  const decorators: string[] = [];
  for (const param of method.getParameters()) {
    for (const dec of param.getDecorators()) {
      decorators.push(dec.getName());
    }
  }
  return decorators;
}

function relativePath(filePath: string): string {
  return filePath.replace(PROJECT_ROOT + '/', '');
}

// ─── Checks ───

function isControllerClass(cls: ClassDeclaration): boolean {
  return cls.getDecorators().some(d => d.getName() === 'Controller');
}

function checkGuardChain(cls: ClassDeclaration, findings: Finding[], filePath: string): void {
  // Only check actual @Controller classes, skip DTOs/other classes in same file
  if (!isControllerClass(cls)) return;

  const guards = getUseGuardsArgs(cls);
  const className = cls.getName() || 'Unknown';

  // Skip platform controllers — they use PlatformGuard
  if (filePath.includes('/platform/')) return;

  // Skip webhook controllers — they should be @Public
  if (className.toLowerCase().includes('webhook')) return;

  // Skip control-plane controllers — they use ApiKeyAuthGuard (legitimate)
  if (filePath.includes('/control-plane/')) return;

  // Skip OAuth controllers — they have special auth flows
  if (className.toLowerCase().includes('oauth')) return;

  // Must have @UseGuards
  if (guards.length === 0) {
    // Check if class has @Public() — some controllers are fully public
    if (!hasDecorator(cls, 'Public')) {
      findings.push({
        file: relativePath(filePath),
        line: cls.getStartLineNumber(),
        severity: 'CRITICAL',
        confidence: 95,
        issue: `${className} has no @UseGuards decorator`,
        fix: 'Add @UseGuards(ClerkAuthGuard, TenantGuard, RolesGuard)',
      });
    }
    return;
  }

  // ClerkAuthGuard must be first (for non-control-plane)
  if (guards[0] !== 'ClerkAuthGuard') {
    findings.push({
      file: relativePath(filePath),
      line: cls.getStartLineNumber(),
      severity: 'CRITICAL',
      confidence: 95,
      issue: `${className} guard chain doesn't start with ClerkAuthGuard (found: ${guards[0]})`,
      fix: 'ClerkAuthGuard must be the first guard in @UseGuards()',
    });
  }

  // If TenantGuard used, RolesGuard should follow
  const hasTenantGuard = guards.includes('TenantGuard');
  const hasRolesGuard = guards.includes('RolesGuard');
  if (hasTenantGuard && !hasRolesGuard) {
    findings.push({
      file: relativePath(filePath),
      line: cls.getStartLineNumber(),
      severity: 'WARNING',
      confidence: 80,
      issue: `${className} has TenantGuard but no RolesGuard`,
      fix: 'Add RolesGuard after TenantGuard: @UseGuards(ClerkAuthGuard, TenantGuard, RolesGuard)',
    });
  }
}

function checkMethodDecorators(
  cls: ClassDeclaration,
  method: MethodDeclaration,
  findings: Finding[],
  filePath: string,
): void {
  if (!isControllerClass(cls)) return;

  const httpMethod = getHttpMethod(method);
  if (!httpMethod) return; // Not an endpoint

  const methodName = method.getName();
  const classGuards = getUseGuardsArgs(cls);

  // Check @Roles or @Public
  const hasRoles = hasDecorator(method, 'Roles');
  const hasPublic = hasDecorator(method, 'Public');
  const classHasPublic = hasDecorator(cls, 'Public');

  if (!hasRoles && !hasPublic && !classHasPublic && classGuards.includes('RolesGuard')) {
    findings.push({
      file: relativePath(filePath),
      line: method.getStartLineNumber(),
      severity: 'CRITICAL',
      confidence: 92,
      issue: `@${httpMethod}() ${methodName}() has no @Roles() or @Public() — RolesGuard will deny all requests`,
      fix: `Add @Roles(TenantRole.OWNER, TenantRole.ADMIN) or @Public()`,
    });
  }
}

function checkParameterUsage(
  cls: ClassDeclaration,
  method: MethodDeclaration,
  findings: Finding[],
  filePath: string,
): void {
  if (!isControllerClass(cls)) return;

  const httpMethod = getHttpMethod(method);
  if (!httpMethod) return;

  const paramDecorators = getParameterDecorators(method);
  const classGuards = getUseGuardsArgs(cls);

  // If class has TenantGuard, tenant-scoped methods should use @CurrentTenant()
  if (classGuards.includes('TenantGuard')) {
    const hasTenantParam =
      paramDecorators.includes('CurrentTenant') ||
      paramDecorators.includes('CurrentOrgId') ||
      paramDecorators.includes('CurrentMembership');

    // Write operations (POST/PATCH/PUT/DELETE) without tenant param
    if (['Post', 'Patch', 'Put', 'Delete'].includes(httpMethod) && !hasTenantParam) {
      findings.push({
        file: relativePath(filePath),
        line: method.getStartLineNumber(),
        severity: 'WARNING',
        confidence: 75,
        issue: `@${httpMethod}() ${method.getName()}() in TenantGuard-protected controller has no @CurrentTenant() parameter`,
        fix: 'Add @CurrentTenant() tenant parameter to ensure tenant scoping',
      });
    }
  }
}

function checkServiceTenantScoping(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();
  if (!filePath.endsWith('.service.ts')) return;

  // Skip platform services
  if (filePath.includes('/platform/')) return;

  const classes = sourceFile.getClasses();

  for (const cls of classes) {
    const methods = cls.getMethods();

    for (const method of methods) {
      const methodName = method.getName();
      const body = method.getBody()?.getText() || '';

      // Check for prisma queries without tenantId
      const hasPrismaCall =
        body.includes('.findMany(') ||
        body.includes('.findFirst(') ||
        body.includes('.findUnique(') ||
        body.includes('.create(') ||
        body.includes('.update(') ||
        body.includes('.delete(');

      if (hasPrismaCall) {
        const hasTenantScope =
          body.includes('tenantId') ||
          body.includes('tenant.id') ||
          body.includes('clerkOrgId') ||
          methodName.startsWith('_'); // Private helper methods might be called with tenant context

        if (!hasTenantScope) {
          // Check method parameters for tenant context
          const params = method.getParameters().map(p => p.getName());
          const hasTenantParam = params.some(
            p =>
              p.includes('tenant') ||
              p.includes('Tenant') ||
              p.includes('orgId') ||
              p.includes('clerkOrgId'),
          );

          if (!hasTenantParam) {
            findings.push({
              file: relativePath(filePath),
              line: method.getStartLineNumber(),
              severity: 'CRITICAL',
              confidence: 85,
              issue: `${cls.getName()}.${methodName}() has Prisma query but no tenantId scoping`,
              fix: 'Add tenantId to where clause or pass tenant context as parameter',
            });
          }
        }
      }
    }
  }
}

function checkEmptyCatchBlocks(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();

  sourceFile.getDescendantsOfKind(SyntaxKind.CatchClause).forEach(catchClause => {
    const block = catchClause.getBlock();
    const statements = block.getStatements();

    if (statements.length === 0) {
      findings.push({
        file: relativePath(filePath),
        line: catchClause.getStartLineNumber(),
        severity: 'WARNING',
        confidence: 85,
        issue: 'Empty catch block swallows errors silently',
        fix: 'Add error logging or re-throw the error',
      });
    }
  });
}

function checkConsoleLog(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();

  // Skip test files
  if (filePath.includes('.spec.') || filePath.includes('.test.')) return;

  sourceFile.getDescendantsOfKind(SyntaxKind.CallExpression).forEach(call => {
    const text = call.getExpression().getText();
    if (text === 'console.log' || text === 'console.debug') {
      findings.push({
        file: relativePath(filePath),
        line: call.getStartLineNumber(),
        severity: 'WARNING',
        confidence: 80,
        issue: `${text}() in production code`,
        fix: 'Use Logger from @nestjs/common instead, or remove',
      });
    }
  });
}

function checkRawSql(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();

  sourceFile.getDescendantsOfKind(SyntaxKind.CallExpression).forEach(call => {
    const text = call.getExpression().getText();
    if (text.includes('$queryRaw') || text.includes('$executeRaw')) {
      // Check if using template literal (safe) or string concatenation (unsafe)
      const args = call.getArguments();
      if (args.length > 0) {
        const argText = args[0].getText();
        if (argText.includes('${') && !argText.startsWith('Prisma.sql')) {
          findings.push({
            file: relativePath(filePath),
            line: call.getStartLineNumber(),
            severity: 'CRITICAL',
            confidence: 95,
            issue: 'Raw SQL with string interpolation — SQL injection risk',
            fix: 'Use Prisma.sql tagged template or parameterized queries',
          });
        }
      }
    }
  });
}

function checkHardcodedSecrets(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();

  // Skip .env files, test files
  if (filePath.includes('.spec.') || filePath.includes('.test.') || filePath.includes('.env'))
    return;

  const secretPatterns = [
    /(?:api[_-]?key|secret|password|token|auth)\s*[:=]\s*['"][a-zA-Z0-9]{16,}['"]/i,
    /sk[-_](?:live|test)_[a-zA-Z0-9]{20,}/,
    /Bearer\s+[a-zA-Z0-9._-]{20,}/,
  ];

  const text = sourceFile.getFullText();
  const lines = text.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    for (const pattern of secretPatterns) {
      if (pattern.test(line)) {
        // Skip lines that are reading from env/config
        if (
          line.includes('process.env') ||
          line.includes('configService') ||
          line.includes('ConfigService') ||
          line.includes('// example') ||
          line.includes('// test')
        )
          continue;

        findings.push({
          file: relativePath(filePath),
          line: i + 1,
          severity: 'CRITICAL',
          confidence: 90,
          issue: 'Potential hardcoded secret or API key',
          fix: 'Move to environment variable and use ConfigService',
        });
      }
    }
  }
}

// ─── Main ───

async function main() {
  const changedOnly = process.argv.includes('--changed-only');

  console.log(`${COLORS.bold}AST Code Review${COLORS.nc}`);
  console.log('================================');
  console.log('');

  // Initialize ts-morph project
  console.log(`${COLORS.cyan}[1/4] Loading TypeScript project...${COLORS.nc}`);

  const project = new Project({
    tsConfigFilePath: TSCONFIG,
    skipAddingFilesFromTsConfig: true,
    skipFileDependencyResolution: true,
  });

  // Determine files to scan
  let controllerGlob = `${API_SRC}/modules/**/*.controller.ts`;
  let serviceGlob = `${API_SRC}/modules/**/*.service.ts`;

  if (changedOnly) {
    try {
      const diffFiles = execSync('git diff --name-only HEAD~1', { encoding: 'utf-8' })
        .trim()
        .split('\n')
        .filter(f => f.startsWith('apps/api/'))
        .map(f => path.join(PROJECT_ROOT, f));

      for (const file of diffFiles) {
        if (file.endsWith('.ts')) {
          try {
            project.addSourceFileAtPath(file);
          } catch {
            // File might not exist (deleted)
          }
        }
      }
      console.log(`  Scanning ${COLORS.green}${diffFiles.length}${COLORS.nc} changed files`);
    } catch {
      console.log(`  ${COLORS.yellow}Could not get git diff, scanning all files${COLORS.nc}`);
      project.addSourceFilesAtPaths([controllerGlob, serviceGlob]);
    }
  } else {
    project.addSourceFilesAtPaths([controllerGlob, serviceGlob]);
  }

  const sourceFiles = project.getSourceFiles();
  const controllers = sourceFiles.filter(f => f.getFilePath().endsWith('.controller.ts'));
  const services = sourceFiles.filter(f => f.getFilePath().endsWith('.service.ts'));

  console.log(
    `  Found ${COLORS.green}${controllers.length}${COLORS.nc} controllers, ${COLORS.green}${services.length}${COLORS.nc} services`,
  );
  console.log('');

  const findings: Finding[] = [];

  // ─── Check Controllers ───
  console.log(`${COLORS.cyan}[2/4] Analyzing controllers...${COLORS.nc}`);

  for (const sourceFile of controllers) {
    const filePath = sourceFile.getFilePath();
    const classes = sourceFile.getClasses();

    for (const cls of classes) {
      // Guard chain check
      checkGuardChain(cls, findings, filePath);

      // Method-level checks
      for (const method of cls.getMethods()) {
        checkMethodDecorators(cls, method, findings, filePath);
        checkParameterUsage(cls, method, findings, filePath);
      }
    }

    // Cross-cutting checks
    checkConsoleLog(sourceFile, findings);
    checkRawSql(sourceFile, findings);
    checkHardcodedSecrets(sourceFile, findings);
    checkEmptyCatchBlocks(sourceFile, findings);
  }

  // ─── Check Services ───
  console.log(`${COLORS.cyan}[3/4] Analyzing services...${COLORS.nc}`);

  for (const sourceFile of services) {
    checkServiceTenantScoping(sourceFile, findings);
    checkConsoleLog(sourceFile, findings);
    checkRawSql(sourceFile, findings);
    checkHardcodedSecrets(sourceFile, findings);
    checkEmptyCatchBlocks(sourceFile, findings);
  }

  // ─── Report ───
  console.log(`${COLORS.cyan}[4/4] Generating report...${COLORS.nc}`);
  console.log('');

  // Sort by severity (CRITICAL first), then confidence
  findings.sort((a, b) => {
    if (a.severity !== b.severity) return a.severity === 'CRITICAL' ? -1 : 1;
    return b.confidence - a.confidence;
  });

  const criticals = findings.filter(f => f.severity === 'CRITICAL');
  const warnings = findings.filter(f => f.severity === 'WARNING');

  if (findings.length === 0) {
    console.log(`${COLORS.green}No issues found. All checks passed.${COLORS.nc}`);
  } else {
    // Table header
    console.log(
      `${COLORS.bold}| # | File:Line | Severity | Confidence | Issue | Fix |${COLORS.nc}`,
    );
    console.log('|---|-----------|----------|------------|-------|-----|');

    findings.forEach((f, i) => {
      const sevColor = f.severity === 'CRITICAL' ? COLORS.red : COLORS.yellow;
      const shortFile = f.file.replace('apps/api/src/modules/', '');
      console.log(
        `| ${i + 1} | ${shortFile}:${f.line} | ${sevColor}${f.severity}${COLORS.nc} | ${f.confidence}% | ${f.issue} | ${f.fix} |`,
      );
    });
  }

  console.log('');
  console.log('================================');
  console.log(
    `  Files scanned:  ${COLORS.bold}${controllers.length + services.length}${COLORS.nc} (${controllers.length} controllers, ${services.length} services)`,
  );
  console.log(
    `  Findings:       ${COLORS.red}${criticals.length} critical${COLORS.nc}, ${COLORS.yellow}${warnings.length} warnings${COLORS.nc}`,
  );

  // Clean files
  const filesWithIssues = new Set(findings.map(f => f.file));
  const allFiles = sourceFiles.map(f => relativePath(f.getFilePath()));
  const cleanFiles = allFiles.filter(f => !filesWithIssues.has(f));

  if (cleanFiles.length > 0) {
    console.log('');
    console.log(`${COLORS.bold}Clean files (no issues):${COLORS.nc}`);
    cleanFiles.forEach(f => {
      console.log(`  ${COLORS.green}✓${COLORS.nc} ${f.replace('apps/api/src/modules/', '')}`);
    });
  }

  console.log('');

  // Verdict
  if (criticals.length > 0) {
    console.log(`${COLORS.red}VERDICT: REQUEST CHANGES — ${criticals.length} critical issues found${COLORS.nc}`);
    process.exit(1);
  } else if (warnings.length > 0) {
    console.log(`${COLORS.yellow}VERDICT: COMMENT — ${warnings.length} warnings to consider${COLORS.nc}`);
    process.exit(0);
  } else {
    console.log(`${COLORS.green}VERDICT: APPROVE — No issues detected${COLORS.nc}`);
    process.exit(0);
  }
}

main().catch(err => {
  console.error(`${COLORS.red}AST Review failed:${COLORS.nc}`, err.message);
  process.exit(2);
});
