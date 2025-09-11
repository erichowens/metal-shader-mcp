import { execSync } from 'child_process';
import { MetalShaderMCPServer } from '../src/index';

const BASIC_SHADER = `/**
 * @name Unit Test Gradient
 * @description Simple gradient for tests
 */
struct RasterizerData {
  float4 position [[position]];
  float2 uv;
};

struct Uniforms {
  float time;
  float2 resolution;
  float2 touchPoint;
};

vertex RasterizerData vertexShader(uint vertexID [[vertex_id]]) {
  float2 pos[4] = { float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0) };
  RasterizerData out;
  out.position = float4(pos[vertexID], 0.0, 1.0);
  out.uv = pos[vertexID] * 0.5 + 0.5;
  return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]], constant Uniforms& u [[buffer(0)]]) {
  float2 uv = in.uv;
  float t = (uv.x + uv.y + u.time) - floor(uv.x + uv.y + u.time);
  return float4(t, 0.2, 1.0 - t, 1.0);
}`;

function parseTextContent(resp: any): any {
  const text = resp.content.find((c: any) => c.type === 'text')?.text ?? '';
  try { return JSON.parse(text); } catch { return text; }
}

function hasFfmpeg(): boolean {
  try {
    execSync('command -v ffmpeg', { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

describe('MCP core tools', () => {
  let server: MetalShaderMCPServer;

  beforeAll(() => {
    server = new MetalShaderMCPServer();
  });

  test('set_shader compiles and stores metadata', async () => {
    const res = await server.callTool('set_shader', { source: BASIC_SHADER });
    const body = parseTextContent(res);
    expect(body.success).toBe(true);
    expect(body.compiled).toBe(true);
    expect(body.metadata.name).toBeDefined();
  });

  test('run_frame renders and writes to Resources/screenshots', async () => {
    // Requires shader set from previous test
    const res = await server.callTool('run_frame', { width: 128, height: 128, time: 0.25, name: 'unit_test_frame' });
    const body = parseTextContent(res);
    expect(body.success).toBe(true);
    expect(body.path).toMatch(/Resources\/screenshots\/unit_test_frame\.png$/);
  });

  test('export_sequence generates frames directory when format=frames', async () => {
    const resFrames = await server.callTool('export_sequence', { format: 'frames', duration: 0.5, fps: 4, width: 64, height: 64, name: 'unit_seq_frames' });
    const bodyFrames = parseTextContent(resFrames);
    expect(bodyFrames.success).toBe(true);
    expect(bodyFrames.outputFile).toMatch(/Resources\/screenshots\/unit_seq_frames/);
    expect(bodyFrames.frameCount).toBeGreaterThan(0);
  }, 30000);

  const ffmpegAvailable = hasFfmpeg();
  (ffmpegAvailable ? test : test.skip)('export_sequence generates mp4 and gif when ffmpeg is available', async () => {
    const resMp4 = await server.callTool('export_sequence', { format: 'mp4', duration: 0.5, fps: 4, width: 64, height: 64, name: 'unit_seq' });
    const bodyMp4 = parseTextContent(resMp4);
    expect(bodyMp4.success).toBe(true);
    expect(bodyMp4.format).toBe('mp4');

    const resGif = await server.callTool('export_sequence', { format: 'gif', duration: 0.5, fps: 4, width: 64, height: 64, name: 'unit_seq_gif' });
    const bodyGif = parseTextContent(resGif);
    expect(bodyGif.success).toBe(true);
    expect(bodyGif.format).toBe('gif');
  }, 60000);
});

