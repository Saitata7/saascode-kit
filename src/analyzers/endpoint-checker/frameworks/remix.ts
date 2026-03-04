import { readFileSync } from 'fs';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { normalizePath } from '../normalizer.js';

/**
 * Scan Remix route files.
 * File-system routing: app/routes/ → loader (GET) / action (POST) exports.
 */
export async function scanRemix(backendPath: string, root: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  const files = await glob('app/routes/**/*.{ts,tsx,js,jsx}', {
    cwd: absPath,
    ignore: ['**/node_modules/**'],
    absolute: true,
  });

  for (const file of files) {
    const filePath = path.relative(root, file);
    const content = readFileSync(file, 'utf-8');

    // Convert Remix file path to route
    let routePath = file
      .replace(/.*\/app\/routes/, '')
      .replace(/\.(ts|tsx|js|jsx)$/, '')
      .replace(/\$/g, ':')       // $param → :param
      .replace(/\./g, '/')       // dot notation → slashes
      .replace(/_index$/, '')     // _index → root
      .replace(/\\/g, '/');

    if (!routePath.startsWith('/')) routePath = '/' + routePath;

    const { normalized, params } = normalizePath(routePath);

    // loader = GET
    if (/export\s+(async\s+)?function\s+loader|export\s+const\s+loader/.test(content)) {
      endpoints.push({
        method: 'GET',
        rawPath: routePath,
        normalizedPath: normalized,
        file: filePath,
        line: 1,
        framework: 'remix',
        confidence: 90,
        params,
      });
    }

    // action = POST (can be other methods via request.method)
    if (/export\s+(async\s+)?function\s+action|export\s+const\s+action/.test(content)) {
      endpoints.push({
        method: 'POST',
        rawPath: routePath,
        normalizedPath: normalized,
        file: filePath,
        line: 1,
        framework: 'remix',
        confidence: 85,
        params,
      });
    }
  }

  return endpoints;
}
