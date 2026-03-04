import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { writeFileSync, mkdirSync, rmSync } from 'fs';
import path from 'path';
import { detectLanguage, detectPackageManager, getSourceExtensions, getExcludedDirs } from '../../src/utils/detect.js';

const TEST_DIR = path.join(process.cwd(), 'tests', '.tmp-detect-test');

describe('detect utils', () => {
  beforeEach(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterEach(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  describe('detectLanguage', () => {
    it('detects TypeScript from tsconfig.json', () => {
      writeFileSync(path.join(TEST_DIR, 'tsconfig.json'), '{}');
      expect(detectLanguage(TEST_DIR)).toBe('typescript');
    });

    it('detects Go from go.mod', () => {
      writeFileSync(path.join(TEST_DIR, 'go.mod'), 'module example.com');
      expect(detectLanguage(TEST_DIR)).toBe('go');
    });

    it('detects Python from requirements.txt', () => {
      writeFileSync(path.join(TEST_DIR, 'requirements.txt'), 'flask==2.0');
      expect(detectLanguage(TEST_DIR)).toBe('python');
    });

    it('detects Ruby from Gemfile', () => {
      writeFileSync(path.join(TEST_DIR, 'Gemfile'), "source 'https://rubygems.org'");
      expect(detectLanguage(TEST_DIR)).toBe('ruby');
    });

    it('detects Rust from Cargo.toml', () => {
      writeFileSync(path.join(TEST_DIR, 'Cargo.toml'), '[package]');
      expect(detectLanguage(TEST_DIR)).toBe('rust');
    });
  });

  describe('detectPackageManager', () => {
    it('detects pnpm from lockfile', () => {
      writeFileSync(path.join(TEST_DIR, 'pnpm-lock.yaml'), '');
      expect(detectPackageManager(TEST_DIR)).toBe('pnpm');
    });

    it('detects yarn from lockfile', () => {
      writeFileSync(path.join(TEST_DIR, 'yarn.lock'), '');
      expect(detectPackageManager(TEST_DIR)).toBe('yarn');
    });

    it('detects npm from lockfile', () => {
      writeFileSync(path.join(TEST_DIR, 'package-lock.json'), '{}');
      expect(detectPackageManager(TEST_DIR)).toBe('npm');
    });

    it('defaults to npm', () => {
      expect(detectPackageManager(TEST_DIR)).toBe('npm');
    });
  });

  describe('getSourceExtensions', () => {
    it('returns ts/tsx for typescript', () => {
      expect(getSourceExtensions('typescript')).toEqual(['ts', 'tsx']);
    });

    it('returns py for python', () => {
      expect(getSourceExtensions('python')).toEqual(['py']);
    });

    it('returns go for go', () => {
      expect(getSourceExtensions('go')).toEqual(['go']);
    });
  });

  describe('getExcludedDirs', () => {
    it('includes node_modules for all', () => {
      expect(getExcludedDirs('typescript')).toContain('node_modules');
      expect(getExcludedDirs('python')).toContain('node_modules');
    });

    it('includes .next for typescript', () => {
      expect(getExcludedDirs('typescript')).toContain('.next');
    });

    it('includes __pycache__ for python', () => {
      expect(getExcludedDirs('python')).toContain('__pycache__');
    });
  });
});
