import { describe, it, expect } from 'vitest';
import { compareEndpoints } from '../../src/analyzers/endpoint-checker/comparator.js';
import type { Endpoint } from '../../src/analyzers/endpoint-checker/types.js';

function makeEndpoint(overrides: Partial<Endpoint>): Endpoint {
  return {
    method: 'GET',
    rawPath: '/api/test',
    normalizedPath: '/api/test',
    file: 'test.ts',
    line: 1,
    framework: 'test',
    confidence: 90,
    params: [],
    ...overrides,
  };
}

describe('compareEndpoints', () => {
  it('matches identical endpoints', () => {
    const fe = [makeEndpoint({ method: 'GET', normalizedPath: '/api/users' })];
    const be = [makeEndpoint({ method: 'GET', normalizedPath: '/api/users' })];
    const result = compareEndpoints(fe, be);

    expect(result.matched).toHaveLength(1);
    expect(result.missingBackend).toHaveLength(0);
    expect(result.orphanedBackend).toHaveLength(0);
  });

  it('detects missing backend routes', () => {
    const fe = [
      makeEndpoint({ method: 'GET', normalizedPath: '/api/users' }),
      makeEndpoint({ method: 'POST', normalizedPath: '/api/orders' }),
    ];
    const be = [makeEndpoint({ method: 'GET', normalizedPath: '/api/users' })];
    const result = compareEndpoints(fe, be);

    expect(result.matched).toHaveLength(1);
    expect(result.missingBackend).toHaveLength(1);
    expect(result.missingBackend[0]!.normalizedPath).toBe('/api/orders');
  });

  it('detects orphaned backend routes', () => {
    const fe = [makeEndpoint({ method: 'GET', normalizedPath: '/api/users' })];
    const be = [
      makeEndpoint({ method: 'GET', normalizedPath: '/api/users' }),
      makeEndpoint({ method: 'DELETE', normalizedPath: '/api/admin/purge' }),
    ];
    const result = compareEndpoints(fe, be);

    expect(result.matched).toHaveLength(1);
    expect(result.orphanedBackend).toHaveLength(1);
    expect(result.orphanedBackend[0]!.normalizedPath).toBe('/api/admin/purge');
  });

  it('detects method mismatches', () => {
    const fe = [makeEndpoint({ method: 'GET', normalizedPath: '/api/orders' })];
    const be = [makeEndpoint({ method: 'POST', normalizedPath: '/api/orders' })];
    const result = compareEndpoints(fe, be);

    expect(result.methodMismatches).toHaveLength(1);
    expect(result.methodMismatches[0]!.path).toBe('/api/orders');
  });

  it('matches normalized param paths', () => {
    const fe = [makeEndpoint({ method: 'GET', normalizedPath: '/api/users/:param', params: ['id'] })];
    const be = [makeEndpoint({ method: 'GET', normalizedPath: '/api/users/:param', params: ['userId'] })];
    const result = compareEndpoints(fe, be);

    expect(result.matched).toHaveLength(1);
    expect(result.paramMismatches).toHaveLength(1); // Different param names
  });

  it('handles empty inputs', () => {
    const result = compareEndpoints([], []);

    expect(result.matched).toHaveLength(0);
    expect(result.missingBackend).toHaveLength(0);
    expect(result.orphanedBackend).toHaveLength(0);
    expect(result.methodMismatches).toHaveLength(0);
  });

  it('handles all frontend missing', () => {
    const fe = [
      makeEndpoint({ method: 'GET', normalizedPath: '/api/missing1' }),
      makeEndpoint({ method: 'POST', normalizedPath: '/api/missing2' }),
    ];
    const be: Endpoint[] = [];
    const result = compareEndpoints(fe, be);

    expect(result.missingBackend).toHaveLength(2);
  });
});
