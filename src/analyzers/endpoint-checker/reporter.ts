import chalk from 'chalk';
import type { Endpoint, ParityResult, CheckOptions } from './types.js';

/**
 * Format and print parity check results.
 */
export function reportResults(
  result: ParityResult,
  context: { framework: string; frontendPath: string; backendPath: string },
  options: CheckOptions,
): void {
  if (options.format === 'json') {
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  const totalFrontend = result.matched.length + result.missingBackend.length + result.methodMismatches.length;
  const totalBackend = result.matched.length + result.orphanedBackend.length + result.methodMismatches.length;

  // Header
  console.log();
  console.log(chalk.bold('  SAASCODE ENDPOINT CHECK'));
  console.log(chalk.dim('  ' + '\u2500'.repeat(40)));
  console.log(`  ${chalk.dim('Stack:')} ${context.framework}`);
  console.log(`  ${chalk.dim('Backend:')} ${context.backendPath} (${totalBackend} routes)`);
  console.log(`  ${chalk.dim('Frontend:')} ${context.frontendPath} (${totalFrontend} API calls)`);

  // Missing backend routes (CRITICAL)
  for (const fe of result.missingBackend) {
    console.log();
    console.log(`  ${chalk.red('\u2717')} ${chalk.red('MISSING BACKEND ROUTE')}`);
    console.log(`    ${fe.method} ${fe.rawPath}`);
    console.log(`    ${chalk.dim('Called in:')} ${fe.file}:${fe.line}`);
  }

  // Method mismatches
  for (const mm of result.methodMismatches) {
    console.log();
    console.log(`  ${chalk.red('\u2717')} ${chalk.red('METHOD MISMATCH')}`);
    console.log(`    ${mm.path}  ${chalk.dim('frontend=')}${mm.frontend.method}  ${chalk.dim('backend=')}${mm.backend.method}`);
    console.log(`    ${chalk.dim('FE:')} ${mm.frontend.file}:${mm.frontend.line}`);
    console.log(`    ${chalk.dim('BE:')} ${mm.backend.file}:${mm.backend.line}`);
  }

  // Orphaned backend routes (WARNING)
  for (const be of result.orphanedBackend) {
    console.log();
    console.log(`  ${chalk.yellow('\u26A0')} ${chalk.yellow('ORPHANED BACKEND ROUTE')}`);
    console.log(`    ${be.method} ${be.rawPath}`);
    console.log(`    ${chalk.dim('Defined in:')} ${be.file}:${be.line}`);
  }

  // Param mismatches (INFO)
  if (options.verbose) {
    for (const pm of result.paramMismatches) {
      console.log();
      console.log(`  ${chalk.blue('\u2139')} ${chalk.blue('PARAM NAME MISMATCH')}`);
      console.log(`    ${pm.path}`);
      console.log(`    ${chalk.dim('FE params:')} ${pm.frontend.params.join(', ')}`);
      console.log(`    ${chalk.dim('BE params:')} ${pm.backend.params.join(', ')}`);
    }
  }

  // Summary
  console.log();
  console.log(chalk.dim('  ' + '\u2500'.repeat(40)));
  const parts = [
    `${chalk.green('Matched: ' + result.matched.length + ' \u2713')}`,
    `${chalk.red('Missing: ' + result.missingBackend.length + ' \u2717')}`,
    `${chalk.red('Mismatch: ' + result.methodMismatches.length + ' \u2717')}`,
    `${chalk.yellow('Orphaned: ' + result.orphanedBackend.length + ' \u26A0')}`,
  ];
  console.log(`  ${parts.join('  ')}`);
  console.log();
}

/**
 * Determine exit code from parity results.
 * 0 = PASS, 1 = FAIL (missing or method mismatch), 2 = ERROR.
 */
export function getExitCode(result: ParityResult): number {
  if (result.missingBackend.length > 0 || result.methodMismatches.length > 0) {
    return 1;
  }
  return 0;
}
