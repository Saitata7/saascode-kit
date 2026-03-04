import { Project, SyntaxKind } from 'ts-morph';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { filePathToRoute, normalizePath } from '../normalizer.js';

const ROUTE_METHODS: HttpMethod[] = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/**
 * Scan Next.js App Router API routes.
 * Looks for app/api/ route.ts files with exported HTTP method handlers.
 */
export async function scanNextjsApp(backendPath: string, root: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  // Find route files in app/api/ or src/app/api/
  const patterns = [
    'app/api/**/route.{ts,tsx,js,jsx}',
    'src/app/api/**/route.{ts,tsx,js,jsx}',
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

  const project = new Project({ skipAddingFilesFromTsConfig: true });
  project.addSourceFilesAtPaths(routeFiles);

  for (const sourceFile of project.getSourceFiles()) {
    const filePath = path.relative(root, sourceFile.getFilePath());
    const absFilePath = sourceFile.getFilePath();

    // Determine route root (app/api/ or src/app/api/)
    let routeRoot = '';
    if (absFilePath.includes('/src/app/')) {
      routeRoot = absFilePath.substring(0, absFilePath.indexOf('/src/app/') + '/src/app'.length);
    } else if (absFilePath.includes('/app/')) {
      routeRoot = absFilePath.substring(0, absFilePath.indexOf('/app/') + '/app'.length);
    }

    const routePath = filePathToRoute(absFilePath, routeRoot);

    // Check for exported HTTP method functions
    for (const method of ROUTE_METHODS) {
      const hasExport = sourceFile.getExportedDeclarations().has(method);
      if (hasExport) {
        const { normalized, params } = normalizePath(routePath);
        endpoints.push({
          method,
          rawPath: routePath,
          normalizedPath: normalized,
          file: filePath,
          line: 1, // File-system routing — the route IS the file
          framework: 'nextjs-app',
          confidence: 95,
          params,
        });
      }
    }
  }

  return endpoints;
}
