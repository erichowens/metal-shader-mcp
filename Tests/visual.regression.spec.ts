import { promises as fs } from 'fs';
import { MetalShaderMCPServer } from '../src/index';

const BASIC_SHADER = `/**
 * @name Visual Baseline Gradient
 * @description Simple gradient for visual regression baselines
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
  return float4(t, 0.3, 1.0 - t, 1.0);
}`;

function parseText(resp: any): any {
  const txt = resp.content.find((c: any) => c.type === 'text')?.text ?? '';
  try { return JSON.parse(txt); } catch { return txt; }
}

describe('Visual regression via MCP baselines', () => {
  let server: MetalShaderMCPServer;

  beforeAll(() => {
    server = new MetalShaderMCPServer();
  });

  test('set_baseline then compare_to_baseline yields diffRatio <= threshold', async () => {
    const width = 128, height = 128;
    const baselineName = 'unit_visual_baseline';

    // Ensure shader is set
    const setRes = await server.callTool('set_shader', { source: BASIC_SHADER });
    const setBody = parseText(setRes);
    expect(setBody.success).toBe(true);

    // Capture baseline
    const baseRes = await server.callTool('set_baseline', {
      name: baselineName,
      renderOptions: { width, height }
    });
    const baseBody = parseText(baseRes);
    expect(baseBody.success).toBe(true);
    expect(typeof baseBody.baselinePath).toBe('string');
    await expect(fs.access(baseBody.baselinePath)).resolves.toBeUndefined();

    // Compare to baseline (same settings → diffRatio near 0)
    const cmpRes = await server.callTool('compare_to_baseline', {
      baselineName,
      threshold: 0.001,
      renderOptions: { width, height }
    });
    const cmpBody = parseText(cmpRes);
    expect(cmpBody.success).toBe(true);
    expect(cmpBody.diffRatio).toBeLessThanOrEqual(0.001);
    expect(typeof cmpBody.diffPath).toBe('string');
    await expect(fs.access(cmpBody.diffPath)).resolves.toBeUndefined();
  }, 20000);
});

