import { existsSync } from 'fs';
import path from 'path';

/**
 * Find the project root by walking up until .git is found.
 */
export function findProjectRoot(startDir?: string): string {
  let dir = startDir ?? process.cwd();
  while (dir !== path.dirname(dir)) {
    if (existsSync(path.join(dir, '.git'))) return dir;
    dir = path.dirname(dir);
  }
  return startDir ?? process.cwd();
}

/**
 * Resolve a path relative to the project root.
 */
export function resolveProjectPath(relativePath: string, root?: string): string {
  const projectRoot = root ?? findProjectRoot();
  return path.resolve(projectRoot, relativePath);
}

/**
 * Convert an absolute path to relative from project root.
 */
export function toRelative(absolutePath: string, root?: string): string {
  const projectRoot = root ?? findProjectRoot();
  return path.relative(projectRoot, absolutePath);
}
