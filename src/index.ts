#!/usr/bin/env node

/**
 * Metal Shader MCP Server
 * Live Metal shader development with real-time preview and hot reload
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import { compileShader, validateShader } from './compiler.js';
import { PreviewEngine } from './preview.js';
import { HotReloadManager } from './hotReload.js';
import { PerformanceProfiler } from './profiler.js';
import { ShaderParameters } from './parameters.js';

class MetalShaderMCPServer {
  private server: Server;
  private preview: PreviewEngine;
  private hotReload: HotReloadManager;
  private profiler: PerformanceProfiler;
  private parameters: ShaderParameters;

  constructor() {
    this.server = new Server(
      {
        name: 'metal-shader-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.preview = new PreviewEngine();
    this.hotReload = new HotReloadManager();
    this.profiler = new PerformanceProfiler();
    this.parameters = new ShaderParameters();

    this.setupHandlers();
  }

  private setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: this.getTools(),
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      switch (name) {
        case 'compile_shader':
          return await this.handleCompileShader(args);
        
        case 'preview_shader':
          return await this.handlePreviewShader(args);
        
        case 'update_uniforms':
          return await this.handleUpdateUniforms(args);
        
        case 'profile_performance':
          return await this.handleProfilePerformance(args);
        
        case 'hot_reload':
          return await this.handleHotReload(args);
        
        case 'validate_shader':
          return await this.handleValidateShader(args);

        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    });
  }

  private getTools(): Tool[] {
    return [
      {
        name: 'compile_shader',
        description: 'Compile Metal shader code and return compilation results',
        inputSchema: {
          type: 'object',
          properties: {
            code: { type: 'string', description: 'Metal shader source code' },
            target: { 
              type: 'string', 
              enum: ['air', 'metallib', 'spirv'],
              description: 'Compilation target format' 
            },
            optimize: { type: 'boolean', description: 'Enable optimizations' },
          },
          required: ['code'],
        },
      },
      {
        name: 'preview_shader',
        description: 'Generate a preview image using the compiled shader',
        inputSchema: {
          type: 'object',
          properties: {
            shaderPath: { type: 'string', description: 'Path to compiled shader' },
            width: { type: 'number', description: 'Preview width in pixels' },
            height: { type: 'number', description: 'Preview height in pixels' },
            time: { type: 'number', description: 'Animation time (0-1)' },
            touchPoint: {
              type: 'object',
              properties: {
                x: { type: 'number' },
                y: { type: 'number' },
              },
            },
          },
          required: ['shaderPath'],
        },
      },
      {
        name: 'update_uniforms',
        description: 'Update shader uniform parameters',
        inputSchema: {
          type: 'object',
          properties: {
            uniforms: {
              type: 'object',
              description: 'Key-value pairs of uniform names and values',
            },
          },
          required: ['uniforms'],
        },
      },
      {
        name: 'profile_performance',
        description: 'Profile shader performance metrics',
        inputSchema: {
          type: 'object',
          properties: {
            shaderPath: { type: 'string', description: 'Path to compiled shader' },
            iterations: { type: 'number', description: 'Number of test iterations' },
            resolution: {
              type: 'object',
              properties: {
                width: { type: 'number' },
                height: { type: 'number' },
              },
            },
          },
          required: ['shaderPath'],
        },
      },
      {
        name: 'hot_reload',
        description: 'Enable hot reload for a shader file',
        inputSchema: {
          type: 'object',
          properties: {
            filePath: { type: 'string', description: 'Path to .metal file to watch' },
            enable: { type: 'boolean', description: 'Enable or disable hot reload' },
          },
          required: ['filePath', 'enable'],
        },
      },
      {
        name: 'validate_shader',
        description: 'Validate shader syntax and semantics',
        inputSchema: {
          type: 'object',
          properties: {
            code: { type: 'string', description: 'Metal shader source code' },
          },
          required: ['code'],
        },
      },
    ];
  }

  private async handleCompileShader(args: any) {
    const { code, target = 'air', optimize = false } = args;
    
    try {
      const result = await compileShader(code, { target, optimize });
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: result.success,
              outputPath: result.outputPath,
              errors: result.errors,
              warnings: result.warnings,
              compileTime: result.compileTime,
            }, null, 2),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Compilation failed: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }

  private async handlePreviewShader(args: any) {
    const { shaderPath, width = 512, height = 512, time = 0, touchPoint } = args;
    
    try {
      const imageData = await this.preview.renderFrame({
        shaderPath,
        width,
        height,
        uniforms: {
          time,
          touchPoint: touchPoint || { x: 0.5, y: 0.5 },
          resolution: { x: width, y: height },
        },
      });
      
      return {
        content: [
          {
            type: 'image',
            data: imageData.toString('base64'),
            mimeType: 'image/png',
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Preview failed: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }

  private async handleUpdateUniforms(args: any) {
    const { uniforms } = args;
    
    this.parameters.updateUniforms(uniforms);
    
    return {
      content: [
        {
          type: 'text',
          text: `Updated ${Object.keys(uniforms).length} uniforms`,
        },
      ],
    };
  }

  private async handleProfilePerformance(args: any) {
    const { shaderPath, iterations = 100, resolution = { width: 512, height: 512 } } = args;
    
    try {
      const metrics = await this.profiler.profileShader({
        shaderPath,
        iterations,
        resolution,
      });
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              averageFrameTime: `${metrics.averageFrameTime.toFixed(2)}ms`,
              fps: metrics.fps.toFixed(1),
              gpuTime: `${metrics.gpuTime.toFixed(2)}ms`,
              cpuTime: `${metrics.cpuTime.toFixed(2)}ms`,
              memoryUsage: `${(metrics.memoryUsage / 1024 / 1024).toFixed(1)}MB`,
              powerUsage: metrics.powerUsage,
            }, null, 2),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Profiling failed: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }

  private async handleHotReload(args: any) {
    const { filePath, enable } = args;
    
    if (enable) {
      await this.hotReload.watch(filePath, async (path) => {
        // Notify about file change
        this.server.notification({
          method: 'shader/changed',
          params: { path },
        });
      });
      
      return {
        content: [
          {
            type: 'text',
            text: `Hot reload enabled for ${filePath}`,
          },
        ],
      };
    } else {
      this.hotReload.unwatch(filePath);
      
      return {
        content: [
          {
            type: 'text',
            text: `Hot reload disabled for ${filePath}`,
          },
        ],
      };
    }
  }

  private async handleValidateShader(args: any) {
    const { code } = args;
    
    try {
      const validation = await validateShader(code);
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              valid: validation.valid,
              errors: validation.errors,
              warnings: validation.warnings,
              suggestions: validation.suggestions,
            }, null, 2),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Validation failed: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Metal Shader MCP Server running on stdio');
  }
}

// Start the server
const server = new MetalShaderMCPServer();
server.run().catch(console.error);