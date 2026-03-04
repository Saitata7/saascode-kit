import { existsSync, mkdirSync, copyFileSync, writeFileSync } from 'fs';
import path from 'path';
import { glob } from 'glob';

interface GeneratorContext {
  language: string;
  packageManager: string;
  frontendFramework: string | null;
  backendFramework: string | null;
}

export async function generateSemgrep(root: string, context: GeneratorContext): Promise<void> {
  const { language } = context;

  // Find saascode-kit's semgrep templates
  const kitDir = findKitDir();
  const semgrepTemplates = path.join(kitDir, 'templates', 'semgrep');

  // Determine which rules apply to this project
  const applicableRules: string[] = ['security.yaml', 'auth-guards.yaml', 'input-validation.yaml'];

  if (['typescript', 'javascript'].includes(language)) {
    applicableRules.push('tenant-isolation.yaml', 'ui-consistency.yaml');
  }
  if (language === 'python') applicableRules.push('python-security.yaml');
  if (language === 'ruby') applicableRules.push('ruby-security.yaml');
  if (language === 'go') applicableRules.push('go-security.yaml');
  if (language === 'java') applicableRules.push('java-security.yaml');
  if (language === 'php') applicableRules.push('php-security.yaml');

  // Copy rules to project
  const targetDir = path.join(root, '.semgrep');
  mkdirSync(targetDir, { recursive: true });

  for (const ruleFile of applicableRules) {
    const src = path.join(semgrepTemplates, ruleFile);
    if (existsSync(src)) {
      copyFileSync(src, path.join(targetDir, ruleFile));
    }
  }

  // Generate .semgrep.yml config
  const semgrepConfig = `rules:
${applicableRules.map(r => `  - .semgrep/${r}`).join('\n')}
`;
  writeFileSync(path.join(root, '.semgrep.yml'), semgrepConfig, 'utf-8');
}

function findKitDir(): string {
  // Resolve relative to this module's location
  const moduleDir = new URL(import.meta.url).pathname;
  return path.resolve(path.dirname(moduleDir), '..', '..');
}
