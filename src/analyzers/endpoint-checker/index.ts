import { scanFrontend } from './frontend-scanner.js';
import { scanBackend, detectBackendType } from './backend-scanner.js';
import { compareEndpoints } from './comparator.js';
import { reportResults, getExitCode } from './reporter.js';
import type { CheckOptions, ParityResult, ScanContext } from './types.js';
import { loadManifest } from '../../utils/manifest.js';
import { detectFrontendFramework, detectBackendFramework } from '../../utils/detect.js';
import { findProjectRoot } from '../../utils/paths.js';

export type { Endpoint, ParityResult, CheckOptions, HttpMethod } from './types.js';

/**
 * Run the endpoint parity check.
 * This is the main orchestrator for the hero feature.
 */
export async function runParityCheck(options: CheckOptions = {}): Promise<{ result: ParityResult; exitCode: number }> {
  const root = findProjectRoot();

  // Resolve context from manifest or auto-detection
  const context = resolveContext(root, options);

  // Scan frontend and backend
  const [frontendEndpoints, backendEndpoints] = await Promise.all([
    scanFrontend(context.frontendPath, root),
    scanBackend(context.backendPath, root, context.framework, context.apiPrefix),
  ]);

  // Compare
  const result = compareEndpoints(frontendEndpoints, backendEndpoints);

  // Report
  reportResults(result, {
    framework: context.framework,
    frontendPath: context.frontendPath,
    backendPath: context.backendPath,
  }, options);

  return { result, exitCode: getExitCode(result) };
}

function resolveContext(root: string, options: CheckOptions): ScanContext {
  const manifest = loadManifest();

  // Frontend path
  const frontendPath = options.frontendPath
    ?? manifest?.paths?.frontend
    ?? detectFrontendPath(root)
    ?? '.';

  // Backend path
  const backendPath = options.backendPath
    ?? manifest?.paths?.backend
    ?? detectBackendPath(root)
    ?? '.';

  // Framework
  const framework = options.framework
    ?? manifest?.stack?.backend?.framework
    ?? detectBackendType(backendPath, root);

  // API prefix
  const nestjsPrefix = manifest?.stack?.backend?.framework === 'nestjs' ? '/api' : '';
  const apiPrefix = options.apiPrefix ?? nestjsPrefix;

  return { root, frontendPath, backendPath, framework, apiPrefix };
}

function detectFrontendPath(root: string): string | null {
  const { existsSync } = require('fs');
  const path = require('path');
  const candidates = ['apps/portal', 'apps/web', 'apps/frontend', 'frontend', 'client', 'web', 'src', '.'];
  for (const candidate of candidates) {
    if (existsSync(path.join(root, candidate, 'package.json'))) return candidate;
  }
  return null;
}

function detectBackendPath(root: string): string | null {
  const { existsSync } = require('fs');
  const path = require('path');
  const candidates = ['apps/api', 'apps/backend', 'apps/server', 'backend', 'server', 'api', 'src', '.'];
  for (const candidate of candidates) {
    if (existsSync(path.join(root, candidate))) return candidate;
  }
  return null;
}
