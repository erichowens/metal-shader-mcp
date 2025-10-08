import { existsSync } from 'fs';
import { dirname, join } from 'path';

// Resolve the project root regardless of current working directory.
// Priority:
// 1) METAL_SHADER_MCP_ROOT env var (absolute path recommended)
// 2) Walk up from this file until we find a directory containing 'Resources'
// 3) Fallback to process.cwd()
export function getProjectRoot(): string {
  const envRoot = process.env.METAL_SHADER_MCP_ROOT;
  if (envRoot && existsSync(join(envRoot, 'Resources'))) return envRoot;

  // Use __dirname (works in CommonJS, which is what tsconfig targets)
  let dir = __dirname;

  // Walk up a few levels to find Resources
  for (let i = 0; i < 6; i++) {
    const candidate = join(dir, '..'.repeat(i));
    if (existsSync(join(candidate, 'Resources'))) return candidate;
  }

  // Fallback
  return process.cwd();
}

export function getResourcesDir(): string {
  return join(getProjectRoot(), 'Resources');
}

export function getCommunicationDir(): string {
  return join(getResourcesDir(), 'communication');
}

export function getScreenshotsDir(): string {
  return join(getResourcesDir(), 'screenshots');
}