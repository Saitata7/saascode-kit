/**
 * Finding and report types for code review and analysis.
 */

export type Severity = 'critical' | 'warning' | 'info';
export type Confidence = 'high' | 'medium' | 'low';
export type Tier = 'general' | 'saas';
export type OutputFormat = 'text' | 'json' | 'sarif';

export interface Finding {
  file: string;
  line: number;
  severity: Severity;
  confidence: Confidence;
  category: string;
  issue: string;
  fix?: string;
  ruleId: string;
  tier: Tier;
}

export interface ScanResult {
  findings: Finding[];
  filesScanned: number;
  duration: number;
  exitCode: number;
}

export interface ScanOptions {
  paths: string[];
  saas?: boolean;
  fix?: boolean;
  format?: OutputFormat;
  ci?: boolean;
  changedOnly?: boolean;
}
