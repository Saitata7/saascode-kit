import type { Command } from 'commander';
import { generateEslint } from '../generators/eslint.js';
import { generatePrettier } from '../generators/prettier.js';
import { generateHusky } from '../generators/husky.js';
import { generateSemgrep } from '../generators/semgrep.js';
import { printHeader, printSuccess, printError } from '../utils/output.js';
import { findProjectRoot } from '../utils/paths.js';
import { loadManifest } from '../utils/manifest.js';
import { detectLanguage, detectPackageManager, detectFrontendFramework, detectBackendFramework } from '../utils/detect.js';

type GeneratorFn = (root: string, context: GeneratorContext) => Promise<void>;

interface GeneratorContext {
  language: string;
  packageManager: string;
  frontendFramework: string | null;
  backendFramework: string | null;
}

const GENERATORS: Record<string, GeneratorFn> = {
  eslint: generateEslint,
  prettier: generatePrettier,
  husky: generateHusky,
  semgrep: generateSemgrep,
};

export function registerAddCommand(program: Command): void {
  program
    .command('add')
    .description('Add and configure development tools')
    .argument('<tool>', 'Tool to add: eslint, prettier, husky, semgrep, or all')
    .action(async (tool: string) => {
      const root = findProjectRoot();
      const manifest = loadManifest();

      const context: GeneratorContext = {
        language: manifest?.stack?.language ?? detectLanguage(root),
        packageManager: detectPackageManager(root),
        frontendFramework: manifest?.stack?.frontend?.framework ?? detectFrontendFramework(root),
        backendFramework: manifest?.stack?.backend?.framework ?? detectBackendFramework(root),
      };

      printHeader('SAASCODE ADD');

      if (tool === 'all') {
        for (const [name, generator] of Object.entries(GENERATORS)) {
          try {
            await generator(root, context);
            printSuccess(`${name} configured`);
          } catch (error) {
            printError(`${name} failed: ${(error as Error).message}`);
          }
        }
      } else {
        const generator = GENERATORS[tool];
        if (!generator) {
          printError(`Unknown tool: ${tool}. Available: eslint, prettier, husky, semgrep, all`);
          process.exit(1);
        }
        try {
          await generator(root, context);
          printSuccess(`${tool} configured`);
        } catch (error) {
          printError(`${tool} failed: ${(error as Error).message}`);
          process.exit(1);
        }
      }
      console.log();
    });
}
