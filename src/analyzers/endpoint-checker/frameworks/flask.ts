import { readFileSync } from 'fs';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { normalizePath } from '../normalizer.js';

/**
 * Scan Flask route definitions.
 * Regex-based: @app.route(), Blueprint routes.
 */
export async function scanFlask(backendPath: string, root: string, apiPrefix?: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  const files = await glob('**/*.py', {
    cwd: absPath,
    ignore: ['**/node_modules/**', '**/venv/**', '**/.venv/**', '**/__pycache__/**', '**/test*/**'],
    absolute: true,
  });

  for (const file of files) {
    const filePath = path.relative(root, file);
    const content = readFileSync(file, 'utf-8');
    const lines = content.split('\n');

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]!;

      // @app.route('/path', methods=['GET', 'POST']) or @bp.route(...)
      const routeMatch = line.match(/@\w+\.route\(\s*['"]([^'"]+)['"]/);
      if (routeMatch) {
        const routePath = apiPrefix ? `${apiPrefix}${routeMatch[1]}` : routeMatch[1]!;
        const { normalized, params } = normalizePath(routePath);

        // Extract methods if specified
        const methodsMatch = line.match(/methods\s*=\s*\[([^\]]+)\]/);
        const methods: HttpMethod[] = methodsMatch
          ? (methodsMatch[1]!.match(/['"](\w+)['"]/g)?.map(m => m.replace(/['"]/g, '').toUpperCase() as HttpMethod) ?? ['GET'])
          : ['GET'];

        for (const method of methods) {
          endpoints.push({
            method,
            rawPath: routePath,
            normalizedPath: normalized,
            file: filePath,
            line: i + 1,
            framework: 'flask',
            confidence: 85,
            params,
          });
        }
      }
    }
  }

  return endpoints;
}
