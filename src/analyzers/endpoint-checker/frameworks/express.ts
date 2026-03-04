import { Project, SyntaxKind, CallExpression } from 'ts-morph';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { normalizePath } from '../normalizer.js';

const HTTP_METHODS: HttpMethod[] = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/**
 * Scan Express/Fastify/Hono route definitions.
 * Detects: app.get(), router.post(), app.use('/prefix', router), etc.
 */
export async function scanExpress(backendPath: string, root: string, apiPrefix?: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  const files = await glob('**/*.{ts,tsx,js,jsx}', {
    cwd: absPath,
    ignore: ['**/node_modules/**', '**/dist/**', '**/test/**', '**/tests/**', '**/*.test.*', '**/*.spec.*'],
    absolute: true,
  });

  if (files.length === 0) return endpoints;

  const project = new Project({ skipAddingFilesFromTsConfig: true });
  project.addSourceFilesAtPaths(files);

  for (const sourceFile of project.getSourceFiles()) {
    const filePath = path.relative(root, sourceFile.getFilePath());
    const calls = sourceFile.getDescendantsOfKind(SyntaxKind.CallExpression);

    for (const call of calls) {
      const expr = call.getExpression();
      if (expr.getKind() !== SyntaxKind.PropertyAccessExpression) continue;

      const propAccess = expr.asKindOrThrow(SyntaxKind.PropertyAccessExpression);
      const methodName = propAccess.getName().toLowerCase();

      if (!HTTP_METHODS.map(m => m.toLowerCase()).includes(methodName)) continue;

      const args = call.getArguments();
      if (args.length === 0) continue;

      const firstArg = args[0]!;
      let routePath: string | null = null;

      if (firstArg.getKind() === SyntaxKind.StringLiteral) {
        routePath = firstArg.asKindOrThrow(SyntaxKind.StringLiteral).getLiteralValue();
      }

      if (!routePath) continue;

      // Apply prefix if provided
      const fullPath = apiPrefix ? `${apiPrefix}${routePath}` : routePath;
      const { normalized, params } = normalizePath(fullPath);

      endpoints.push({
        method: methodName.toUpperCase() as HttpMethod,
        rawPath: fullPath,
        normalizedPath: normalized,
        file: filePath,
        line: call.getStartLineNumber(),
        framework: 'express',
        confidence: 90,
        params,
      });
    }
  }

  return endpoints;
}
