import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { writeFileSync, mkdirSync, rmSync } from 'fs';
import path from 'path';
import { loadManifest, writeManifest, getManifestValue } from '../../src/utils/manifest.js';
import type { Manifest } from '../../src/types/manifest.js';

const TEST_DIR = path.join(process.cwd(), 'tests', '.tmp-manifest-test');

describe('manifest utils', () => {
  beforeEach(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterEach(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  it('loads a valid manifest file', () => {
    const yamlContent = `project:
  name: "TestApp"
  type: "multi-tenant-saas"
stack:
  language: "typescript"
  backend:
    framework: "nestjs"
`;
    writeFileSync(path.join(TEST_DIR, 'manifest.yaml'), yamlContent, 'utf-8');
    const manifest = loadManifest(path.join(TEST_DIR, 'manifest.yaml'));

    expect(manifest).not.toBeNull();
    expect(manifest!.project.name).toBe('TestApp');
    expect(manifest!.project.type).toBe('multi-tenant-saas');
    expect(manifest!.stack?.language).toBe('typescript');
    expect(manifest!.stack?.backend?.framework).toBe('nestjs');
  });

  it('returns null for non-existent file', () => {
    const manifest = loadManifest(path.join(TEST_DIR, 'nonexistent.yaml'));
    expect(manifest).toBeNull();
  });

  it('writes a manifest file', () => {
    const manifest: Manifest = {
      project: { name: 'WriteTest', type: 'api-service' },
      stack: { language: 'python', backend: { framework: 'django' } },
    };

    const outputPath = path.join(TEST_DIR, 'output.yaml');
    writeManifest(manifest, outputPath);

    const loaded = loadManifest(outputPath);
    expect(loaded).not.toBeNull();
    expect(loaded!.project.name).toBe('WriteTest');
    expect(loaded!.stack?.backend?.framework).toBe('django');
  });

  it('gets nested manifest values', () => {
    const manifest: Manifest = {
      project: { name: 'Test', type: 'single-tenant' },
      stack: { backend: { framework: 'express', database: 'postgresql' } },
      paths: { frontend: 'client', backend: 'server' },
    };

    expect(getManifestValue(manifest, 'project.name')).toBe('Test');
    expect(getManifestValue(manifest, 'stack.backend.framework')).toBe('express');
    expect(getManifestValue(manifest, 'stack.backend.database')).toBe('postgresql');
    expect(getManifestValue(manifest, 'paths.frontend')).toBe('client');
    expect(getManifestValue(manifest, 'nonexistent.path')).toBeUndefined();
  });
});
