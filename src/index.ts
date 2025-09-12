import fs from 'fs';
import path from 'path';
import { PNG } from 'pngjs';

export type ShaderMeta = {
  name: string;
  description: string;
  path?: string;
};

const COMM_DIR = path.join(process.cwd(), 'Resources', 'communication');
const SCREENSHOTS_DIR = path.join(process.cwd(), 'Resources', 'screenshots');

function ensureDir(p: string) {
  fs.mkdirSync(p, { recursive: true });
}

function writeJSON(filePath: string, obj: any) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, JSON.stringify(obj, null, 2), 'utf8');
}

export function extractDocstring(code: string): ShaderMeta {
  const trimmed = code.trim();
  let title = '';
  let desc = '';
  const start = trimmed.indexOf('/**');
  if (start >= 0) {
    const end = trimmed.indexOf('*/', start + 3);
    if (end > start) {
      const block = trimmed.slice(start + 3, end);
      const lines = block.split(/\r?\n/).map(l => l.replace(/^\s*\*\s?/, '').trim());
      let i = 0;
      while (i < lines.length && lines[i].length === 0) i++;
      if (i < lines.length) {
        title = lines[i++];
      }
      const descLines: string[] = [];
      while (i < lines.length && lines[i].length > 0) {
        descLines.push(lines[i++]);
      }
      desc = descLines.join(' ');
    }
  }
  if (!title) title = 'Untitled Shader';
  return { name: title, description: desc };
}

export async function setShader(code: string, opts: { name?: string; description?: string; path?: string; save?: boolean; noSnapshot?: boolean } = {}) {
  ensureDir(COMM_DIR);
  const meta = extractDocstring(code);
  const payload: any = {
    action: opts.name || opts.description || opts.path ? 'set_shader_with_meta' : 'set_shader',
    shader_code: code,
    name: opts.name ?? meta.name,
    description: opts.description ?? meta.description,
    path: opts.path ?? '',
    save: Boolean(opts.save),
    no_snapshot: Boolean(opts.noSnapshot),
    timestamp: Date.now() / 1000
  };
  writeJSON(path.join(COMM_DIR, 'commands.json'), payload);
}

function listNewScreenshots(token: string, since: number): string[] {
  if (!fs.existsSync(SCREENSHOTS_DIR)) return [];
  const files = fs.readdirSync(SCREENSHOTS_DIR)
    .filter(f => f.endsWith('.png') && f.includes(token))
    .map(f => path.join(SCREENSHOTS_DIR, f));
  return files.filter(f => {
    try {
      const st = fs.statSync(f);
      return st.mtimeMs >= since;
    } catch { return false; }
  }).sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
}

async function wait(ms: number) { return new Promise(res => setTimeout(res, ms)); }

async function generatePlaceholderPNG(filename: string, label: string) {
  ensureDir(SCREENSHOTS_DIR);
  const width = 512, height = 512;
  const png = new PNG({ width, height });
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = (width * y + x) << 2;
      png.data[idx] = Math.floor((x / width) * 255);
      png.data[idx + 1] = Math.floor((y / height) * 255);
      png.data[idx + 2] = 128;
      png.data[idx + 3] = 255;
    }
  }
  const buffer = (PNG as any).sync.write(png as any);
  fs.writeFileSync(filename, buffer);
}

export async function exportFrame(description: string, time?: number, opts: { waitSeconds?: number } = {}) {
  ensureDir(COMM_DIR);
  const now = Date.now();
  const payload: any = { action: 'export_frame', description, time, timestamp: now / 1000 };
  writeJSON(path.join(COMM_DIR, 'commands.json'), payload);

  const waitSeconds = opts.waitSeconds ?? 6;
  const until = Date.now() + waitSeconds * 1000;
  while (Date.now() < until) {
    const found = listNewScreenshots(description, now);
    if (found.length > 0) return found[0];
    await wait(200);
  }
  if (process.env.MCP_FAKE_RENDER === '1') {
    const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19).replace('T', '_');
    const filename = path.join(SCREENSHOTS_DIR, `${ts}_${description}.png`);
    await generatePlaceholderPNG(filename, description);
    return filename;
  }
  throw new Error(`Timed out waiting for exported frame containing '${description}'.`);
}

if (process.argv[1] && path.basename(process.argv[1]).includes('index')) {
  (async () => {
    const cmd = process.argv[2];
    if (cmd === 'set_shader') {
      const fileArg = process.argv[3];
      if (!fileArg) { console.error('Usage: node dist/index.js set_shader <file.metal>'); process.exit(1); }
      const code = fs.readFileSync(fileArg, 'utf8');
      await setShader(code);
      console.log('set_shader command issued.');
    } else if (cmd === 'export_frame') {
      const description = process.argv[3] ?? 'mcp_export';
      const time = process.argv[4] ? Number(process.argv[4]) : undefined;
      const out = await exportFrame(description, time);
      console.log(out);
    } else if (cmd === 'extract_meta') {
      const fileArg = process.argv[3];
      const code = fileArg ? fs.readFileSync(fileArg, 'utf8') : '';
      console.log(JSON.stringify(extractDocstring(code), null, 2));
    }
  })().catch(err => { console.error(err); process.exit(1); });
}
