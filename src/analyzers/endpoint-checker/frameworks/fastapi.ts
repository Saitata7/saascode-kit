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
 * Scan FastAPI route definitions.
 * Regex-based: @app.get(), @router.post(), APIRouter prefix.
 */
export async function scanFastAPI(backendPath: string, root: string, apiPrefix?: string): Promise<Endpoint[]> {
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

    // Detect router prefix: router = APIRouter(prefix="/api/users")
    let routerPrefix = '';
    const prefixMatch = content.match(/APIRouter\([^)]*prefix\s*=\s*['"]([^'"]+)['"]/);
    if (prefixMatch) {
      routerPrefix = prefixMatch[1]!;
    }

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]!;

      // @app.get("/path") or @router.post("/path")
      const routeMatch = line.match(/@\w+\.(get|post|put|patch|delete)\(\s*['"]([^'"]+)['"]/);
      if (routeMatch) {
        const method = METHOD_MAP[routeMatch[1]!]!;
        const routeSuffix = routeMatch[2]!;

        const prefix = apiPrefix ?? '';
        const fullPath = `${prefix}${routerPrefix}${routeSuffix}`.replace(/\/+/g, '/') || '/';
        const { normalized, params } = normalizePath(fullPath);

        endpoints.push({
          method,
          rawPath: fullPath,
          normalizedPath: normalized,
          file: filePath,
          line: i + 1,
          framework: 'fastapi',
          confidence: 90,
          params,
        });
      }
    }
  }

  return endpoints;
}
