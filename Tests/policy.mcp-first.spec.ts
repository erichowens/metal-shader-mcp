import { readdirSync, readFileSync, statSync } from 'fs';
import { join, relative } from 'path';

/**
 * Policy test: Enforce MCP-first architecture.
 *
 * Fails if any TypeScript source (outside explicitly permitted files) contains forbidden patterns:
 * - AppleScript usage (osascript, AppleScript, NSAppleScript)
 * - UI/file-bridge control plane under Resources/communication
 * - Deprecated Resources/exports path
 *
 * Allowed exceptions:
 * - src/simple-mcp.ts (deprecated demo; tolerated until fully removed)
 */

type Finding = { file: string; pattern: string; line: number; context: string };

const ROOT = process.cwd();
const SRC_DIR = join(ROOT, 'src');
const FORBIDDEN = [
  /\bosascript\b/i,
  /\bAppleScript\b/,
  /\bNSAppleScript\b/,
  /Resources\/(?:communication|exports)\b/,
];

const ALLOWLIST = new Set<string>([
  'src/simple-mcp.ts',
]);

function walk(dir: string): string[] {
  const out: string[] = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) {
      out.push(...walk(full));
    } else if (st.isFile() && full.endsWith('.ts')) {
      out.push(full);
    }
  }
  return out;
}

function scanFile(path: string): Finding[] {
  const rel = relative(ROOT, path).replaceAll('\\', '/');
  if (ALLOWLIST.has(rel)) return [];
  const text = readFileSync(path, 'utf8');
  const lines = text.split(/\r?\n/);
  const findings: Finding[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    for (const rx of FORBIDDEN) {
      if (rx.test(line)) {
        findings.push({ file: rel, pattern: rx.toString(), line: i + 1, context: line.trim() });
      }
    }
  }
  return findings;
}

describe('Policy: MCP-first enforcement', () => {
  it('contains no forbidden patterns in TypeScript sources (outside allowlist)', () => {
    const files = walk(SRC_DIR);
    const all: Finding[] = files.flatMap(scanFile);
    const msg = all
      .map(f => `${f.file}:${f.line} matches ${f.pattern}\n  ${f.context}`)
      .join('\n');
    if (all.length) {
      console.error('\nForbidden pattern(s) detected. See WARP.md MCP-first policy.');
      console.error(msg);
    }
    expect(all).toHaveLength(0);
  });
});

