import fs from 'fs';
import path from 'path';
import { extractDocstring, exportFrame, setShader } from '../src/index';

describe('MCP headless tools', () => {
  it('extracts title/description from docstring', () => {
    const code = `/**\n * My Shader\n * A cool effect\n */\nfragment float4 fragmentShader() { return float4(1); }`;
    const meta = extractDocstring(code);
    expect(meta.name).toBe('My Shader');
    expect(meta.description).toBe('A cool effect');
  });

  it('exports a frame (fake render)', async () => {
    process.env.MCP_FAKE_RENDER = '1';
    const out = await exportFrame('jest_test_token');
    expect(fs.existsSync(out)).toBe(true);
    expect(path.basename(out)).toMatch(/jest_test_token/);
  }, 20000);

  it('extracts empty docstring as Untitled Shader', () => {
    const meta = extractDocstring('fragment float4 fragmentShader(){return float4(1);}');
    expect(meta.name).toBe('Untitled Shader');
    expect(meta.description).toBe('');
  });

  it('rejects exportFrame with empty description', async () => {
    await expect(exportFrame('')).rejects.toThrow(/description must be a non-empty string/);
  });

  it('rejects setShader with unsafe path', async () => {
    await expect(setShader('fragment float4 fragmentShader(){return float4(1);} ', { path: '../bad' as any })).rejects.toThrow(/unsafe path/);
  });
});