import path from 'path';
import type { Endpoint } from './types.js';
import { scanNextjsApp } from './frameworks/nextjs-app.js';
import { scanNextjsPages } from './frameworks/nextjs-pages.js';
import { scanExpress } from './frameworks/express.js';
import { scanNestJS } from './frameworks/nestjs.js';
import { scanRemix } from './frameworks/remix.js';
import { scanDjango } from './frameworks/django.js';
import { scanFlask } from './frameworks/flask.js';
import { scanFastAPI } from './frameworks/fastapi.js';
import { scanRails } from './frameworks/rails.js';
import { scanSpring } from './frameworks/spring.js';
import { scanLaravel } from './frameworks/laravel.js';
import { scanGo } from './frameworks/go.js';

type BackendScanner = (backendPath: string, root: string, apiPrefix?: string) => Promise<Endpoint[]>;

const SCANNERS: Record<string, BackendScanner> = {
  'nextjs-app': scanNextjsApp,
  'nextjs-pages': scanNextjsPages,
  'nextjs': scanNextjsApp, // Default to App Router
  express: scanExpress,
  fastify: scanExpress, // Same pattern as Express
  hono: scanExpress,    // Same pattern as Express
  nestjs: scanNestJS,
  remix: scanRemix,
  django: scanDjango,
  flask: scanFlask,
  fastapi: scanFastAPI,
  rails: scanRails,
  spring: scanSpring,
  laravel: scanLaravel,
  gin: scanGo,
  chi: scanGo,
  mux: scanGo,
  go: scanGo,
};

/**
 * Scan backend source files for route definitions.
 * Dispatches to framework-specific scanners.
 */
export async function scanBackend(
  backendPath: string,
  root: string,
  framework: string,
  apiPrefix?: string,
): Promise<Endpoint[]> {
  const scanner = SCANNERS[framework];
  if (!scanner) {
    console.warn(`No scanner available for framework: ${framework}. Falling back to Express patterns.`);
    return scanExpress(backendPath, root, apiPrefix);
  }
  return scanner(backendPath, root, apiPrefix);
}

/**
 * Auto-detect which backend framework scanner to use.
 */
export function detectBackendType(backendPath: string, root: string): string {
  const absPath = path.resolve(root, backendPath);
  const { existsSync, readFileSync } = require('fs');

  // Next.js App Router
  if (existsSync(path.join(absPath, 'app', 'api')) || existsSync(path.join(absPath, 'src', 'app', 'api'))) {
    return 'nextjs-app';
  }

  // Next.js Pages Router
  if (existsSync(path.join(absPath, 'pages', 'api')) || existsSync(path.join(absPath, 'src', 'pages', 'api'))) {
    return 'nextjs-pages';
  }

  // Remix
  if (existsSync(path.join(absPath, 'app', 'routes'))) {
    return 'remix';
  }

  // Check package.json
  const pkgPath = path.join(absPath, 'package.json');
  if (existsSync(pkgPath)) {
    try {
      const pkg = JSON.parse(readFileSync(pkgPath, 'utf-8'));
      const deps = { ...pkg.dependencies, ...pkg.devDependencies };
      if (deps['@nestjs/core']) return 'nestjs';
      if (deps['hono']) return 'express';
      if (deps['fastify']) return 'express';
      if (deps['express']) return 'express';
    } catch { /* ignore */ }
  }

  // Check for manage.py (Django)
  if (existsSync(path.join(absPath, 'manage.py'))) return 'django';

  // Check Gemfile (Rails)
  if (existsSync(path.join(absPath, 'Gemfile'))) return 'rails';

  // Check go.mod (Go)
  if (existsSync(path.join(absPath, 'go.mod'))) return 'go';

  // Check pom.xml (Spring)
  if (existsSync(path.join(absPath, 'pom.xml'))) return 'spring';

  // Check composer.json (Laravel)
  if (existsSync(path.join(absPath, 'composer.json'))) return 'laravel';

  return 'express'; // Default fallback
}
