import type { Endpoint, HttpMethod, ParityResult } from './types.js';

/**
 * Compare frontend API calls against backend route definitions.
 * Produces matched, missing, orphaned, and mismatch sets.
 */
export function compareEndpoints(
  frontendEndpoints: Endpoint[],
  backendEndpoints: Endpoint[],
): ParityResult {
  const result: ParityResult = {
    matched: [],
    missingBackend: [],
    orphanedBackend: [],
    methodMismatches: [],
    paramMismatches: [],
  };

  // Build lookup maps: METHOD|normalizedPath → endpoint[]
  const backendMap = new Map<string, Endpoint[]>();
  const backendPathMap = new Map<string, Endpoint[]>();
  const matchedBackendKeys = new Set<string>();

  for (const ep of backendEndpoints) {
    // Skip unknown/placeholder endpoints
    if (ep.normalizedPath === '[unknown]') continue;

    const key = `${ep.method}|${ep.normalizedPath}`;
    if (!backendMap.has(key)) backendMap.set(key, []);
    backendMap.get(key)!.push(ep);

    // Also index by path only for method mismatch detection
    if (!backendPathMap.has(ep.normalizedPath)) backendPathMap.set(ep.normalizedPath, []);
    backendPathMap.get(ep.normalizedPath)!.push(ep);
  }

  // Match frontend → backend
  const matchedFrontendIndices = new Set<number>();

  for (let i = 0; i < frontendEndpoints.length; i++) {
    const fe = frontendEndpoints[i]!;
    const key = `${fe.method}|${fe.normalizedPath}`;

    const beMatches = backendMap.get(key);
    if (beMatches && beMatches.length > 0) {
      // Exact match: method + path
      const be = beMatches[0]!;
      result.matched.push({ frontend: fe, backend: be });
      matchedBackendKeys.add(key);
      matchedFrontendIndices.add(i);

      // Check param name mismatches (advisory)
      if (fe.params.length > 0 && be.params.length > 0) {
        const feParams = new Set(fe.params);
        const beParams = new Set(be.params);
        const mismatch = ![...feParams].every(p => beParams.has(p));
        if (mismatch) {
          result.paramMismatches.push({
            path: fe.normalizedPath,
            frontend: fe,
            backend: be,
          });
        }
      }
    } else {
      // Check for path match but method mismatch
      const pathMatches = backendPathMap.get(fe.normalizedPath);
      if (pathMatches && pathMatches.length > 0) {
        result.methodMismatches.push({
          path: fe.normalizedPath,
          frontend: fe,
          backend: pathMatches[0]!,
        });
        matchedFrontendIndices.add(i);
        matchedBackendKeys.add(`${pathMatches[0]!.method}|${fe.normalizedPath}`);
      }
    }
  }

  // Unmatched frontend = missing backend (CRITICAL — will 404!)
  for (let i = 0; i < frontendEndpoints.length; i++) {
    if (!matchedFrontendIndices.has(i)) {
      result.missingBackend.push(frontendEndpoints[i]!);
    }
  }

  // Unmatched backend = orphaned (WARNING — may be intentional)
  for (const [key, endpoints] of backendMap) {
    if (!matchedBackendKeys.has(key)) {
      result.orphanedBackend.push(...endpoints);
    }
  }

  return result;
}
