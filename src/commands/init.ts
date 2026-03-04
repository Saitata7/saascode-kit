import type { Command } from 'commander';
import { input, select, confirm, checkbox } from '@inquirer/prompts';
import path from 'path';
import { writeManifest } from '../utils/manifest.js';
import {
  detectLanguage,
  detectFrontendFramework,
  detectBackendFramework,
  detectOrm,
  detectPackageManager,
} from '../utils/detect.js';
import { findProjectRoot } from '../utils/paths.js';
import { printHeader, printSuccess } from '../utils/output.js';
import type { Manifest } from '../types/manifest.js';

export function registerInitCommand(program: Command): void {
  program
    .command('init')
    .description('Interactive setup wizard — configure your SaaS project in 60 seconds')
    .argument('[path]', 'Project directory', '.')
    .action(async (projectPath: string) => {
      const root = path.resolve(projectPath);

      printHeader('SAASCODE INIT');
      console.log('  Set up your SaaS project guardrails.\n');

      // Auto-detect defaults
      const detectedLang = detectLanguage(root);
      const detectedFrontend = detectFrontendFramework(root);
      const detectedBackend = detectBackendFramework(root);
      const detectedOrm = detectOrm(root);

      // 1. Project name
      const projectName = await input({
        message: 'Project name',
        default: path.basename(root),
      });

      // 2. Project type
      const projectType = await select({
        message: 'Project type',
        choices: [
          { value: 'multi-tenant-saas', name: 'Multi-tenant SaaS' },
          { value: 'single-tenant', name: 'Single-tenant' },
          { value: 'api-service', name: 'API Service' },
          { value: 'marketplace', name: 'Marketplace' },
          { value: 'platform', name: 'Platform' },
        ],
      });

      // 3. Backend framework
      const backendFramework = await select({
        message: `Backend framework${detectedBackend ? ` (detected: ${detectedBackend})` : ''}`,
        default: detectedBackend ?? undefined,
        choices: [
          { value: 'nextjs', name: 'Next.js (API Routes)' },
          { value: 'express', name: 'Express' },
          { value: 'fastify', name: 'Fastify' },
          { value: 'nestjs', name: 'NestJS' },
          { value: 'hono', name: 'Hono' },
          { value: 'django', name: 'Django' },
          { value: 'flask', name: 'Flask' },
          { value: 'fastapi', name: 'FastAPI' },
          { value: 'rails', name: 'Rails' },
          { value: 'spring', name: 'Spring Boot' },
          { value: 'laravel', name: 'Laravel' },
          { value: 'gin', name: 'Go (Gin)' },
        ],
      });

      // 4. Frontend framework
      const frontendFramework = await select({
        message: `Frontend framework${detectedFrontend ? ` (detected: ${detectedFrontend})` : ''}`,
        default: detectedFrontend ?? undefined,
        choices: [
          { value: 'nextjs', name: 'Next.js' },
          { value: 'react', name: 'React' },
          { value: 'vue', name: 'Vue' },
          { value: 'svelte', name: 'Svelte' },
          { value: 'angular', name: 'Angular' },
          { value: 'none', name: 'None (API only)' },
        ],
      });

      // 5. Language
      const language = await select({
        message: `Language${detectedLang ? ` (detected: ${detectedLang})` : ''}`,
        default: detectedLang,
        choices: [
          { value: 'typescript', name: 'TypeScript' },
          { value: 'javascript', name: 'JavaScript' },
          { value: 'python', name: 'Python' },
          { value: 'go', name: 'Go' },
          { value: 'java', name: 'Java' },
          { value: 'ruby', name: 'Ruby' },
          { value: 'php', name: 'PHP' },
        ],
      });

      // 6. Database
      const database = await select({
        message: 'Database',
        choices: [
          { value: 'postgresql', name: 'PostgreSQL' },
          { value: 'mysql', name: 'MySQL' },
          { value: 'mongodb', name: 'MongoDB' },
          { value: 'sqlite', name: 'SQLite' },
          { value: 'none', name: 'None' },
        ],
      });

      // 7. ORM
      const orm = await select({
        message: `ORM${detectedOrm ? ` (detected: ${detectedOrm})` : ''}`,
        default: detectedOrm ?? undefined,
        choices: [
          { value: 'prisma', name: 'Prisma' },
          { value: 'typeorm', name: 'TypeORM' },
          { value: 'drizzle', name: 'Drizzle' },
          { value: 'django', name: 'Django ORM' },
          { value: 'sqlalchemy', name: 'SQLAlchemy' },
          { value: 'activerecord', name: 'Active Record' },
          { value: 'none', name: 'None' },
        ],
      });

      // 8. Multi-tenant?
      const multiTenant = await confirm({
        message: 'Multi-tenant?',
        default: projectType === 'multi-tenant-saas',
      });

      // 9. Tools to configure
      const tools = await checkbox({
        message: 'Tools to configure',
        choices: [
          { value: 'eslint', name: 'ESLint', checked: true },
          { value: 'prettier', name: 'Prettier', checked: true },
          { value: 'husky', name: 'Husky (git hooks)', checked: true },
          { value: 'semgrep', name: 'Semgrep security rules', checked: true },
        ],
      });

      // Build manifest
      const manifest: Manifest = {
        project: {
          name: projectName,
          type: projectType as Manifest['project']['type'],
        },
        stack: {
          frontend: frontendFramework !== 'none' ? { framework: frontendFramework as any } : undefined,
          backend: {
            framework: backendFramework as any,
            orm: orm !== 'none' ? orm as any : undefined,
            database: database !== 'none' ? database as any : undefined,
          },
          language: language as any,
        },
        auth: {
          multi_tenant: multiTenant,
        },
        tenancy: multiTenant ? {
          enabled: true,
          isolation: 'row-level',
        } : undefined,
      };

      // Write manifest
      const manifestPath = path.join(root, 'manifest.yaml');
      writeManifest(manifest, manifestPath);
      printSuccess(`Created ${manifestPath}`);

      // Suggest next steps
      console.log();
      console.log('  Next steps:');
      if (tools.length > 0) {
        console.log(`  ${tools.map(t => `npx saascode add ${t}`).join('\n  ')}`);
      }
      console.log('  npx saascode check     # Check endpoint parity');
      console.log('  npx saascode review    # Run code review');
      console.log('  npx saascode recommend # Get project health score');
      console.log();
      console.log('  TIP: For AI IDE rules (CLAUDE.md, .cursorrules), try: npx rulesync init');
      console.log();
    });
}
