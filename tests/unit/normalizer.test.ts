import { describe, it, expect } from 'vitest';
import { normalizePath, filePathToRoute } from '../../src/analyzers/endpoint-checker/normalizer.js';

describe('normalizePath', () => {
  it('normalizes Express :param style', () => {
    const result = normalizePath('/api/users/:id');
    expect(result.normalized).toBe('/api/users/:param');
    expect(result.params).toContain('id');
  });

  it('normalizes Next.js [param] style', () => {
    const result = normalizePath('/api/users/[id]');
    expect(result.normalized).toBe('/api/users/:param');
    expect(result.params).toContain('id');
  });

  it('normalizes Spring {param} style', () => {
    const result = normalizePath('/api/users/{id}');
    expect(result.normalized).toBe('/api/users/:param');
    expect(result.params).toContain('id');
  });

  it('normalizes Django <type:param> style', () => {
    const result = normalizePath('/api/users/<int:id>');
    expect(result.normalized).toBe('/api/users/:param');
    expect(result.params).toContain('id');
  });

  it('normalizes Django <param> style', () => {
    const result = normalizePath('/api/users/<id>');
    expect(result.normalized).toBe('/api/users/:param');
    expect(result.params).toContain('id');
  });

  it('normalizes Remix $param style', () => {
    const result = normalizePath('/api/users/$id');
    expect(result.normalized).toBe('/api/users/:param');
    expect(result.params).toContain('id');
  });

  it('normalizes Next.js catch-all [...slug]', () => {
    const result = normalizePath('/api/docs/[...slug]');
    expect(result.normalized).toBe('/api/docs/:param');
    expect(result.params).toContain('slug');
  });

  it('normalizes Next.js optional catch-all [[...slug]]', () => {
    const result = normalizePath('/api/docs/[[...slug]]');
    expect(result.normalized).toBe('/api/docs/:param');
    expect(result.params).toContain('slug');
  });

  it('handles multiple params', () => {
    const result = normalizePath('/api/orgs/:orgId/users/:userId');
    expect(result.normalized).toBe('/api/orgs/:param/users/:param');
    expect(result.params).toContain('orgId');
    expect(result.params).toContain('userId');
  });

  it('removes trailing slashes', () => {
    const result = normalizePath('/api/users/');
    expect(result.normalized).toBe('/api/users');
  });

  it('adds leading slash', () => {
    const result = normalizePath('api/users');
    expect(result.normalized).toBe('/api/users');
  });

  it('handles root path', () => {
    const result = normalizePath('/');
    expect(result.normalized).toBe('/');
  });
});

describe('filePathToRoute', () => {
  it('converts Next.js App Router path to route', () => {
    const result = filePathToRoute('/app/api/users/[id]/route.ts', '/app');
    expect(result).toBe('/api/users/[id]');
  });

  it('converts Next.js Pages Router path to route', () => {
    const result = filePathToRoute('/pages/api/users/index.ts', '/pages');
    expect(result).toBe('/api/users');
  });

  it('handles root route file', () => {
    const result = filePathToRoute('/app/api/route.ts', '/app');
    expect(result).toBe('/api');
  });
});
