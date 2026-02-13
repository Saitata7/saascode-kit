#!/usr/bin/env npx tsx
/**
 * SaasCode Kit — AST-Based Code Review
 * Uses ts-morph to parse TypeScript files for:
 *   - Missing guard chains (NestJS)
 *   - Missing @Roles or @Public on endpoints (NestJS)
 *   - Missing tenant scoping in services (NestJS)
 *   - Empty catch blocks (universal)
 *   - Console.log in production code (universal)
 *   - Raw SQL injection (universal)
 *   - Hardcoded secrets (universal)
 *   - innerHTML write detection (universal)
 *   - Hardcoded AI model names (universal)
 *   - Switch without default (universal)
 *
 * Usage: npx tsx saascode-kit/scripts/ast-review.ts [--changed-only]
 *   --changed-only: Only scan files changed in git (for PR reviews)
 */

import { Project, SyntaxKind, Node, ClassDeclaration, MethodDeclaration, SourceFile, BinaryExpression } from 'ts-morph';
import * as path from 'path';
import * as fs from 'fs';
import { execSync } from 'child_process';

// ─── Config ───

// Bug 8 fix: fallback to cwd if not in a git repo
let PROJECT_ROOT: string;
try {
  PROJECT_ROOT = execSync('git rev-parse --show-toplevel', { encoding: 'utf-8' }).trim();
} catch {
  PROJECT_ROOT = process.cwd();
}

// Bug 13 fix: Read manifest to determine paths and project type
interface ManifestConfig {
  backendPath: string;
  frontendPath: string;
  backendFramework: string;
  isNestJS: boolean;
  tsconfigPath: string;
}

function readManifestValue(key: string, defaultValue: string): string {
  const manifestPaths = [
    path.join(PROJECT_ROOT, 'saascode-kit/manifest.yaml'),
    path.join(PROJECT_ROOT, '.saascode/manifest.yaml'),
    path.join(PROJECT_ROOT, 'manifest.yaml'),
    path.join(PROJECT_ROOT, 'saascode-kit.yaml'),
  ];

  let manifestPath = '';
  for (const p of manifestPaths) {
    if (fs.existsSync(p)) {
      manifestPath = p;
      break;
    }
  }
  if (!manifestPath) return defaultValue;

  try {
    const content = fs.readFileSync(manifestPath, 'utf-8');
    const [section, field] = key.split('.');
    let inSection = false;

    for (const line of content.split('\n')) {
      if (/^[a-z]/.test(line)) {
        inSection = line.startsWith(section + ':');
        // Top-level key with value
        if (inSection && section === field) {
          const val = line.replace(/^[^:]+:\s*/, '').replace(/\s+#\s.*$/, '').replace(/^"|"$/g, '').trim();
          if (val) return val;
        }
        continue;
      }
      if (inSection && /^\s{2}[a-z]/.test(line)) {
        const trimmed = line.trim();
        if (trimmed.startsWith(field + ':')) {
          const val = trimmed.replace(/^[^:]+:\s*/, '').replace(/\s+#\s.*$/, '').replace(/^"|"$/g, '').trim();
          if (val) return val;
        }
      }
    }
  } catch { /* ignore */ }

  return defaultValue;
}

function loadConfig(): ManifestConfig {
  const backendPath = readManifestValue('paths.backend', 'apps/api');
  const frontendPath = readManifestValue('paths.frontend', 'apps/portal');
  const backendFramework = readManifestValue('stack.backend_framework', '');

  // Also try nested key format
  const fw = backendFramework || readManifestValue('backend.framework', '');

  // Detect NestJS by checking for NestJS imports if manifest doesn't say
  let isNestJS = fw.toLowerCase().includes('nest');
  if (!isNestJS) {
    // Auto-detect: check if any .ts file imports from @nestjs
    const srcDir = path.join(PROJECT_ROOT, backendPath, 'src');
    if (fs.existsSync(srcDir)) {
      try {
        const result = execSync(`grep -rl "@nestjs/" "${srcDir}" --include="*.ts" 2>/dev/null | head -1`, { encoding: 'utf-8' }).trim();
        isNestJS = result.length > 0;
      } catch { /* not NestJS */ }
    }
  }

  // Find tsconfig.json — search backend path first, then root
  let tsconfigPath = '';
  const candidates = [
    path.join(PROJECT_ROOT, backendPath, 'tsconfig.json'),
    path.join(PROJECT_ROOT, 'tsconfig.json'),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) {
      tsconfigPath = c;
      break;
    }
  }

  return { backendPath, frontendPath, backendFramework: fw, isNestJS, tsconfigPath };
}

const CONFIG = loadConfig();

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

// ─── Decorator Helpers (NestJS-specific) ───

function getDecoratorNames(node: ClassDeclaration | MethodDeclaration): string[] {
  return node.getDecorators().map(d => d.getName());
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

// ─── NestJS-Specific Checks ───

function isControllerClass(cls: ClassDeclaration): boolean {
  return cls.getDecorators().some(d => d.getName() === 'Controller');
}

function checkGuardChain(cls: ClassDeclaration, findings: Finding[], filePath: string): void {
  if (!isControllerClass(cls)) return;

  const guards = getUseGuardsArgs(cls);
  const className = cls.getName() || 'Unknown';

  if (filePath.includes('/platform/')) return;
  if (className.toLowerCase().includes('webhook')) return;
  if (filePath.includes('/control-plane/')) return;
  if (className.toLowerCase().includes('oauth')) return;

  if (guards.length === 0) {
    if (!hasDecorator(cls, 'Public')) {
      findings.push({
        file: relativePath(filePath),
        line: cls.getStartLineNumber(),
        severity: 'CRITICAL',
        confidence: 95,
        issue: `${className} has no @UseGuards decorator`,
        fix: 'Add @UseGuards(AuthGuard, TenantGuard, RolesGuard)',
      });
    }
    return;
  }

  // Check first guard is an auth guard
  const firstGuard = guards[0];
  if (!firstGuard.includes('Auth') && !firstGuard.includes('auth')) {
    findings.push({
      file: relativePath(filePath),
      line: cls.getStartLineNumber(),
      severity: 'CRITICAL',
      confidence: 95,
      issue: `${className} guard chain doesn't start with an auth guard (found: ${firstGuard})`,
      fix: 'Auth guard must be the first guard in @UseGuards()',
    });
  }

  const hasTenantGuard = guards.includes('TenantGuard');
  const hasRolesGuard = guards.includes('RolesGuard');
  if (hasTenantGuard && !hasRolesGuard) {
    findings.push({
      file: relativePath(filePath),
      line: cls.getStartLineNumber(),
      severity: 'WARNING',
      confidence: 80,
      issue: `${className} has TenantGuard but no RolesGuard`,
      fix: 'Add RolesGuard after TenantGuard: @UseGuards(AuthGuard, TenantGuard, RolesGuard)',
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
  if (!httpMethod) return;

  const methodName = method.getName();
  const classGuards = getUseGuardsArgs(cls);

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
      fix: `Add @Roles(...) or @Public()`,
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

  if (classGuards.includes('TenantGuard')) {
    const hasTenantParam =
      paramDecorators.includes('CurrentTenant') ||
      paramDecorators.includes('CurrentOrgId') ||
      paramDecorators.includes('CurrentMembership');

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
  if (filePath.includes('/platform/')) return;

  const classes = sourceFile.getClasses();

  for (const cls of classes) {
    const methods = cls.getMethods();

    for (const method of methods) {
      const methodName = method.getName();
      const body = method.getBody()?.getText() || '';

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
          methodName.startsWith('_');

        if (!hasTenantScope) {
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

// ─── Universal Checks ───

// Bug 17 fix: check for comments in empty catch blocks
function checkEmptyCatchBlocks(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();

  sourceFile.getDescendantsOfKind(SyntaxKind.CatchClause).forEach(catchClause => {
    const block = catchClause.getBlock();
    const statements = block.getStatements();

    if (statements.length === 0) {
      // Check if block contains comments (not flagged by statements)
      const blockText = block.getFullText();
      const hasComment = /\/\/|\/\*/.test(blockText);
      if (hasComment) return; // Has comments — intentionally empty, don't flag

      findings.push({
        file: relativePath(filePath),
        line: catchClause.getStartLineNumber(),
        severity: 'WARNING',
        confidence: 85,
        issue: 'Empty catch block swallows errors silently',
        fix: 'Add error logging, re-throw, or add a comment explaining why',
      });
    }
  });
}

function checkConsoleLog(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();

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
        fix: 'Use a proper logger instead, or remove',
      });
    }
  });
}

function checkRawSql(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();

  sourceFile.getDescendantsOfKind(SyntaxKind.CallExpression).forEach(call => {
    const text = call.getExpression().getText();
    if (text.includes('$queryRaw') || text.includes('$executeRaw')) {
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
          fix: 'Move to environment variable and use config service',
        });
      }
    }
  }
}

// Bug 18 fix: Only flag innerHTML WRITES, not reads
function checkInnerHtmlWrites(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();
  if (filePath.includes('.spec.') || filePath.includes('.test.')) return;

  sourceFile.getDescendantsOfKind(SyntaxKind.BinaryExpression).forEach(expr => {
    const left = expr.getLeft().getText();
    const operator = expr.getOperatorToken().getText();

    // Only flag assignments: .innerHTML = ... or .innerHTML += ...
    if ((operator === '=' || operator === '+=') && left.includes('.innerHTML')) {
      findings.push({
        file: relativePath(filePath),
        line: expr.getStartLineNumber(),
        severity: 'CRITICAL',
        confidence: 90,
        issue: 'Direct innerHTML assignment — XSS risk',
        fix: 'Use textContent, DOM APIs, or a sanitizer library instead',
      });
    }
  });
}

// Bug 16 fix: Skip constants/config files for hardcoded model name check
function isConstantsFile(filePath: string): boolean {
  const lower = filePath.toLowerCase();
  return (
    lower.includes('/constants/') ||
    lower.includes('/config/') ||
    lower.includes('/settings/') ||
    lower.includes('constant') ||
    lower.includes('config') ||
    lower.includes('.config.') ||
    lower.includes('model') // e.g., models.ts defining model name mappings
  );
}

function checkHardcodedModelNames(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();
  if (filePath.includes('.spec.') || filePath.includes('.test.')) return;
  if (isConstantsFile(filePath)) return;

  const modelPatterns = [
    /['"]gpt-4[^'"]*['"]/,
    /['"]gpt-3[^'"]*['"]/,
    /['"]claude-3[^'"]*['"]/,
    /['"]claude-2[^'"]*['"]/,
    /['"]llama[^'"]*['"]/i,
    /['"]gemini[^'"]*['"]/i,
  ];

  const text = sourceFile.getFullText();
  const lines = text.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Skip comments
    if (line.trim().startsWith('//') || line.trim().startsWith('*')) continue;

    for (const pattern of modelPatterns) {
      if (pattern.test(line)) {
        // Skip if it's an export const (likely constants definition)
        if (/export\s+const\s/.test(line)) continue;

        findings.push({
          file: relativePath(filePath),
          line: i + 1,
          severity: 'WARNING',
          confidence: 70,
          issue: 'Hardcoded AI model name — makes upgrades painful',
          fix: 'Use a config/constants file for model names',
        });
        break; // One finding per line
      }
    }
  }
}

function checkSwitchWithoutDefault(sourceFile: SourceFile, findings: Finding[]): void {
  const filePath = sourceFile.getFilePath();
  if (filePath.includes('.spec.') || filePath.includes('.test.')) return;

  sourceFile.getDescendantsOfKind(SyntaxKind.SwitchStatement).forEach(switchStmt => {
    const clauses = switchStmt.getCaseBlock().getClauses();
    const hasDefault = clauses.some(c => c.getKind() === SyntaxKind.DefaultClause);
    if (!hasDefault) {
      findings.push({
        file: relativePath(filePath),
        line: switchStmt.getStartLineNumber(),
        severity: 'WARNING',
        confidence: 70,
        issue: 'switch statement without default case — may miss enum values',
        fix: 'Add a default case or exhaustive type check',
      });
    }
  });
}

// ─── Main ───

async function main() {
  const changedOnly = process.argv.includes('--changed-only');

  console.log(`${COLORS.bold}AST Code Review${COLORS.nc}`);
  console.log('================================');
  console.log(`  Project: ${CONFIG.isNestJS ? 'NestJS' : 'Generic TypeScript'}`);
  console.log(`  Backend: ${CONFIG.backendPath}`);
  console.log('');

  console.log(`${COLORS.cyan}[1/4] Loading TypeScript project...${COLORS.nc}`);

  const projectOptions: any = {
    skipAddingFilesFromTsConfig: true,
    skipFileDependencyResolution: true,
  };
  if (CONFIG.tsconfigPath) {
    projectOptions.tsConfigFilePath = CONFIG.tsconfigPath;
  }

  const project = new Project(projectOptions);

  // Bug 13 fix: Scan ALL .ts/.tsx files, not just controllers/services
  const backendSrc = path.join(PROJECT_ROOT, CONFIG.backendPath, 'src');
  const frontendSrc = path.join(PROJECT_ROOT, CONFIG.frontendPath, 'src');

  if (changedOnly) {
    try {
      const diffBase = CONFIG.backendPath.replace(/\/$/, '');
      const diffFiles = execSync('git diff --name-only HEAD~1', { encoding: 'utf-8' })
        .trim()
        .split('\n')
        .filter(f => f.endsWith('.ts') || f.endsWith('.tsx'))
        .map(f => path.join(PROJECT_ROOT, f));

      for (const file of diffFiles) {
        try {
          if (fs.existsSync(file)) {
            project.addSourceFileAtPath(file);
          }
        } catch {
          // File might not exist (deleted)
        }
      }
      console.log(`  Scanning ${COLORS.green}${diffFiles.length}${COLORS.nc} changed files`);
    } catch {
      console.log(`  ${COLORS.yellow}Could not get git diff, scanning all files${COLORS.nc}`);
      addAllSourceFiles(project, backendSrc, frontendSrc);
    }
  } else {
    addAllSourceFiles(project, backendSrc, frontendSrc);
  }

  const sourceFiles = project.getSourceFiles();

  // Categorize files
  const controllers = sourceFiles.filter(f => f.getFilePath().endsWith('.controller.ts'));
  const services = sourceFiles.filter(f => f.getFilePath().endsWith('.service.ts'));
  const allTsFiles = sourceFiles;

  console.log(
    `  Found ${COLORS.green}${allTsFiles.length}${COLORS.nc} files` +
    (CONFIG.isNestJS ? ` (${controllers.length} controllers, ${services.length} services)` : ''),
  );
  console.log('');

  const findings: Finding[] = [];

  // ─── NestJS-Specific Checks (conditional) ───
  if (CONFIG.isNestJS) {
    console.log(`${COLORS.cyan}[2/4] Analyzing NestJS controllers...${COLORS.nc}`);

    for (const sourceFile of controllers) {
      const filePath = sourceFile.getFilePath();
      const classes = sourceFile.getClasses();

      for (const cls of classes) {
        checkGuardChain(cls, findings, filePath);
        for (const method of cls.getMethods()) {
          checkMethodDecorators(cls, method, findings, filePath);
          checkParameterUsage(cls, method, findings, filePath);
        }
      }
    }

    console.log(`${COLORS.cyan}[3/4] Analyzing NestJS services...${COLORS.nc}`);

    for (const sourceFile of services) {
      checkServiceTenantScoping(sourceFile, findings);
    }
  } else {
    console.log(`${COLORS.cyan}[2/4] Skipping NestJS checks (not a NestJS project)${COLORS.nc}`);
    console.log(`${COLORS.cyan}[3/4] Running generic checks...${COLORS.nc}`);
  }

  // ─── Universal Checks (always run on all files) ───
  console.log(`${COLORS.cyan}[4/4] Running universal checks on all files...${COLORS.nc}`);

  for (const sourceFile of allTsFiles) {
    checkConsoleLog(sourceFile, findings);
    checkRawSql(sourceFile, findings);
    checkHardcodedSecrets(sourceFile, findings);
    checkEmptyCatchBlocks(sourceFile, findings);
    checkInnerHtmlWrites(sourceFile, findings);
    checkHardcodedModelNames(sourceFile, findings);
    checkSwitchWithoutDefault(sourceFile, findings);
  }

  // ─── Report ───
  console.log('');

  findings.sort((a, b) => {
    if (a.severity !== b.severity) return a.severity === 'CRITICAL' ? -1 : 1;
    return b.confidence - a.confidence;
  });

  const criticals = findings.filter(f => f.severity === 'CRITICAL');
  const warnings = findings.filter(f => f.severity === 'WARNING');

  if (findings.length === 0) {
    console.log(`${COLORS.green}No issues found. All checks passed.${COLORS.nc}`);
  } else {
    console.log(
      `${COLORS.bold}| # | File:Line | Severity | Confidence | Issue | Fix |${COLORS.nc}`,
    );
    console.log('|---|-----------|----------|------------|-------|-----|');

    findings.forEach((f, i) => {
      const sevColor = f.severity === 'CRITICAL' ? COLORS.red : COLORS.yellow;
      console.log(
        `| ${i + 1} | ${f.file}:${f.line} | ${sevColor}${f.severity}${COLORS.nc} | ${f.confidence}% | ${f.issue} | ${f.fix} |`,
      );
    });
  }

  console.log('');
  console.log('================================');
  console.log(
    `  Files scanned:  ${COLORS.bold}${allTsFiles.length}${COLORS.nc}`,
  );
  console.log(
    `  Findings:       ${COLORS.red}${criticals.length} critical${COLORS.nc}, ${COLORS.yellow}${warnings.length} warnings${COLORS.nc}`,
  );

  const filesWithIssues = new Set(findings.map(f => f.file));
  const allFiles = sourceFiles.map(f => relativePath(f.getFilePath()));
  const cleanFiles = allFiles.filter(f => !filesWithIssues.has(f));

  if (cleanFiles.length > 0 && cleanFiles.length <= 20) {
    console.log('');
    console.log(`${COLORS.bold}Clean files (no issues):${COLORS.nc}`);
    cleanFiles.forEach(f => {
      console.log(`  ${COLORS.green}✓${COLORS.nc} ${f}`);
    });
  } else if (cleanFiles.length > 20) {
    console.log(`  ${COLORS.green}${cleanFiles.length} files clean (no issues)${COLORS.nc}`);
  }

  console.log('');

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

function addAllSourceFiles(project: Project, backendSrc: string, frontendSrc: string): void {
  // Add backend source files
  if (fs.existsSync(backendSrc)) {
    project.addSourceFilesAtPaths([
      `${backendSrc}/**/*.ts`,
    ]);
  }

  // Add frontend source files
  if (fs.existsSync(frontendSrc)) {
    project.addSourceFilesAtPaths([
      `${frontendSrc}/**/*.ts`,
      `${frontendSrc}/**/*.tsx`,
    ]);
  }

  // Fallback: if neither exists, try scanning from project root src/
  if (!fs.existsSync(backendSrc) && !fs.existsSync(frontendSrc)) {
    const rootSrc = path.join(PROJECT_ROOT, 'src');
    if (fs.existsSync(rootSrc)) {
      project.addSourceFilesAtPaths([
        `${rootSrc}/**/*.ts`,
        `${rootSrc}/**/*.tsx`,
      ]);
    }
  }
}

main().catch(err => {
  console.error(`${COLORS.red}AST Review failed:${COLORS.nc}`, err.message);
  process.exit(2);
});
