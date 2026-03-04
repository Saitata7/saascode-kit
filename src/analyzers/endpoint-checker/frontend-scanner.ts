import { Project, SyntaxKind, Node, CallExpression, StringLiteral, TemplateExpression, NoSubstitutionTemplateLiteral } from 'ts-morph';
import path from 'path';
import { glob } from 'glob';
import type { Endpoint, HttpMethod } from './types.js';
import { normalizePath } from './normalizer.js';

const HTTP_METHODS: HttpMethod[] = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/**
 * Scan frontend source files for API calls.
 * Detects: fetch(), axios, useSWR, useQuery, $fetch, ky, custom clients.
 */
export async function scanFrontend(frontendPath: string, root: string): Promise<Endpoint[]> {
  const endpoints: Endpoint[] = [];
  const absPath = path.resolve(root, frontendPath);

  const files = await glob('**/*.{ts,tsx,js,jsx}', {
    cwd: absPath,
    ignore: ['**/node_modules/**', '**/dist/**', '**/.next/**', '**/coverage/**'],
    absolute: true,
  });

  if (files.length === 0) return endpoints;

  const project = new Project({ skipAddingFilesFromTsConfig: true });
  project.addSourceFilesAtPaths(files);

  for (const sourceFile of project.getSourceFiles()) {
    const filePath = path.relative(root, sourceFile.getFilePath());
    const calls = sourceFile.getDescendantsOfKind(SyntaxKind.CallExpression);

    for (const call of calls) {
      const extracted = extractApiCall(call, filePath);
      if (extracted) endpoints.push(...extracted);
    }
  }

  return endpoints;
}

function extractApiCall(call: CallExpression, filePath: string): Endpoint[] | null {
  const expr = call.getExpression();
  const exprText = expr.getText();

  // Pattern 1: fetch('/api/...', { method: 'POST' })
  if (exprText === 'fetch' || exprText.endsWith('.fetch') || exprText === '$fetch') {
    return extractFetchCall(call, filePath);
  }

  // Pattern 2: axios.get('/api/...') or apiClient.get('/api/...')
  if (expr.getKind() === SyntaxKind.PropertyAccessExpression) {
    const propAccess = expr.asKindOrThrow(SyntaxKind.PropertyAccessExpression);
    const methodName = propAccess.getName().toUpperCase();
    if (HTTP_METHODS.includes(methodName as HttpMethod)) {
      return extractMethodCall(call, methodName as HttpMethod, filePath);
    }
  }

  // Pattern 3: useSWR('/api/...') — always GET
  if (exprText === 'useSWR' || exprText === 'useSWRImmutable') {
    return extractSwrCall(call, filePath);
  }

  // Pattern 4: trpc.<router>.<procedure>.useQuery() / useMutation()
  if (exprText.includes('trpc') || exprText.includes('api.')) {
    return extractTrpcCall(call, filePath);
  }

  return null;
}

function extractFetchCall(call: CallExpression, filePath: string): Endpoint[] | null {
  const args = call.getArguments();
  if (args.length === 0) return null;

  const urlArg = args[0]!;
  const url = extractStringValue(urlArg);
  if (!url || !looksLikeApiPath(url)) return null;

  // Determine method from options object
  let method: HttpMethod = 'GET';
  if (args.length >= 2) {
    const optionsArg = args[1]!;
    if (optionsArg.getKind() === SyntaxKind.ObjectLiteralExpression) {
      const obj = optionsArg.asKindOrThrow(SyntaxKind.ObjectLiteralExpression);
      const methodProp = obj.getProperty('method');
      if (methodProp && Node.isPropertyAssignment(methodProp)) {
        const init = methodProp.getInitializer();
        if (init) {
          const val = extractStringValue(init)?.toUpperCase();
          if (val && HTTP_METHODS.includes(val as HttpMethod)) {
            method = val as HttpMethod;
          }
        }
      }
    }
  }

  const { normalized, params } = normalizePath(url);
  return [{
    method,
    rawPath: url,
    normalizedPath: normalized,
    file: filePath,
    line: call.getStartLineNumber(),
    framework: 'fetch',
    confidence: 90,
    params,
  }];
}

function extractMethodCall(call: CallExpression, method: HttpMethod, filePath: string): Endpoint[] | null {
  const args = call.getArguments();
  if (args.length === 0) return null;

  const urlArg = args[0]!;
  const url = extractStringValue(urlArg);
  if (!url || !looksLikeApiPath(url)) return null;

  const { normalized, params } = normalizePath(url);
  return [{
    method,
    rawPath: url,
    normalizedPath: normalized,
    file: filePath,
    line: call.getStartLineNumber(),
    framework: 'axios',
    confidence: 90,
    params,
  }];
}

function extractSwrCall(call: CallExpression, filePath: string): Endpoint[] | null {
  const args = call.getArguments();
  if (args.length === 0) return null;

  const urlArg = args[0]!;
  const url = extractStringValue(urlArg);
  if (!url || !looksLikeApiPath(url)) return null;

  const { normalized, params } = normalizePath(url);
  return [{
    method: 'GET' as HttpMethod,
    rawPath: url,
    normalizedPath: normalized,
    file: filePath,
    line: call.getStartLineNumber(),
    framework: 'swr',
    confidence: 85,
    params,
  }];
}

function extractTrpcCall(call: CallExpression, filePath: string): Endpoint[] | null {
  const expr = call.getExpression();
  const exprText = expr.getText();

  // Match patterns like:
  //   trpc.user.getAll.useQuery()    → GET /api/trpc/user.getAll
  //   trpc.order.create.useMutation() → POST /api/trpc/order.create
  //   api.user.list.useQuery()       → GET /api/trpc/user.list

  const isQuery = exprText.endsWith('.useQuery') || exprText.endsWith('.useInfiniteQuery');
  const isMutation = exprText.endsWith('.useMutation');
  if (!isQuery && !isMutation) return null;

  // Strip the hook suffix to get the procedure path
  const procedurePath = exprText
    .replace(/\.(useQuery|useInfiniteQuery|useMutation)$/, '')
    .replace(/^(trpc|api)\./, '');

  if (!procedurePath) return null;

  const routePath = `/api/trpc/${procedurePath.replace(/\./g, '/')}`;
  const method: HttpMethod = isMutation ? 'POST' : 'GET';
  const { normalized, params } = normalizePath(routePath);

  return [{
    method,
    rawPath: routePath,
    normalizedPath: normalized,
    file: filePath,
    line: call.getStartLineNumber(),
    framework: 'trpc',
    confidence: 75,
    params,
  }];
}

function extractStringValue(node: Node): string | null {
  if (Node.isStringLiteral(node)) {
    return (node as StringLiteral).getLiteralValue();
  }
  if (Node.isNoSubstitutionTemplateLiteral(node)) {
    return (node as NoSubstitutionTemplateLiteral).getLiteralValue();
  }
  if (Node.isTemplateExpression(node)) {
    // For template literals like `/api/users/${id}`, extract the static prefix
    const head = (node as TemplateExpression).getHead().getText().slice(1); // Remove leading backtick
    if (head && looksLikeApiPath(head)) {
      // Return prefix with a generic param placeholder
      return head + ':param';
    }
  }
  return null;
}

function looksLikeApiPath(url: string): boolean {
  return url.startsWith('/api') || url.startsWith('/v1') || url.startsWith('/v2') || url.startsWith('/rest');
}
