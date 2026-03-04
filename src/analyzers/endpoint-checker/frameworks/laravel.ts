import { readFileSync } from 'fs';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { normalizePath } from '../normalizer.js';

const METHOD_MAP: Record<string, HttpMethod> = {
  get: 'GET',
  post: 'POST',
  put: 'PUT',
  patch: 'PATCH',
  delete: 'DELETE',
};

/**
 * Scan Laravel route files.
 * Regex-based: Route::get(), Route::post(), Route groups.
 */
export async function scanLaravel(backendPath: string, root: string, apiPrefix?: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  const files = await glob('routes/**/*.php', {
    cwd: absPath,
    ignore: ['**/vendor/**'],
    absolute: true,
  });

  for (const file of files) {
    const filePath = path.relative(root, file);
    const content = readFileSync(file, 'utf-8');
    const lines = content.split('\n');

    // Detect if this is an API route file (routes/api.php has automatic /api prefix)
    const isApiFile = file.endsWith('api.php');
    const filePrefix = isApiFile ? (apiPrefix ?? '/api') : '';

    // Track Route::group prefixes
    const prefixStack: string[] = [];
    const prefixMatch = content.match(/Route::group\(\s*\[.*?'prefix'\s*=>\s*'([^']+)'/g);

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]!;

      // Route::group with prefix
      const groupMatch = line.match(/Route::group\(\s*\[.*?'prefix'\s*=>\s*'([^']+)'/);
      if (groupMatch) {
        prefixStack.push(`/${groupMatch[1]}`);
        continue;
      }

      // Route::get('/path', ...)
      for (const [verb, method] of Object.entries(METHOD_MAP)) {
        const routeMatch = line.match(new RegExp(`Route::${verb}\\(\\s*'([^']+)'`));
        if (routeMatch) {
          const groupPrefix = prefixStack.join('');
          const routePath = `${filePrefix}${groupPrefix}/${routeMatch[1]}`.replace(/\/+/g, '/');
          const { normalized, params } = normalizePath(routePath);

          endpoints.push({
            method,
            rawPath: routePath,
            normalizedPath: normalized,
            file: filePath,
            line: i + 1,
            framework: 'laravel',
            confidence: 90,
            params,
          });
        }
      }

      // Route::resource('users', UserController::class)
      const resourceMatch = line.match(/Route::(?:api)?[Rr]esource\(\s*'([^']+)'/);
      if (resourceMatch) {
        const resource = resourceMatch[1]!;
        const groupPrefix = prefixStack.join('');
        const basePath = `${filePrefix}${groupPrefix}/${resource}`.replace(/\/+/g, '/');

        const restRoutes: [HttpMethod, string][] = [
          ['GET', basePath],
          ['GET', `${basePath}/{id}`],
          ['POST', basePath],
          ['PUT', `${basePath}/{id}`],
          ['DELETE', `${basePath}/{id}`],
        ];

        for (const [method, routePath] of restRoutes) {
          const { normalized, params } = normalizePath(routePath);
          endpoints.push({
            method,
            rawPath: routePath,
            normalizedPath: normalized,
            file: filePath,
            line: i + 1,
            framework: 'laravel',
            confidence: 85,
            params,
          });
        }
      }
    }
  }

  return endpoints;
}
