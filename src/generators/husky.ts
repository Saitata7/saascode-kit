import { execSync } from 'child_process';
import { mkdirSync, writeFileSync, chmodSync } from 'fs';
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

export async function generateHusky(root: string, context: GeneratorContext): Promise<void> {
  const { language, packageManager } = context;

  // Only for JS/TS projects with npm ecosystem
  if (!['typescript', 'javascript'].includes(language)) return;

  // Install husky and lint-staged
  const packages = ['husky', 'lint-staged'];
  const cmd = `${installCmd(packageManager)} ${packages.join(' ')}`;
  execSync(cmd, { cwd: root, stdio: 'pipe' });

  // Initialize husky
  execSync('npx husky init', { cwd: root, stdio: 'pipe' });

  // Write pre-commit hook: lint-staged
  const huskyDir = path.join(root, '.husky');
  mkdirSync(huskyDir, { recursive: true });
  const preCommit = `npx lint-staged\n`;
  writeFileSync(path.join(huskyDir, 'pre-commit'), preCommit, 'utf-8');
  chmodSync(path.join(huskyDir, 'pre-commit'), 0o755);

  // Write pre-push hook: endpoint parity check
  const prePush = `npx saascode check\n`;
  writeFileSync(path.join(huskyDir, 'pre-push'), prePush, 'utf-8');
  chmodSync(path.join(huskyDir, 'pre-push'), 0o755);

  // Write lint-staged config
  const lintStagedConfig: Record<string, string[]> = {};
  if (language === 'typescript') {
    lintStagedConfig['*.{ts,tsx}'] = ['eslint --fix', 'prettier --write'];
  } else {
    lintStagedConfig['*.{js,jsx}'] = ['eslint --fix', 'prettier --write'];
  }
  lintStagedConfig['*.{json,md,yml,yaml}'] = ['prettier --write'];

  // Write to package.json (as a key) or .lintstagedrc.json
  writeFileSync(
    path.join(root, '.lintstagedrc.json'),
    JSON.stringify(lintStagedConfig, null, 2) + '\n',
    'utf-8',
  );
}
