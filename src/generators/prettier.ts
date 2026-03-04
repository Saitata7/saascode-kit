import { execSync } from 'child_process';
import { writeFileSync } from 'fs';
import path from 'path';

interface GeneratorContext {
  language: string;
  packageManager: string;
  frontendFramework: string | null;
  backendFramework: string | null;
}

function installCmd(pkgManager: string): string {
  switch (pkgManager) {
    case 'yarn': return 'yarn add -D';
    case 'pnpm': return 'pnpm add -D';
    default: return 'npm install -D';
  }
}

export async function generatePrettier(root: string, context: GeneratorContext): Promise<void> {
  const { language, packageManager, frontendFramework } = context;

  // Python — Ruff handles formatting. Go — gofmt is built-in.
  if (language === 'python' || language === 'go') return;

  const packages: string[] = ['prettier'];

  if (frontendFramework === 'svelte') packages.push('prettier-plugin-svelte');

  const config: Record<string, unknown> = {
    semi: true,
    singleQuote: true,
    trailingComma: 'all',
    printWidth: 100,
    tabWidth: 2,
  };

  if (frontendFramework === 'svelte') {
    config.plugins = ['prettier-plugin-svelte'];
  }

  // Install packages
  const cmd = `${installCmd(packageManager)} ${packages.join(' ')}`;
  execSync(cmd, { cwd: root, stdio: 'pipe' });

  // Write config
  writeFileSync(path.join(root, '.prettierrc'), JSON.stringify(config, null, 2) + '\n', 'utf-8');
}
