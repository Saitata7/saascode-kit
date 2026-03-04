import { mkdirSync, appendFileSync } from 'fs';
import path from 'path';
import { findProjectRoot } from './paths.js';

interface LogEntry {
  ts: string;
  source: string;
  severity: string;
  category: string;
  message: string;
  file?: string;
  line?: string;
  detail?: string;
}

/**
 * Append an issue to the daily JSONL log file.
 */
export function logIssue(
  source: string,
  severity: string,
  category: string,
  message: string,
  file?: string,
  line?: number,
  detail?: string,
): void {
  const root = findProjectRoot();
  const logDir = path.join(root, '.saascode', 'logs');
  mkdirSync(logDir, { recursive: true });

  const today = new Date().toISOString().split('T')[0];
  const logFile = path.join(logDir, `issues-${today}.jsonl`);

  const entry: LogEntry = {
    ts: new Date().toISOString(),
    source,
    severity,
    category,
    message,
    file: file ?? '',
    line: line?.toString() ?? '',
    detail: detail ?? '',
  };

  appendFileSync(logFile, JSON.stringify(entry) + '\n', 'utf-8');
}
