import chalk from 'chalk';
import type { Finding, ScanResult } from '../types/findings.js';

/**
 * Print a styled header.
 */
export function printHeader(title: string): void {
  const line = '\u2500'.repeat(Math.max(title.length + 4, 40));
  console.log();
  console.log(chalk.bold(`  ${title}`));
  console.log(chalk.dim(`  ${line}`));
}

/**
 * Print a key-value info line.
 */
export function printInfo(label: string, value: string): void {
  console.log(`  ${chalk.dim(label + ':')} ${value}`);
}

/**
 * Print a finding in formatted output.
 */
export function printFinding(finding: Finding): void {
  const icon = finding.severity === 'critical' ? chalk.red('\u2717')
    : finding.severity === 'warning' ? chalk.yellow('\u26A0')
    : chalk.blue('\u2139');

  const severityLabel = finding.severity === 'critical' ? chalk.red('CRITICAL')
    : finding.severity === 'warning' ? chalk.yellow('WARNING')
    : chalk.blue('INFO');

  console.log();
  console.log(`  ${icon} ${severityLabel} ${chalk.dim(`[${finding.ruleId}]`)}`);
  console.log(`    ${finding.issue}`);
  console.log(`    ${chalk.dim('at')} ${finding.file}:${finding.line}`);
  if (finding.fix) {
    console.log(`    ${chalk.green('Fix:')} ${finding.fix}`);
  }
}

/**
 * Print scan summary.
 */
export function printSummary(result: ScanResult): void {
  const criticals = result.findings.filter(f => f.severity === 'critical').length;
  const warnings = result.findings.filter(f => f.severity === 'warning').length;
  const infos = result.findings.filter(f => f.severity === 'info').length;

  const line = '\u2500'.repeat(40);
  console.log();
  console.log(chalk.dim(`  ${line}`));
  console.log(`  Files scanned: ${result.filesScanned}`);
  console.log(`  ${chalk.red(`Critical: ${criticals}`)}  ${chalk.yellow(`Warning: ${warnings}`)}  ${chalk.blue(`Info: ${infos}`)}`);
  console.log(`  Duration: ${(result.duration / 1000).toFixed(1)}s`);
}

/**
 * Print a success message.
 */
export function printSuccess(message: string): void {
  console.log(`  ${chalk.green('\u2713')} ${message}`);
}

/**
 * Print an error message.
 */
export function printError(message: string): void {
  console.log(`  ${chalk.red('\u2717')} ${message}`);
}

/**
 * Print a table of rows with fixed column widths.
 */
export function printTable(headers: string[], rows: string[][], widths?: number[]): void {
  const colWidths = widths ?? headers.map((h, i) => {
    const maxContent = Math.max(h.length, ...rows.map(r => (r[i] ?? '').length));
    return Math.min(maxContent + 2, 50);
  });

  const headerLine = headers.map((h, i) => h.padEnd(colWidths[i]!)).join('  ');
  const separator = colWidths.map(w => '\u2500'.repeat(w)).join('\u2500\u2500');

  console.log(`  ${chalk.bold(headerLine)}`);
  console.log(`  ${chalk.dim(separator)}`);

  for (const row of rows) {
    const line = row.map((cell, i) => cell.padEnd(colWidths[i]!)).join('  ');
    console.log(`  ${line}`);
  }
}
