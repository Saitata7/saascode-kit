import { Project, SyntaxKind } from 'ts-morph';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from '../types.js';
import { normalizePath } from '../normalizer.js';

const METHOD_DECORATORS: Record<string, HttpMethod> = {
  Get: 'GET',
  Post: 'POST',
  Put: 'PUT',
  Patch: 'PATCH',
  Delete: 'DELETE',
};

/**
 * Scan NestJS controller files for route definitions.
 * Uses ts-morph AST: @Controller('prefix') + @Get('path') decorators.
 */
export async function scanNestJS(backendPath: string, root: string, apiPrefix?: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, backendPath);

  const files = await glob('**/*.controller.{ts,js}', {
    cwd: absPath,
    ignore: ['**/node_modules/**', '**/dist/**'],
    absolute: true,
  });

  if (files.length === 0) return endpoints;

  const project = new Project({ skipAddingFilesFromTsConfig: true });
  project.addSourceFilesAtPaths(files);

  for (const sourceFile of project.getSourceFiles()) {
    const filePath = path.relative(root, sourceFile.getFilePath());

    for (const classDecl of sourceFile.getClasses()) {
      // Extract @Controller('prefix') path
      let controllerPrefix = '';
      for (const decorator of classDecl.getDecorators()) {
        if (decorator.getName() === 'Controller') {
          const args = decorator.getArguments();
          if (args.length > 0 && args[0]!.getKind() === SyntaxKind.StringLiteral) {
            controllerPrefix = args[0]!.asKindOrThrow(SyntaxKind.StringLiteral).getLiteralValue();
          }
        }
      }

      // Scan methods for @Get(), @Post(), etc.
      for (const method of classDecl.getMethods()) {
        for (const decorator of method.getDecorators()) {
          const decoratorName = decorator.getName();
          const httpMethod = METHOD_DECORATORS[decoratorName];
          if (!httpMethod) continue;

          let methodPath = '';
          const args = decorator.getArguments();
          if (args.length > 0 && args[0]!.getKind() === SyntaxKind.StringLiteral) {
            methodPath = args[0]!.asKindOrThrow(SyntaxKind.StringLiteral).getLiteralValue();
          }

          // Build full path
          const prefix = apiPrefix ?? '/api';
          let fullPath = prefix;
          if (controllerPrefix) fullPath += '/' + controllerPrefix;
          if (methodPath) fullPath += '/' + methodPath;
          fullPath = fullPath.replace(/\/+/g, '/');

          const { normalized, params } = normalizePath(fullPath);

          endpoints.push({
            method: httpMethod,
            rawPath: fullPath,
            normalizedPath: normalized,
            file: filePath,
            line: decorator.getStartLineNumber(),
            framework: 'nestjs',
            confidence: 95,
            params,
          });
        }
      }
    }
  }

  return endpoints;
}
