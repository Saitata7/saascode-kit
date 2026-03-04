import type { Command } from 'commander';
import { runParityCheck } from '../analyzers/endpoint-checker/index.js';
import type { CheckOptions } from '../analyzers/endpoint-checker/types.js';
import { toSarif } from '../utils/sarif.js';

export function registerCheckCommand(program: Command): void {
  program
    .command('check')
    .description('Check endpoint parity between frontend API calls and backend routes')
    .option('--frontend <path>', 'Frontend source directory')
    .option('--backend <path>', 'Backend source directory')
    .option('--framework <name>', 'Backend framework (nestjs, express, django, etc.)')
    .option('--api-prefix <prefix>', 'API route prefix (e.g., /api)')
    .option('--json', 'Output as JSON')
    .option('--sarif', 'Output as SARIF 2.1.0')
    .option('--verbose', 'Show detailed output including param mismatches')
    .action(async (opts) => {
      const options: CheckOptions = {
        frontendPath: opts.frontend,
        backendPath: opts.backend,
        framework: opts.framework,
        apiPrefix: opts.apiPrefix,
        format: opts.sarif ? 'sarif' : opts.json ? 'json' : 'text',
        verbose: opts.verbose,
      };

      try {
        const { result, exitCode } = await runParityCheck(options);

        if (opts.sarif) {
          const sarifOutput = toSarif({
            findings: [
              ...result.missingBackend.map(ep => ({
                file: ep.file,
                line: ep.line,
                severity: 'critical' as const,
                confidence: 'high' as const,
                category: 'endpoint-parity',
                issue: `Missing backend route: ${ep.method} ${ep.rawPath}`,
                ruleId: 'parity/missing-backend',
                tier: 'general' as const,
              })),
              ...result.methodMismatches.map(mm => ({
                file: mm.frontend.file,
                line: mm.frontend.line,
                severity: 'critical' as const,
                confidence: 'high' as const,
                category: 'endpoint-parity',
                issue: `Method mismatch on ${mm.path}: frontend=${mm.frontend.method}, backend=${mm.backend.method}`,
                ruleId: 'parity/method-mismatch',
                tier: 'general' as const,
              })),
              ...result.orphanedBackend.map(ep => ({
                file: ep.file,
                line: ep.line,
                severity: 'warning' as const,
                confidence: 'medium' as const,
                category: 'endpoint-parity',
                issue: `Orphaned backend route: ${ep.method} ${ep.rawPath}`,
                ruleId: 'parity/orphaned-backend',
                tier: 'general' as const,
              })),
            ],
            filesScanned: 0,
            duration: 0,
            exitCode,
          });
          console.log(JSON.stringify(sarifOutput, null, 2));
        }

        process.exit(exitCode);
      } catch (error) {
        console.error('Error running parity check:', (error as Error).message);
        process.exit(2);
      }
    });
}
