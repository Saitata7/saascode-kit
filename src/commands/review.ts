import type { Command } from 'commander';
import { execSync } from 'child_process';
import path from 'path';
import { findProjectRoot } from '../utils/paths.js';

export function registerReviewCommand(program: Command): void {
  program
    .command('review')
    .description('Run deterministic AST code review')
    .option('--saas', 'Enable SaaS-specific checks')
    .option('--fix', 'Show fix suggestions prominently')
    .option('--json', 'Output as JSON')
    .option('--sarif', 'Output as SARIF 2.1.0')
    .option('--ci', 'CI mode: exit code 1 on critical issues, no colors')
    .option('--changed-only', 'Only scan git-changed files')
    .argument('[paths...]', 'Files or directories to scan')
    .action(async (paths: string[], opts) => {
      const root = findProjectRoot();

      // Find the ast-review.sh script
      const scriptDir = findScriptDir();
      const reviewScript = path.join(scriptDir, 'ast-review.sh');

      // Build command arguments
      const args: string[] = [];
      if (opts.saas) args.push('--saas');
      if (opts.fix) args.push('--fix');
      if (opts.json) args.push('--json');
      if (opts.sarif) args.push('--sarif');
      if (opts.ci) args.push('--ci');
      if (opts.changedOnly) args.push('--changed-only');
      if (paths.length > 0) args.push(...paths);

      try {
        const result = execSync(`bash "${reviewScript}" ${args.join(' ')}`, {
          cwd: root,
          stdio: 'inherit',
          env: { ...process.env, SAASCODE_KIT_DIR: path.dirname(scriptDir) },
        });
      } catch (error) {
        const exitCode = (error as { status?: number }).status ?? 1;
        process.exit(exitCode);
      }
    });
}

function findScriptDir(): string {
  // When running from npx/installed package, scripts are relative to package root
  const packageRoot = path.resolve(new URL(import.meta.url).pathname, '..', '..', '..');
  const scriptsDir = path.join(packageRoot, 'scripts');
  return scriptsDir;
}
