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
 * Scan Rails routes.rb for route definitions.
 * Regex-based: resources, get/post/put/patch/delete, namespace/scope.
 */
export async function scanRails(backendPath: string, root: string, apiPrefix?: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  const files = await glob('**/routes.rb', {
    cwd: absPath,
    ignore: ['**/node_modules/**', '**/vendor/**'],
    absolute: true,
  });

  for (const file of files) {
    const filePath = path.relative(root, file);
    const content = readFileSync(file, 'utf-8');
    const lines = content.split('\n');

    const prefixStack: string[] = apiPrefix ? [apiPrefix] : [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]!.trim();

      // namespace :api do / scope '/api' do
      const nsMatch = line.match(/(?:namespace|scope)\s+[:'"](\w+)/);
      if (nsMatch) {
        prefixStack.push(`/${nsMatch[1]}`);
        continue;
      }

      if (line === 'end' && prefixStack.length > (apiPrefix ? 1 : 0)) {
        prefixStack.pop();
        continue;
      }

      // resources :users
      const resourceMatch = line.match(/resources?\s+:(\w+)/);
      if (resourceMatch) {
        const resource = resourceMatch[1]!;
        const prefix = prefixStack.join('');
        const basePath = `${prefix}/${resource}`;

        const restRoutes: [HttpMethod, string][] = [
          ['GET', basePath],
          ['GET', `${basePath}/:param`],
          ['POST', basePath],
          ['PUT', `${basePath}/:param`],
          ['PATCH', `${basePath}/:param`],
          ['DELETE', `${basePath}/:param`],
        ];

        for (const [method, routePath] of restRoutes) {
          const { normalized, params } = normalizePath(routePath);
          endpoints.push({
            method,
            rawPath: routePath,
            normalizedPath: normalized,
            file: filePath,
            line: i + 1,
            framework: 'rails',
            confidence: 85,
            params,
          });
        }
        continue;
      }

      // get '/path', post '/path', etc.
      for (const [verb, method] of Object.entries(METHOD_MAP)) {
        const routeMatch = line.match(new RegExp(`^${verb}\\s+['"]([^'"]+)['"]\s*`));
        if (routeMatch) {
          const prefix = prefixStack.join('');
          const routePath = `${prefix}${routeMatch[1]}`;
          const { normalized, params } = normalizePath(routePath);

          endpoints.push({
            method,
            rawPath: routePath,
            normalizedPath: normalized,
            file: filePath,
            line: i + 1,
            framework: 'rails',
            confidence: 90,
            params,
          });
        }
      }
    }
  }

  return endpoints;
}
