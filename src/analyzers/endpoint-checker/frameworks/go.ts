import { readFileSync } from 'fs';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { normalizePath } from '../normalizer.js';

const METHOD_MAP: Record<string, HttpMethod> = {
  GET: 'GET',
  POST: 'POST',
  PUT: 'PUT',
  PATCH: 'PATCH',
  DELETE: 'DELETE',
  Get: 'GET',
  Post: 'POST',
  Put: 'PUT',
  Patch: 'PATCH',
  Delete: 'DELETE',
};

/**
 * Scan Go route definitions (Gin, Chi, Gorilla Mux, Echo, Fiber).
 * Regex-based: r.GET(), r.HandleFunc(), e.GET(), etc.
 */
export async function scanGo(backendPath: string, root: string, apiPrefix?: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  const files = await glob('**/*.go', {
    cwd: absPath,
    ignore: ['**/vendor/**', '**/*_test.go'],
    absolute: true,
  });

  for (const file of files) {
    const filePath = path.relative(root, file);
    const content = readFileSync(file, 'utf-8');
    const lines = content.split('\n');

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]!;

      // Gin: r.GET("/path", handler) or group.GET(...)
      // Chi: r.Get("/path", handler)
      // Echo: e.GET("/path", handler)
      // Fiber: app.Get("/path", handler)
      for (const [verb, method] of Object.entries(METHOD_MAP)) {
        const routeMatch = line.match(new RegExp(`\\.(${verb})\\(\\s*"([^"]+)"`));
        if (routeMatch) {
          const prefix = apiPrefix ?? '';
          const routePath = `${prefix}${routeMatch[2]}`.replace(/\/+/g, '/') || '/';
          const { normalized, params } = normalizePath(routePath);

          endpoints.push({
            method,
            rawPath: routePath,
            normalizedPath: normalized,
            file: filePath,
            line: i + 1,
            framework: 'go',
            confidence: 85,
            params,
          });
        }
      }

      // Gorilla Mux: r.HandleFunc("/path", handler).Methods("GET")
      const muxMatch = line.match(/\.HandleFunc\(\s*"([^"]+)".*\.Methods\(\s*"(\w+)"/);
      if (muxMatch) {
        const prefix = apiPrefix ?? '';
        const routePath = `${prefix}${muxMatch[1]}`.replace(/\/+/g, '/') || '/';
        const method = muxMatch[2]!.toUpperCase() as HttpMethod;
        const { normalized, params } = normalizePath(routePath);

        endpoints.push({
          method,
          rawPath: routePath,
          normalizedPath: normalized,
          file: filePath,
          line: i + 1,
          framework: 'go-mux',
          confidence: 85,
          params,
        });
      }
    }
  }

  return endpoints;
}
