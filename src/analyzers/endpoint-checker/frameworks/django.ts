import { readFileSync } from 'fs';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { normalizePath } from '../normalizer.js';

/**
 * Scan Django URL patterns.
 * Regex-based: urlpatterns with path() / re_path().
 */
export async function scanDjango(backendPath: string, root: string, apiPrefix?: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  // Find urls.py files
  const files = await glob('**/urls.py', {
    cwd: absPath,
    ignore: ['**/node_modules/**', '**/venv/**', '**/.venv/**'],
    absolute: true,
  });

  for (const file of files) {
    const filePath = path.relative(root, file);
    const content = readFileSync(file, 'utf-8');
    const lines = content.split('\n');

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]!;

      // Match path('route/', view) patterns
      const pathMatch = line.match(/path\(\s*['"]([^'"]*)['"]/);
      if (pathMatch) {
        const routePath = apiPrefix
          ? `${apiPrefix}/${pathMatch[1]}`
          : `/${pathMatch[1]}`;

        const { normalized, params } = normalizePath(routePath);

        // Django views typically handle multiple methods; default to GET + POST
        for (const method of ['GET', 'POST'] as HttpMethod[]) {
          endpoints.push({
            method,
            rawPath: routePath,
            normalizedPath: normalized,
            file: filePath,
            line: i + 1,
            framework: 'django',
            confidence: 80,
            params,
          });
        }
      }
    }
  }

  // Also scan views for @api_view decorators (DRF)
  const viewFiles = await glob('**/views.py', {
    cwd: absPath,
    ignore: ['**/node_modules/**', '**/venv/**', '**/.venv/**'],
    absolute: true,
  });

  for (const file of viewFiles) {
    const filePath = path.relative(root, file);
    const content = readFileSync(file, 'utf-8');
    const lines = content.split('\n');

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]!;
      // @api_view(['GET', 'POST'])
      const apiViewMatch = line.match(/@api_view\(\s*\[([^\]]+)\]/);
      if (apiViewMatch) {
        const methods = apiViewMatch[1]!.match(/['"](\w+)['"]/g)?.map(m => m.replace(/['"]/g, '').toUpperCase() as HttpMethod) ?? [];
        // We know the methods but not the path from this decorator alone — mark for reference
        for (const method of methods) {
          endpoints.push({
            method,
            rawPath: `[from ${filePath}]`,
            normalizedPath: '[unknown]',
            file: filePath,
            line: i + 1,
            framework: 'django-drf',
            confidence: 60,
            params: [],
          });
        }
      }
    }
  }

  return endpoints;
}
