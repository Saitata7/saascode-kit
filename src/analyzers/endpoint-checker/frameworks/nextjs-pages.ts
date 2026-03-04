import { readFileSync } from 'fs';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { filePathToRoute, normalizePath } from '../normalizer.js';

/**
 * Scan Next.js Pages Router API routes.
 * Looks for pages/api/ directory files with default exports.
 */
export async function scanNextjsPages(backendPath: string, root: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  const patterns = [
    'pages/api/**/*.{ts,tsx,js,jsx}',
    'src/pages/api/**/*.{ts,tsx,js,jsx}',
  ];

  let routeFiles: string[] = [];
  for (const pattern of patterns) {
    const files = await glob(pattern, {
      cwd: absPath,
      ignore: ['**/node_modules/**'],
      absolute: true,
    });
    routeFiles.push(...files);
  }

  if (routeFiles.length === 0) return endpoints;

  for (const file of routeFiles) {
    const filePath = path.relative(root, file);
    const content = readFileSync(file, 'utf-8');

    // Determine route root
    let routeRoot = '';
    if (file.includes('/src/pages/')) {
      routeRoot = file.substring(0, file.indexOf('/src/pages/') + '/src/pages'.length);
    } else if (file.includes('/pages/')) {
      routeRoot = file.substring(0, file.indexOf('/pages/') + '/pages'.length);
    }

    const routePath = filePathToRoute(file, routeRoot);
    const { normalized, params } = normalizePath(routePath);

    // Pages Router: default export handles all methods
    // Check for req.method checks to determine specific methods
    const methods: HttpMethod[] = [];
    const methodChecks = content.match(/req\.method\s*===?\s*['"](\w+)['"]/g);
    if (methodChecks) {
      for (const check of methodChecks) {
        const method = check.match(/['"](\w+)['"]/)?.[1]?.toUpperCase();
        if (method && ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
          methods.push(method as HttpMethod);
        }
      }
    }

    // If no method checks found, assume GET and POST
    if (methods.length === 0) {
      methods.push('GET', 'POST');
    }

    for (const method of methods) {
      endpoints.push({
        method,
        rawPath: routePath,
        normalizedPath: normalized,
        file: filePath,
        line: 1,
        framework: 'nextjs-pages',
        confidence: 85,
        params,
      });
    }
  }

  return endpoints;
}
