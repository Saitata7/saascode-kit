/**
 * Path normalization for endpoint comparison.
 * Converts all param styles to `:param` format for matching.
 */

/**
 * Normalize a URL path for comparison.
 * All dynamic segments become :param for uniform matching.
 */
export function normalizePath(rawPath: string): { normalized: string; params: string[] } {
  const params: string[] = [];
  let normalized = rawPath;

  // Remove leading/trailing slashes, then re-add leading
  normalized = normalized.replace(/\/+$/, '').replace(/^\/+/, '/');
  if (!normalized.startsWith('/')) normalized = '/' + normalized;

  // Next.js file-system routing: [slug] or [...slug] or [[...slug]]
  normalized = normalized.replace(/\[\[\.\.\.(\w+)\]\]/g, (_, name) => {
    params.push(name);
    return ':param';
  });
  normalized = normalized.replace(/\[\.\.\.(\w+)\]/g, (_, name) => {
    params.push(name);
    return ':param';
  });
  normalized = normalized.replace(/\[(\w+)\]/g, (_, name) => {
    params.push(name);
    return ':param';
  });

  // Express/NestJS: :param
  normalized = normalized.replace(/:(\w+)/g, (_, name) => {
    if (!params.includes(name)) params.push(name);
    return ':param';
  });

  // Spring/Go: {param}
  normalized = normalized.replace(/\{(\w+)\}/g, (_, name) => {
    if (!params.includes(name)) params.push(name);
    return ':param';
  });

  // Django/Flask: <type:param> or <param>
  normalized = normalized.replace(/<(?:\w+:)?(\w+)>/g, (_, name) => {
    if (!params.includes(name)) params.push(name);
    return ':param';
  });

  // Remix: $param
  normalized = normalized.replace(/\$(\w+)/g, (_, name) => {
    if (!params.includes(name)) params.push(name);
    return ':param';
  });

  // Remove trailing slashes again after normalization
  normalized = normalized.replace(/\/+$/, '') || '/';

  return { normalized, params };
}

/**
 * Convert a file-system path to a URL path (for Next.js/Remix routing).
 * e.g., app/api/users/[id]/route.ts → /api/users/[id]
 */
export function filePathToRoute(filePath: string, routeRoot: string): string {
  let route = filePath
    .replace(routeRoot, '')
    .replace(/\\/g, '/')
    .replace(/\/route\.(ts|tsx|js|jsx)$/, '')
    .replace(/\/index\.(ts|tsx|js|jsx)$/, '')
    .replace(/\.(ts|tsx|js|jsx)$/, '');

  if (!route.startsWith('/')) route = '/' + route;
  return route || '/';
}
