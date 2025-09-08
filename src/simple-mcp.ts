#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { execSync } from 'child_process';
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';

const server = new Server(
  {
    name: 'shader-playground-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Paths
const SCREENSHOTS_DIR = join(process.cwd(), 'Resources/screenshots');

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'set_shader',
        description: 'Set the shader code in the ShaderPlayground app',
        inputSchema: {
          type: 'object',
          properties: {
            shader_code: {
              type: 'string',
              description: 'Complete Metal fragment shader code',
            },
            description: {
              type: 'string',
              description: 'Description of what this shader does',
            },
          },
          required: ['shader_code'],
        },
      },
      {
        name: 'get_compilation_errors',
        description: 'Get detailed compilation errors and warnings from the current shader',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'get_current_shader',
        description: 'Get the current shader code from ShaderPlayground app',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'export_frame',
        description: 'Export a single rendered frame at a specific time',
        inputSchema: {
          type: 'object',
          properties: {
            description: {
              type: 'string',
              description: 'Description for the frame export',
            },
            time: {
              type: 'number',
              description: 'Time in seconds (optional, uses current time if not specified)',
            },
          },
          required: ['description'],
        },
      },
      {
        name: 'export_sequence',
        description: 'Export a sequence of frames over time to see shader animation',
        inputSchema: {
          type: 'object',
          properties: {
            description: {
              type: 'string',
              description: 'Description for the sequence',
            },
            duration: {
              type: 'number',
              description: 'Duration in seconds (default: 5.0)',
            },
            fps: {
              type: 'number',
              description: 'Frames per second (default: 30)',
            },
          },
          required: ['description'],
        },
      },
      {
        name: 'set_uniforms',
        description: 'Set uniform values for the current shader',
        inputSchema: {
          type: 'object',
          properties: {
            uniforms: {
              type: 'object',
              description: 'Key-value pairs of uniform names and values',
              additionalProperties: {
                oneOf: [
                  { type: 'number' },
                  { type: 'array', items: { type: 'number' } }
                ]
              }
            },
          },
          required: ['uniforms'],
        },
      },
      {
        name: 'list_uniforms',
        description: 'List all available uniforms and their current values',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'get_example_shader',
        description: 'Get an example Metal shader to experiment with',
        inputSchema: {
          type: 'object',
          properties: {
            type: {
              type: 'string',
              enum: ['basic', 'plasma', 'gradient', 'noise', 'spiral', 'ripples'],
              description: 'Type of example shader',
            },
          },
          required: ['type'],
        },
      },

      // ---- Next set of REPL tools (schemas only; handlers stubbed below) ----
      {
        name: 'run_frame',
        description: 'Render a single frame deterministically and return image',
        inputSchema: {
          type: 'object',
          properties: {
            time: { type: 'number', description: 'Time in seconds' },
            uniforms: { type: 'object', description: 'Key-value uniforms' },
            resolution: {
              type: 'object',
              properties: { w: { type: 'number' }, h: { type: 'number' } },
              required: ['w','h']
            },
            seed: { type: 'number', description: 'Random seed' },
            colorspace: { type: 'string', enum: ['sRGB','P3'] }
          },
          required: ['time','resolution']
        }
      },
      { name: 'set_time', description: 'Set the current timeline time', inputSchema: { type: 'object', properties: { time: { type: 'number' } }, required: ['time'] } },
      { name: 'play', description: 'Start timeline playback', inputSchema: { type: 'object', properties: {} } },
      { name: 'pause', description: 'Pause timeline playback', inputSchema: { type: 'object', properties: {} } },
      { name: 'set_playback_speed', description: 'Set timeline speed multiplier', inputSchema: { type: 'object', properties: { speed: { type: 'number' } }, required: ['speed'] } },

      { name: 'set_resolution', description: 'Set render resolution via preset or explicit', inputSchema: { type: 'object', properties: { preset: { type:'string', enum: ['720p','1080p','4k','square','vertical'] }, w: { type:'number' }, h: { type:'number' } } } },
      { name: 'set_aspect', description: 'Set aspect ratio', inputSchema: { type: 'object', properties: { aspect: { type: 'string', enum: ['16:9','9:16','1:1','4:3','3:4','3:2','2:3'] } }, required: ['aspect'] } },
      { name: 'set_device_profile', description: 'Apply device-specific defaults', inputSchema: { type: 'object', properties: { device: { type: 'string', enum: ['macOS','iPhone','iPad'] } }, required: ['device'] } },

      { name: 'set_seed', description: 'Set deterministic random seed', inputSchema: { type: 'object', properties: { seed: { type: 'number' } }, required: ['seed'] } },
      { name: 'randomize_seed', description: 'Randomize seed', inputSchema: { type: 'object', properties: {} } },

      { name: 'set_mouse', description: 'Set mouse position (normalized or px depending on app)', inputSchema: { type: 'object', properties: { x: { type:'number' }, y: { type:'number' } }, required: ['x','y'] } },
      { name: 'simulate_touch_path', description: 'Drive interaction along a path', inputSchema: { type: 'object', properties: { path: { type:'array', items: { type:'array', items:{ type:'number' } } } }, required: ['path'] } },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'set_shader': {
        if (!args) {
            return { text: [{ text: 'Missing arguments for set_shader' }] };
        }
        
        const shaderCode = args.shader_code as string;
        const description = args.description as string || 'mcp_shader';
        
        // Write command to communication file
        const command = {
          action: 'set_shader',
          shader_code: shaderCode,
          description,
          timestamp: Date.now()
        };
        
        const commandFile = 'Resources/communication/commands.json';
        const statusFile = 'Resources/communication/status.json';
        
        try {
          // Ensure communication directory exists
          execSync('mkdir -p Resources/communication');
          
          // Write command
          writeFileSync(commandFile, JSON.stringify(command, null, 2));
          
          // Wait for command to be processed
          let attempts = 0;
          const maxAttempts = 50; // 5 seconds
          
          while (attempts < maxAttempts) {
            await new Promise(resolve => setTimeout(resolve, 100));
            
            if (!existsSync(commandFile)) {
              // Command was processed
              if (existsSync(statusFile)) {
                const status = JSON.parse(readFileSync(statusFile, 'utf8'));
                if (status.success) {
                  return {
                    content: [
                      {
                        type: 'text',
                        text: `✅ Shader code updated successfully!\n\n${description}\n\nThe shader has been compiled and is now running in the ShaderPlayground app.`,
                      },
                    ],
                  };
                } else {
                  return {
                    content: [
                      {
                        type: 'text',
                        text: `❌ Shader update failed: ${status.error || 'Unknown error'}`,
                      },
                    ],
                    isError: true,
                  };
                }
              }
              break;
            }
            attempts++;
          }
          
          if (attempts >= maxAttempts) {
            return {
              content: [
                {
                  type: 'text',
                  text: '⏰ Shader update timed out. Make sure ShaderPlayground app is running.',
                },
              ],
              isError: true,
            };
          }
        } catch (error) {
          return {
            content: [
              {
                type: 'text',
                text: `❌ Failed to set shader: ${error}`,
              },
            ],
            isError: true,
          };
        }
      }
      
      case 'get_current_shader': {
        try {
          const shaderFile = 'Resources/communication/current_shader.metal';
          if (existsSync(shaderFile)) {
            const currentShader = readFileSync(shaderFile, 'utf8');
            return {
              content: [
                {
                  type: 'text',
                  text: `📝 Current shader code:\n\n\`\`\`metal\n${currentShader}\n\`\`\``,
                },
              ],
            };
          } else {
            return {
              content: [
                {
                  type: 'text',
                  text: '❌ No shader state file found. Make sure ShaderPlayground app is running.',
                },
              ],
              isError: true,
            };
          }
        } catch (error) {
          return {
            content: [
              {
                type: 'text',
                text: `❌ Failed to get shader: ${error}`,
              },
            ],
            isError: true,
          };
        }
      }
      
      case 'export_frame': {
        if (!args) {
            return { text: [{ text: 'Missing arguments for export_frame' }] };
        }
        
        const description = args.description as string;
        const time = args.time as number | undefined;
        
        // Trigger frame export via AppleScript to call app function
        const timeParam = time !== undefined ? `, time: ${time}` : '';
        const appleScriptCmd = `osascript -e 'tell application "ShaderPlayground" to activate' -e 'delay 0.5' -e 'tell application "System Events" to tell process "ShaderPlayground" to click button "Export Frame" of window 1'`;
        
        try {
          execSync(appleScriptCmd, { encoding: 'utf8' });
          
          // Wait a moment for export to complete
          await new Promise(resolve => setTimeout(resolve, 1000));
          
          // Find the latest export
          const exportsDir = 'Resources/exports';
          const latestFile = execSync(`ls -t ${exportsDir}/*.png | head -1`, { encoding: 'utf8' }).trim();
          
          if (existsSync(latestFile)) {
            const imageBuffer = readFileSync(latestFile);
            
            return {
              content: [
                {
                  type: 'image',
                  data: imageBuffer.toString('base64'),
                  mimeType: 'image/png',
                },
                {
                  type: 'text',
                  text: `🎨 Frame exported: ${description}\n\nFile: ${latestFile}\n\nThis is a direct render from the Metal shader at ${time !== undefined ? `t=${time}s` : 'current time'}.`,
                },
              ],
            };
          } else {
            throw new Error('Export file not found');
          }
        } catch (error) {
          return {
            content: [
              {
                type: 'text',
                text: `❌ Export failed: ${error}\n\nMake sure ShaderPlayground app is running and visible.`,
              },
            ],
            isError: true,
          };
        }
      }

      case 'get_compilation_errors': {
        try {
          const errorsFile = 'Resources/communication/compilation_errors.json';
          if (existsSync(errorsFile)) {
            const errorsData = JSON.parse(readFileSync(errorsFile, 'utf8'));
            
            let response = '🔍 **Compilation Status:**\n\n';
            
            if (errorsData.errors && errorsData.errors.length > 0) {
              response += '❌ **Errors:**\n';
              errorsData.errors.forEach((error: any, i: number) => {
                response += `${i+1}. Line ${error.line}: ${error.message}\n`;
                if (error.suggestion) {
                  response += `   💡 Suggestion: ${error.suggestion}\n`;
                }
              });
              response += '\n';
            }
            
            if (errorsData.warnings && errorsData.warnings.length > 0) {
              response += '⚠️ **Warnings:**\n';
              errorsData.warnings.forEach((warning: any, i: number) => {
                response += `${i+1}. Line ${warning.line}: ${warning.message}\n`;
              });
              response += '\n';
            }
            
            if ((!errorsData.errors || errorsData.errors.length === 0) && 
                (!errorsData.warnings || errorsData.warnings.length === 0)) {
              response += '✅ **No compilation errors or warnings!**\n\n';
              response += 'Shader compiled successfully and is ready to render.';
            }
            
            return {
              content: [{
                type: 'text',
                text: response
              }]
            };
          } else {
            return {
              content: [{
                type: 'text',
                text: '📝 No compilation status available. Make sure ShaderPlayground app is running and has compiled a shader.'
              }]
            };
          }
        } catch (error) {
          return {
            content: [{
              type: 'text',
              text: `❌ Failed to get compilation errors: ${error}`
            }],
            isError: true
          };
        }
      }
      
      case 'set_uniforms': {
        if (!args) {
          return { content: [{ type: 'text', text: 'Missing arguments for set_uniforms' }], isError: true };
        }
        
        const uniforms = args.uniforms as Record<string, number | number[]>;
        
        // Write uniforms to communication file for ShaderPlayground to pick up
        const uniformsFile = 'Resources/communication/uniforms.json';
        try {
          execSync('mkdir -p Resources/communication');
          writeFileSync(uniformsFile, JSON.stringify({ uniforms, timestamp: Date.now() }, null, 2));
          
          let response = '✅ **Uniforms Updated:**\n\n';
          for (const [name, value] of Object.entries(uniforms)) {
            if (Array.isArray(value)) {
              response += `🔢 ${name}: [${value.join(', ')}]\n`;
            } else {
              response += `🔢 ${name}: ${value}\n`;
            }
          }
          
          return {
            content: [{
              type: 'text',
              text: response
            }]
          };
        } catch (error) {
          return {
            content: [{
              type: 'text',
              text: `❌ Failed to set uniforms: ${error}`
            }],
            isError: true
          };
        }
      }
      
      case 'list_uniforms': {
        try {
          const uniformsFile = 'Resources/communication/uniforms.json';
          if (existsSync(uniformsFile)) {
            const uniformsData = JSON.parse(readFileSync(uniformsFile, 'utf8'));
            
            let response = '📊 **Current Uniforms:**\n\n';
            if (uniformsData.uniforms && Object.keys(uniformsData.uniforms).length > 0) {
              for (const [name, value] of Object.entries(uniformsData.uniforms)) {
                if (Array.isArray(value)) {
                  response += `🔢 ${name}: [${(value as number[]).join(', ')}]\n`;
                } else {
                  response += `🔢 ${name}: ${value}\n`;
                }
              }
            } else {
              response += '📝 No uniforms currently set.';
            }
            
            return {
              content: [{
                type: 'text',
                text: response
              }]
            };
          } else {
            return {
              content: [{
                type: 'text',
                text: '📝 No uniforms file found. No uniforms have been set yet.'
              }]
            };
          }
        } catch (error) {
          return {
            content: [{
              type: 'text',
              text: `❌ Failed to list uniforms: ${error}`
            }],
            isError: true
          };
        }
      }
      
      case 'get_example_shader': {
        if (!args) {
            return { text: [{ text: 'Missing arguments for list_example_shaders' }] };
        }
        
        const type = args.type as string;
        
        const examples = {
          basic: `#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader(float4 position [[position]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]]) {
    float2 uv = position.xy / resolution;
    
    // Simple animated gradient
    float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    
    return float4(color, 1.0);
}`,
          
          plasma: `#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader(float4 position [[position]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]]) {
    float2 uv = position.xy / resolution;
    uv = uv * 2.0 - 1.0;
    
    float v = 0.0;
    v += sin((uv.x + time));
    v += sin((uv.y + time) / 2.0);
    v += sin((uv.x + uv.y + time) / 2.0);
    
    float cx = uv.x + 0.5 * sin(time / 5.0);
    float cy = uv.y + 0.5 * cos(time / 3.0);
    v += sin(sqrt(100.0 * (cx * cx + cy * cy) + 1.0) + time);
    
    v = v / 2.0;
    
    float3 col = float3(1, sin(3.14159 * v), cos(3.14159 * v));
    
    return float4(col, 1.0);
}`,

          gradient: `#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader(float4 position [[position]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]]) {
    float2 uv = position.xy / resolution;
    
    float3 col = mix(float3(1.0, 0.5, 0.5), float3(0.5, 0.5, 1.0), uv.y);
    col = mix(col, float3(1.0, 1.0, 0.5), sin(time) * 0.5 + 0.5);
    
    return float4(col, 1.0);
}`,

          noise: `#include <metal_stdlib>
using namespace metal;

float random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898,78.233))) * 43758.5453123);
}

fragment float4 fragmentShader(float4 position [[position]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]]) {
    float2 uv = position.xy / resolution;
    
    float noise = random(uv + time);
    float3 col = float3(noise);
    
    return float4(col, 1.0);
}`,

          spiral: `#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader(float4 position [[position]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]]) {
    float2 uv = position.xy / resolution;
    uv = uv * 2.0 - 1.0;
    
    float angle = atan2(uv.y, uv.x);
    float radius = length(uv);
    
    float spiral = sin(radius * 10.0 - angle * 3.0 + time * 2.0);
    float3 col = float3(spiral * 0.5 + 0.5);
    col *= smoothstep(0.8, 0.0, radius);
    
    return float4(col, 1.0);
}`,

          ripples: `#include <metal_stdlib>
using namespace metal;

fragment float4 fragmentShader(float4 position [[position]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]]) {
    float2 uv = position.xy / resolution;
    uv = uv * 2.0 - 1.0;
    
    float dist = length(uv);
    float ripple = sin(dist * 20.0 - time * 8.0) * exp(-dist * 3.0);
    
    float3 col = float3(0.5 + ripple * 0.5);
    col *= smoothstep(1.0, 0.0, dist);
    
    return float4(col, 1.0);
}`
        };
        
        const shaderCode = examples[type as keyof typeof examples];
        if (!shaderCode) {
          throw new Error(`Unknown shader type: ${type}`);
        }
        
        return {
          content: [
            {
              type: 'text',
              text: `Here's a ${type} shader example:\n\n\`\`\`metal\n${shaderCode}\n\`\`\`\n\nTo see this shader in action:\n1. Copy this code\n2. Paste it into the ShaderPlayground app\n3. Use the take_screenshot tool to capture the result`,
            },
          ],
        };
      }

      // ---- Stub handlers for newly-added tools ----
      case 'run_frame':
      case 'set_time':
      case 'play':
      case 'pause':
      case 'set_playback_speed':
      case 'set_resolution':
      case 'set_aspect':
      case 'set_device_profile':
      case 'set_seed':
      case 'randomize_seed':
      case 'set_mouse':
      case 'simulate_touch_path': {
        return {
          content: [{
            type: 'text',
            text: `🧪 Tool '${name}' acknowledged (schema ready). Implementation pending.`
          }]
        };
      }

      case 'save_snapshot': {
        // Bridge to app via command file
        try {
          const description = (args && (args as any).description) || 'snapshot';
          const fs = await import('fs');
          await fs.promises.mkdir('Resources/communication', { recursive: true });
          await fs.promises.writeFile('Resources/communication/commands.json', JSON.stringify({ action: 'save_snapshot', description, timestamp: Date.now() }, null, 2));
          return { content: [{ type: 'text', text: '🖼️ Snapshot requested. App will capture code+image+meta.' }] };
        } catch (e: any) {
          return { content: [{ type: 'text', text: `❌ Failed to request snapshot: ${e.message}` }], isError: true };
        }
      }

      // Session & snapshots
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Shader Playground MCP server running on stdio');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
