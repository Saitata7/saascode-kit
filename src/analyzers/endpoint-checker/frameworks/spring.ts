import { readFileSync } from 'fs';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { normalizePath } from '../normalizer.js';

const MAPPING_MAP: Record<string, HttpMethod> = {
  GetMapping: 'GET',
  PostMapping: 'POST',
  PutMapping: 'PUT',
  PatchMapping: 'PATCH',
  DeleteMapping: 'DELETE',
};

/**
 * Scan Spring Boot controllers for route definitions.
 * Regex-based: @RequestMapping, @GetMapping, @PostMapping, etc.
 */
export async function scanSpring(backendPath: string, root: string, apiPrefix?: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  const files = await glob('**/*Controller.{java,kt}', {
    cwd: absPath,
    ignore: ['**/node_modules/**', '**/target/**', '**/build/**', '**/test/**'],
    absolute: true,
  });

  for (const file of files) {
    const filePath = path.relative(root, file);
    const content = readFileSync(file, 'utf-8');
    const lines = content.split('\n');

    // Extract class-level @RequestMapping
    let classPrefix = '';
    const classMappingMatch = content.match(/@RequestMapping\(\s*(?:value\s*=\s*)?["']([^"']+)["']/);
    if (classMappingMatch) {
      classPrefix = classMappingMatch[1]!;
    }

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]!;

      // @GetMapping("/path"), @PostMapping("/path"), etc.
      for (const [annotation, method] of Object.entries(MAPPING_MAP)) {
        const match = line.match(new RegExp(`@${annotation}\\(\\s*(?:value\\s*=\\s*)?["']([^"']+)["']`));
        if (match) {
          const prefix = apiPrefix ?? '/api';
          const fullPath = `${prefix}${classPrefix}${match[1]}`.replace(/\/+/g, '/');
          const { normalized, params } = normalizePath(fullPath);

          endpoints.push({
            method,
            rawPath: fullPath,
            normalizedPath: normalized,
            file: filePath,
            line: i + 1,
            framework: 'spring',
            confidence: 90,
            params,
          });
        }
      }

      // @RequestMapping with method attribute
      const reqMappingMatch = line.match(/@RequestMapping\(\s*(?:value\s*=\s*)?["']([^"']+)["'].*method\s*=\s*RequestMethod\.(\w+)/);
      if (reqMappingMatch) {
        const prefix = apiPrefix ?? '/api';
        const fullPath = `${prefix}${classPrefix}${reqMappingMatch[1]}`.replace(/\/+/g, '/');
        const { normalized, params } = normalizePath(fullPath);

        endpoints.push({
          method: reqMappingMatch[2]!.toUpperCase() as HttpMethod,
          rawPath: fullPath,
          normalizedPath: normalized,
          file: filePath,
          line: i + 1,
          framework: 'spring',
          confidence: 85,
          params,
        });
      }
    }
  }

  return endpoints;
}
