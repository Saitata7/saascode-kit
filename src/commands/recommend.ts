import type { Command } from 'commander';
import { execSync } from 'child_process';
import path from 'path';
import { findProjectRoot } from '../utils/paths.js';

export function registerRecommendCommand(program: Command): void {
  program
    .command('recommend')
    .description('Smart project health scoring and recommendations')
    .option('--json', 'Output as JSON')
    .action(async (opts) => {
      const root = findProjectRoot();

      // Find the recommend.sh script
      const scriptDir = findScriptDir();
      const recommendScript = path.join(scriptDir, 'recommend.sh');

      const args: string[] = [];
      if (opts.json) args.push('--json');

      try {
        execSync(`bash "${recommendScript}" ${args.join(' ')}`, {
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
  const packageRoot = path.resolve(new URL(import.meta.url).pathname, '..', '..', '..');
  return path.join(packageRoot, 'scripts');
}
