import { existsSync, readFileSync } from 'fs';
import path from 'path';
import { findProjectRoot } from './paths.js';

type Language = 'typescript' | 'javascript' | 'python' | 'ruby' | 'go' | 'java' | 'kotlin' | 'rust' | 'php';
type PackageManager = 'npm' | 'yarn' | 'pnpm' | 'pip' | 'gem' | 'go' | 'mvn' | 'gradle' | 'cargo' | 'composer';
type FrontendFramework = 'nextjs' | 'react' | 'vue' | 'svelte' | 'angular' | 'nuxt' | 'remix';
type BackendFramework = 'nestjs' | 'express' | 'fastify' | 'hono' | 'django' | 'flask' | 'fastapi' | 'rails' | 'spring' | 'laravel' | 'gin' | 'chi' | 'mux' | 'echo' | 'fiber';
type ORM = 'prisma' | 'typeorm' | 'drizzle' | 'sequelize' | 'mongoose' | 'sqlalchemy' | 'django' | 'activerecord';

interface PackageJson {
  dependencies?: Record<string, string>;
  devDependencies?: Record<string, string>;
}

function readPackageJson(root: string): PackageJson | null {
  const pkgPath = path.join(root, 'package.json');
  if (!existsSync(pkgPath)) return null;
  try {
    return JSON.parse(readFileSync(pkgPath, 'utf-8'));
  } catch {
    return null;
  }
}

function hasDep(pkg: PackageJson | null, name: string): boolean {
  if (!pkg) return false;
  return !!(pkg.dependencies?.[name] || pkg.devDependencies?.[name]);
}

/**
 * Detect language from project files.
 */
export function detectLanguage(root?: string): Language {
  const projectRoot = root ?? findProjectRoot();
  if (existsSync(path.join(projectRoot, 'tsconfig.json'))) return 'typescript';
  if (existsSync(path.join(projectRoot, 'Cargo.toml'))) return 'rust';
  if (existsSync(path.join(projectRoot, 'go.mod'))) return 'go';
  if (existsSync(path.join(projectRoot, 'Gemfile'))) return 'ruby';
  if (existsSync(path.join(projectRoot, 'pom.xml')) || existsSync(path.join(projectRoot, 'build.gradle'))) return 'java';
  if (existsSync(path.join(projectRoot, 'composer.json'))) return 'php';
  if (existsSync(path.join(projectRoot, 'requirements.txt')) || existsSync(path.join(projectRoot, 'pyproject.toml')) || existsSync(path.join(projectRoot, 'Pipfile'))) return 'python';
  if (existsSync(path.join(projectRoot, 'package.json'))) return 'javascript';
  return 'typescript';
}

/**
 * Detect package manager from lockfiles.
 */
export function detectPackageManager(root?: string): PackageManager {
  const projectRoot = root ?? findProjectRoot();
  if (existsSync(path.join(projectRoot, 'yarn.lock'))) return 'yarn';
  if (existsSync(path.join(projectRoot, 'pnpm-lock.yaml'))) return 'pnpm';
  if (existsSync(path.join(projectRoot, 'package-lock.json'))) return 'npm';
  if (existsSync(path.join(projectRoot, 'Pipfile.lock')) || existsSync(path.join(projectRoot, 'requirements.txt'))) return 'pip';
  if (existsSync(path.join(projectRoot, 'Gemfile.lock'))) return 'gem';
  if (existsSync(path.join(projectRoot, 'go.sum'))) return 'go';
  if (existsSync(path.join(projectRoot, 'build.gradle')) || existsSync(path.join(projectRoot, 'build.gradle.kts'))) return 'gradle';
  if (existsSync(path.join(projectRoot, 'pom.xml'))) return 'mvn';
  if (existsSync(path.join(projectRoot, 'Cargo.lock'))) return 'cargo';
  if (existsSync(path.join(projectRoot, 'composer.lock'))) return 'composer';
  return 'npm';
}

/**
 * Detect frontend framework from package.json dependencies.
 */
export function detectFrontendFramework(root?: string): FrontendFramework | null {
  const projectRoot = root ?? findProjectRoot();
  const pkg = readPackageJson(projectRoot);

  if (hasDep(pkg, 'next')) return 'nextjs';
  if (hasDep(pkg, '@remix-run/react')) return 'remix';
  if (hasDep(pkg, 'nuxt') || hasDep(pkg, 'nuxt3')) return 'nuxt';
  if (hasDep(pkg, 'vue')) return 'vue';
  if (hasDep(pkg, 'svelte') || hasDep(pkg, '@sveltejs/kit')) return 'svelte';
  if (hasDep(pkg, '@angular/core')) return 'angular';
  if (hasDep(pkg, 'react')) return 'react';
  return null;
}

/**
 * Detect backend framework from package.json, requirements.txt, etc.
 */
export function detectBackendFramework(root?: string): BackendFramework | null {
  const projectRoot = root ?? findProjectRoot();
  const pkg = readPackageJson(projectRoot);

  // JS/TS frameworks
  if (hasDep(pkg, '@nestjs/core')) return 'nestjs';
  if (hasDep(pkg, 'hono')) return 'hono';
  if (hasDep(pkg, 'fastify')) return 'fastify';
  if (hasDep(pkg, 'express')) return 'express';

  // Python frameworks
  if (existsSync(path.join(projectRoot, 'manage.py'))) return 'django';
  const reqPath = path.join(projectRoot, 'requirements.txt');
  if (existsSync(reqPath)) {
    const reqs = readFileSync(reqPath, 'utf-8').toLowerCase();
    if (reqs.includes('fastapi')) return 'fastapi';
    if (reqs.includes('flask')) return 'flask';
    if (reqs.includes('django')) return 'django';
  }
  const pyprojectPath = path.join(projectRoot, 'pyproject.toml');
  if (existsSync(pyprojectPath)) {
    const pyproject = readFileSync(pyprojectPath, 'utf-8').toLowerCase();
    if (pyproject.includes('fastapi')) return 'fastapi';
    if (pyproject.includes('flask')) return 'flask';
    if (pyproject.includes('django')) return 'django';
  }

  // Ruby
  if (existsSync(path.join(projectRoot, 'Gemfile'))) {
    const gemfile = readFileSync(path.join(projectRoot, 'Gemfile'), 'utf-8');
    if (gemfile.includes("'rails'") || gemfile.includes('"rails"')) return 'rails';
  }

  // Java/Kotlin
  if (existsSync(path.join(projectRoot, 'pom.xml'))) {
    const pom = readFileSync(path.join(projectRoot, 'pom.xml'), 'utf-8');
    if (pom.includes('spring-boot')) return 'spring';
  }

  // PHP
  if (existsSync(path.join(projectRoot, 'composer.json'))) {
    const composer = readFileSync(path.join(projectRoot, 'composer.json'), 'utf-8');
    if (composer.includes('laravel')) return 'laravel';
  }

  // Go
  if (existsSync(path.join(projectRoot, 'go.mod'))) {
    const goMod = readFileSync(path.join(projectRoot, 'go.mod'), 'utf-8');
    if (goMod.includes('github.com/gin-gonic/gin')) return 'gin';
    if (goMod.includes('github.com/go-chi/chi')) return 'chi';
    if (goMod.includes('github.com/gorilla/mux')) return 'mux';
    if (goMod.includes('github.com/labstack/echo')) return 'echo';
    if (goMod.includes('github.com/gofiber/fiber')) return 'fiber';
  }

  return null;
}

/**
 * Detect ORM from project dependencies.
 */
export function detectOrm(root?: string): ORM | null {
  const projectRoot = root ?? findProjectRoot();
  const pkg = readPackageJson(projectRoot);

  if (existsSync(path.join(projectRoot, 'prisma')) || hasDep(pkg, '@prisma/client')) return 'prisma';
  if (hasDep(pkg, 'typeorm')) return 'typeorm';
  if (hasDep(pkg, 'drizzle-orm')) return 'drizzle';
  if (hasDep(pkg, 'sequelize')) return 'sequelize';
  if (hasDep(pkg, 'mongoose')) return 'mongoose';

  // Python ORMs
  const reqPath = path.join(projectRoot, 'requirements.txt');
  if (existsSync(reqPath)) {
    const reqs = readFileSync(reqPath, 'utf-8').toLowerCase();
    if (reqs.includes('sqlalchemy')) return 'sqlalchemy';
  }
  if (existsSync(path.join(projectRoot, 'manage.py'))) return 'django';

  // Ruby
  if (existsSync(path.join(projectRoot, 'Gemfile'))) {
    const gemfile = readFileSync(path.join(projectRoot, 'Gemfile'), 'utf-8');
    if (gemfile.includes("'rails'") || gemfile.includes('"rails"')) return 'activerecord';
  }

  return null;
}

/**
 * Get source file extensions for a language.
 */
export function getSourceExtensions(language?: string): string[] {
  switch (language ?? 'typescript') {
    case 'typescript': return ['ts', 'tsx'];
    case 'javascript': return ['js', 'jsx'];
    case 'python': return ['py'];
    case 'ruby': return ['rb'];
    case 'go': return ['go'];
    case 'java': case 'kotlin': return ['java', 'kt'];
    case 'rust': return ['rs'];
    case 'php': return ['php'];
    default: return ['ts', 'tsx', 'js', 'jsx'];
  }
}

/**
 * Get directories to exclude from scanning.
 */
export function getExcludedDirs(language?: string): string[] {
  const common = ['node_modules', 'dist', '.git', 'coverage'];
  switch (language ?? 'typescript') {
    case 'typescript': case 'javascript': return [...common, '.next', '.turbo'];
    case 'python': return [...common, '__pycache__', 'venv', '.venv', '.tox'];
    case 'ruby': return [...common, 'vendor/bundle', 'tmp'];
    case 'go': return [...common, 'vendor'];
    case 'java': case 'kotlin': return [...common, 'target', 'build', '.gradle'];
    case 'rust': return [...common, 'target'];
    case 'php': return [...common, 'vendor'];
    default: return common;
  }
}

/**
 * Detect if the project is a monorepo.
 */
export function detectMonorepo(root?: string): { isMonorepo: boolean; tool?: string } {
  const projectRoot = root ?? findProjectRoot();
  if (existsSync(path.join(projectRoot, 'turbo.json'))) return { isMonorepo: true, tool: 'turborepo' };
  if (existsSync(path.join(projectRoot, 'pnpm-workspace.yaml'))) return { isMonorepo: true, tool: 'pnpm' };
  if (existsSync(path.join(projectRoot, 'lerna.json'))) return { isMonorepo: true, tool: 'lerna' };
  if (existsSync(path.join(projectRoot, 'nx.json'))) return { isMonorepo: true, tool: 'nx' };

  const pkg = readPackageJson(projectRoot);
  if (pkg && 'workspaces' in (pkg as Record<string, unknown>)) return { isMonorepo: true, tool: 'workspaces' };

  if (existsSync(path.join(projectRoot, 'apps')) || existsSync(path.join(projectRoot, 'packages'))) {
    return { isMonorepo: true };
  }

  return { isMonorepo: false };
}
