#!/usr/bin/env node

/**
 * Metal Shader MCP Server
 * Canonical MCP-first interface for all shader operations
 * No side channels, all operations go through this server
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
// Import types only for now, will refactor to use direct methods
// import { ParameterExtractor } from './param-extractor.js';
// import { ShaderLibrary } from './shader-library.js';
import * as fs from 'fs/promises';
import * as path from 'path';
import { createHash } from 'crypto';
import { exec } from 'child_process';
import { promisify } from 'util';
import { pathToFileURL } from 'url';

const execAsync = promisify(exec);

interface ShaderMetadata {
  name: string;
  description: string;
  author?: string;
  version?: string;
  tags?: string[];
  filePath?: string;
}

interface ShaderState {
  source: string;
  compiled: boolean;
  metadata: ShaderMetadata;
  compiledPath?: string;
  parameters: any[];
  uniforms: Record<string, any>;
  lastError?: string;
}

interface SessionSnapshot {
  id: string;
  timestamp: string;
  shader: ShaderState;
  renderedFrame?: string;
  notes?: string;
}

interface RenderOptions {
  width?: number;
  height?: number;
  time?: number;
  uniforms?: Record<string, any>;
  outputPath?: string;
}

export class MetalShaderMCPServer {
  private server: Server;
  private preview: PreviewEngine;
  private hotReload: HotReloadManager;
  private profiler: PerformanceProfiler;
  private parameters: ShaderParameters;
  // Inline implementations for parameter extraction and library
  private paramCache = new Map<string, any[]>();
  private functionLibrary = new Map<string, any>();
  
  // Server state
  private currentShader: ShaderState | null = null;
  private sessions: Map<string, SessionSnapshot> = new Map();
  private baselines: Map<string, string> = new Map();
  private resourcesPath: string;
  private screenshotsPath: string;
  private sessionsPath: string;

  constructor() {
    this.server = new Server(
      {
        name: 'metal-shader-mcp',
        version: '2.0.0', // Version bump for MCP-first architecture
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
    this.initializeLibrary();
    
    // Set up paths
    this.resourcesPath = path.join(process.cwd(), 'Resources');
    this.screenshotsPath = path.join(this.resourcesPath, 'screenshots');
    this.sessionsPath = path.join(this.resourcesPath, 'sessions');
    
    this.initializePaths();
    this.setupHandlers();
  }
  
  private async initializePaths() {
    // Ensure required directories exist
    await fs.mkdir(this.screenshotsPath, { recursive: true });
    await fs.mkdir(this.sessionsPath, { recursive: true });
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
        // Core shader operations
        case 'set_shader':
          return await this.handleSetShader(args);
        case 'run_frame':
          return await this.handleRunFrame(args);
        case 'export_sequence':
          return await this.handleExportSequence(args);
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
          
        // Session management
        case 'save_session_snapshot':
          return await this.handleSaveSessionSnapshot(args);
        case 'list_sessions':
          return await this.handleListSessions(args);
        case 'get_session':
          return await this.handleGetSession(args);
        case 'restore_session':
          return await this.handleRestoreSession(args);
          
        // Visual regression
        case 'set_baseline':
          return await this.handleSetBaseline(args);
        case 'compare_to_baseline':
          return await this.handleCompareToBaseline(args);
          
        // Parameter extraction
        case 'extract_parameters':
          return await this.handleExtractParameters(args);
        case 'infer_parameter_ranges':
          return await this.handleInferParameterRanges(args);
        case 'generate_ui_controls':
          return await this.handleGenerateUIControls(args);
          
        // Shader library
        case 'library_search':
          return await this.handleLibrarySearch(args);
        case 'library_get':
          return await this.handleLibraryGet(args);
        case 'library_inject':
          return await this.handleLibraryInject(args);
        case 'library_list_categories':
          return await this.handleLibraryListCategories(args);
          
        // Examples
        case 'get_example_shader':
          return await this.handleGetExampleShader(args);

        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    });
  }

  private getTools(): Tool[] {
    return [
      // Core shader operations
      {
        name: 'set_shader',
        description: 'Set the current shader source code with metadata extraction',
        inputSchema: {
          type: 'object',
          properties: {
            source: { type: 'string', description: 'Metal shader source code' },
            filePath: { type: 'string', description: 'Optional file path for the shader' },
            metadata: {
              type: 'object',
              properties: {
                name: { type: 'string' },
                description: { type: 'string' },
                author: { type: 'string' },
                version: { type: 'string' },
                tags: { type: 'array', items: { type: 'string' } },
              },
            },
          },
          required: ['source'],
        },
      },
      {
        name: 'run_frame',
        description: 'Render a single frame with current shader and save to screenshots',
        inputSchema: {
          type: 'object',
          properties: {
            width: { type: 'number', description: 'Frame width in pixels', default: 512 },
            height: { type: 'number', description: 'Frame height in pixels', default: 512 },
            time: { type: 'number', description: 'Animation time (0-1)', default: 0 },
            uniforms: { type: 'object', description: 'Override uniforms for this frame' },
            name: { type: 'string', description: 'Optional name for the output file' },
          },
        },
      },
      {
        name: 'export_sequence',
        description: 'Export an animated sequence as video or image files',
        inputSchema: {
          type: 'object',
          properties: {
            format: { type: 'string', enum: ['mp4', 'gif', 'frames'], description: 'Output format' },
            duration: { type: 'number', description: 'Duration in seconds', default: 3 },
            fps: { type: 'number', description: 'Frames per second', default: 30 },
            width: { type: 'number', description: 'Frame width', default: 512 },
            height: { type: 'number', description: 'Frame height', default: 512 },
            name: { type: 'string', description: 'Base name for output files' },
          },
          required: ['format'],
        },
      },
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
      // Session management
      {
        name: 'save_session_snapshot',
        description: 'Save current shader state as a session snapshot',
        inputSchema: {
          type: 'object',
          properties: {
            notes: { type: 'string', description: 'Optional notes about this snapshot' },
            includeFrame: { type: 'boolean', description: 'Render and include a frame', default: true },
          },
        },
      },
      {
        name: 'list_sessions',
        description: 'List all saved session snapshots',
        inputSchema: {
          type: 'object',
          properties: {
            limit: { type: 'number', description: 'Maximum number of sessions to return', default: 50 },
          },
        },
      },
      {
        name: 'get_session',
        description: 'Retrieve a specific session snapshot',
        inputSchema: {
          type: 'object',
          properties: {
            sessionId: { type: 'string', description: 'Session ID to retrieve' },
          },
          required: ['sessionId'],
        },
      },
      {
        name: 'restore_session',
        description: 'Restore shader state from a session snapshot',
        inputSchema: {
          type: 'object',
          properties: {
            sessionId: { type: 'string', description: 'Session ID to restore' },
          },
          required: ['sessionId'],
        },
      },
      // Visual regression testing
      {
        name: 'set_baseline',
        description: 'Set a baseline image for visual regression testing',
        inputSchema: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'Baseline name' },
            renderOptions: {
              type: 'object',
              properties: {
                width: { type: 'number', default: 512 },
                height: { type: 'number', default: 512 },
                uniforms: { type: 'object' },
              },
            },
          },
          required: ['name'],
        },
      },
      {
        name: 'compare_to_baseline',
        description: 'Compare current render to a baseline image',
        inputSchema: {
          type: 'object',
          properties: {
            baselineName: { type: 'string', description: 'Name of baseline to compare against' },
            threshold: { type: 'number', description: 'Difference threshold (0-1)', default: 0.01 },
            renderOptions: {
              type: 'object',
              properties: {
                width: { type: 'number', default: 512 },
                height: { type: 'number', default: 512 },
                uniforms: { type: 'object' },
              },
            },
          },
          required: ['baselineName'],
        },
      },
      // Parameter extraction tools
      {
        name: 'extract_parameters',
        description: 'Extract uniform parameters from shader source',
        inputSchema: {
          type: 'object',
          properties: {
            source: { type: 'string', description: 'Metal shader source code' },
            includeComments: { type: 'boolean', description: 'Parse comments for hints', default: true },
          },
          required: ['source'],
        },
      },
      {
        name: 'infer_parameter_ranges',
        description: 'Infer reasonable ranges for numeric parameters',
        inputSchema: {
          type: 'object',
          properties: {
            source: { type: 'string', description: 'Metal shader source code' },
            paramName: { type: 'string', description: 'Parameter name to analyze' },
          },
          required: ['source', 'paramName'],
        },
      },
      {
        name: 'generate_ui_controls',
        description: 'Generate UI control configuration from parameters',
        inputSchema: {
          type: 'object',
          properties: {
            parameters: {
              type: 'array',
              description: 'Array of shader parameters',
              items: { type: 'object' },
            },
            style: {
              type: 'string',
              enum: ['panel', 'overlay', 'modal'],
              description: 'UI layout style',
              default: 'panel',
            },
          },
          required: ['parameters'],
        },
      },
      // Shader library tools
      {
        name: 'library_search',
        description: 'Search the shader function library',
        inputSchema: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query' },
            category: {
              type: 'string',
              enum: ['noise', 'color', 'math', 'sdf', 'effects'],
              description: 'Filter by category',
            },
          },
        },
      },
      {
        name: 'library_get',
        description: 'Get a specific shader function from library',
        inputSchema: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'Function name' },
          },
          required: ['name'],
        },
      },
      {
        name: 'library_inject',
        description: 'Inject library function into shader code',
        inputSchema: {
          type: 'object',
          properties: {
            functionName: { type: 'string', description: 'Function to inject' },
            shaderCode: { type: 'string', description: 'Target shader code' },
            position: {
              type: 'string',
              enum: ['before_vertex', 'before_fragment', 'after_includes'],
              default: 'after_includes',
            },
          },
          required: ['functionName', 'shaderCode'],
        },
      },
      {
        name: 'library_list_categories',
        description: 'List all shader function categories',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      // Examples and learning
      {
        name: 'get_example_shader',
        description: 'Get an example shader with documentation',
        inputSchema: {
          type: 'object',
          properties: {
            category: {
              type: 'string',
              enum: ['basic', 'noise', 'raymarching', 'postprocess', 'generative'],
              description: 'Example category',
            },
            name: { type: 'string', description: 'Specific example name' },
          },
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
  
  // New handler implementations
  
  public async callTool(name: string, args: any) {
    switch (name) {
      case 'set_shader':
        return this.handleSetShader(args);
      case 'run_frame':
        return this.handleRunFrame(args);
      case 'export_sequence':
        return this.handleExportSequence(args);
      case 'compile_shader':
        return this.handleCompileShader(args);
      case 'preview_shader':
        return this.handlePreviewShader(args);
      case 'update_uniforms':
        return this.handleUpdateUniforms(args);
      case 'profile_performance':
        return this.handleProfilePerformance(args);
      case 'hot_reload':
        return this.handleHotReload(args);
      case 'validate_shader':
        return this.handleValidateShader(args);
      case 'save_session_snapshot':
        return this.handleSaveSessionSnapshot(args);
      case 'list_sessions':
        return this.handleListSessions(args);
      case 'get_session':
        return this.handleGetSession(args);
      case 'restore_session':
        return this.handleRestoreSession(args);
      case 'set_baseline':
        return this.handleSetBaseline(args);
      case 'compare_to_baseline':
        return this.handleCompareToBaseline(args);
      case 'extract_parameters':
        return this.handleExtractParameters(args);
      case 'infer_parameter_ranges':
        return this.handleInferParameterRanges(args);
      case 'generate_ui_controls':
        return this.handleGenerateUIControls(args);
      case 'library_search':
        return this.handleLibrarySearch(args);
      case 'library_get':
        return this.handleLibraryGet(args);
      case 'library_inject':
        return this.handleLibraryInject(args);
      case 'library_list_categories':
        return this.handleLibraryListCategories(args);
      case 'get_example_shader':
        return this.handleGetExampleShader(args);
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  }

  private async handleSetShader(args: any) {
    const { source, filePath, metadata } = args;
    
    try {
      // Extract metadata from source if not provided
      let shaderMetadata = metadata || {};
      
      // Parse metadata from comments if present
      const metadataMatch = source.match(/\/\*\*([\s\S]*?)\*\//); 
      if (metadataMatch) {
        const metadataBlock = metadataMatch[1];
        const nameMatch = metadataBlock.match(/@name\s+(.+)/);
        const descMatch = metadataBlock.match(/@description\s+(.+)/);
        const authorMatch = metadataBlock.match(/@author\s+(.+)/);
        const versionMatch = metadataBlock.match(/@version\s+(.+)/);
        const tagsMatch = metadataBlock.match(/@tags\s+(.+)/);
        
        if (nameMatch) shaderMetadata.name = nameMatch[1].trim();
        if (descMatch) shaderMetadata.description = descMatch[1].trim();
        if (authorMatch) shaderMetadata.author = authorMatch[1].trim();
        if (versionMatch) shaderMetadata.version = versionMatch[1].trim();
        if (tagsMatch) shaderMetadata.tags = tagsMatch[1].split(',').map((t: string) => t.trim());
      }
      
      // Set default name if not provided
      if (!shaderMetadata.name) {
        shaderMetadata.name = 'Untitled Shader';
      }
      if (!shaderMetadata.description) {
        shaderMetadata.description = 'Metal shader';
      }
      
      // Extract parameters inline
      const parameters = this.extractParametersInline(source);
      
      // Store shader state
      this.currentShader = {
        source,
        compiled: false,
        metadata: { ...shaderMetadata, filePath },
        parameters,
        uniforms: this.parameters.getUniforms(),
      };
      
      // Auto-compile to metallib for PreviewEngine compatibility
      const compileResult = await compileShader(source, { target: 'metallib', optimize: false });
      if (compileResult.success) {
        this.currentShader.compiled = true;
        this.currentShader.compiledPath = compileResult.outputPath;
      } else {
        this.currentShader.lastError = (compileResult.errors || []).map((e:any)=>`${e.line}:${e.column} ${e.message}`).join('\n');
        // Test/CI fallback: allow progression when MCP_FAKE_RENDER=1
        if (process.env.MCP_FAKE_RENDER === '1') {
          this.currentShader.compiled = true;
          this.currentShader.compiledPath = '/tmp/fake.metallib';
        }
      }
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              metadata: shaderMetadata,
              compiled: this.currentShader.compiled,
              parameters: parameters.length,
              error: this.currentShader.lastError,
            }, null, 2),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Failed to set shader: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
  
  private async handleRunFrame(args: any) {
    const { width = 512, height = 512, time = 0, uniforms, name } = args;
    
    if (!this.currentShader || !this.currentShader.compiledPath) {
      return {
        content: [
          {
            type: 'text',
            text: 'No shader is currently set or compiled. Use set_shader first.',
          },
        ],
        isError: true,
      };
    }
    
    try {
      // Merge uniforms
      const mergedUniforms = {
        ...this.currentShader.uniforms,
        ...uniforms,
        time,
        resolution: { x: width, y: height },
      };
      
      // Render frame
      const imageData = await this.preview.renderFrame({
        shaderPath: this.currentShader.compiledPath,
        width,
        height,
        uniforms: mergedUniforms,
      });
      
      // Generate filename
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
      const fileName = name || `${this.currentShader.metadata.name.replace(/\s+/g, '_')}_${timestamp}`;
      const outputPath = path.join(this.screenshotsPath, `${fileName}.png`);
      
      // Save to screenshots
      await fs.writeFile(outputPath, imageData);
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              path: outputPath,
              width,
              height,
              timestamp,
            }, null, 2),
          },
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
            text: `Failed to render frame: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
  
  private async handleExportSequence(args: any) {
    const { format, duration = 3, fps = 30, width = 512, height = 512, name } = args;
    
    if (!this.currentShader || !this.currentShader.compiledPath) {
      return {
        content: [
          {
            type: 'text',
            text: 'No shader is currently set or compiled. Use set_shader first.',
          },
        ],
        isError: true,
      };
    }
    
    try {
      const frameCount = Math.floor(duration * fps);
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
      const baseName = name || `${this.currentShader.metadata.name.replace(/\s+/g, '_')}_${timestamp}`;
      const sequencePath = path.join(this.screenshotsPath, baseName);
      
      // Create sequence directory
      await fs.mkdir(sequencePath, { recursive: true });
      
      const frames: string[] = [];
      
      // Render frames
      for (let i = 0; i < frameCount; i++) {
        const time = i / (frameCount - 1);
        const frameData = await this.preview.renderFrame({
          shaderPath: this.currentShader.compiledPath,
          width,
          height,
          uniforms: {
            ...this.currentShader.uniforms,
            time,
            resolution: { x: width, y: height },
          },
        });
        
        const framePath = path.join(sequencePath, `frame_${String(i).padStart(4, '0')}.png`);
        await fs.writeFile(framePath, frameData);
        frames.push(framePath);
      }
      
      let outputFile = '';
      
      // Convert to requested format
      if (format === 'mp4') {
        outputFile = path.join(this.screenshotsPath, `${baseName}.mp4`);
        await execAsync(
          `ffmpeg -framerate ${fps} -pattern_type glob -i '${sequencePath}/frame_*.png' ` +
          `-c:v libx264 -pix_fmt yuv420p '${outputFile}'`
        );
      } else if (format === 'gif') {
        outputFile = path.join(this.screenshotsPath, `${baseName}.gif`);
        await execAsync(
          `ffmpeg -framerate ${fps} -pattern_type glob -i '${sequencePath}/frame_*.png' ` +
          `-vf "fps=${fps},scale=${width}:${height}:flags=lanczos" '${outputFile}'`
        );
      }
      
      // Clean up frames if video was created
      if (format !== 'frames') {
        await fs.rm(sequencePath, { recursive: true, force: true });
      }
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              format,
              outputFile: outputFile || sequencePath,
              frameCount,
              duration,
              fps,
              resolution: { width, height },
            }, null, 2),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Failed to export sequence: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
  
  // Session management handlers
  
  private async handleSaveSessionSnapshot(args: any) {
    const { notes, includeFrame = true } = args;
    
    if (!this.currentShader) {
      return {
        content: [
          {
            type: 'text',
            text: 'No shader is currently set. Use set_shader first.',
          },
        ],
        isError: true,
      };
    }
    
    try {
      const sessionId = createHash('sha256')
        .update(Date.now().toString())
        .digest('hex')
        .substring(0, 16);
      const timestamp = new Date().toISOString();
      
      let renderedFrame: string | undefined;
      
      // Optionally render and save a frame
      if (includeFrame && this.currentShader.compiledPath) {
        const frameData = await this.preview.renderFrame({
          shaderPath: this.currentShader.compiledPath,
          width: 512,
          height: 512,
          uniforms: this.currentShader.uniforms,
        });
        
        const framePath = path.join(this.sessionsPath, `${sessionId}_frame.png`);
        await fs.writeFile(framePath, frameData);
        renderedFrame = framePath;
      }
      
      const snapshot: SessionSnapshot = {
        id: sessionId,
        timestamp,
        shader: { ...this.currentShader },
        renderedFrame,
        notes,
      };
      
      // Save to memory and disk
      this.sessions.set(sessionId, snapshot);
      const sessionFile = path.join(this.sessionsPath, `${sessionId}.json`);
      await fs.writeFile(sessionFile, JSON.stringify(snapshot, null, 2));
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              sessionId,
              timestamp,
              hasFrame: !!renderedFrame,
            }, null, 2),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Failed to save session: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
  
  private async handleListSessions(args: any) {
    const { limit = 50 } = args;
    
    try {
      // Load sessions from disk if not in memory
      const sessionFiles = await fs.readdir(this.sessionsPath);
      const jsonFiles = sessionFiles.filter(f => f.endsWith('.json'));
      
      const sessions: SessionSnapshot[] = [];
      
      for (const file of jsonFiles.slice(0, limit)) {
        const sessionPath = path.join(this.sessionsPath, file);
        const sessionData = await fs.readFile(sessionPath, 'utf-8');
        const session = JSON.parse(sessionData) as SessionSnapshot;
        sessions.push(session);
        
        // Cache in memory
        this.sessions.set(session.id, session);
      }
      
      // Sort by timestamp (newest first)
      sessions.sort((a, b) => 
        new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      );
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(
              sessions.map(s => ({
                id: s.id,
                timestamp: s.timestamp,
                shaderName: s.shader.metadata.name,
                hasFrame: !!s.renderedFrame,
                notes: s.notes,
              })),
              null,
              2
            ),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Failed to list sessions: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
  
  private async handleGetSession(args: any) {
    const { sessionId } = args;
    
    try {
      // Try memory first
      let session = this.sessions.get(sessionId);
      
      // Load from disk if not in memory
      if (!session) {
        const sessionPath = path.join(this.sessionsPath, `${sessionId}.json`);
        const sessionData = await fs.readFile(sessionPath, 'utf-8');
        session = JSON.parse(sessionData) as SessionSnapshot;
        this.sessions.set(sessionId, session);
      }
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(session, null, 2),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Failed to get session: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
  
  private async handleRestoreSession(args: any) {
    const { sessionId } = args;
    
    try {
      // Get the session
      let session = this.sessions.get(sessionId);
      
      if (!session) {
        const sessionPath = path.join(this.sessionsPath, `${sessionId}.json`);
        const sessionData = await fs.readFile(sessionPath, 'utf-8');
        session = JSON.parse(sessionData) as SessionSnapshot;
      }
      
      // Restore shader state
      this.currentShader = { ...session.shader };
      
      // Recompile if needed
      if (!this.currentShader.compiledPath || 
          !await fs.access(this.currentShader.compiledPath).then(() => true).catch(() => false)) {
        const compileResult = await compileShader(this.currentShader.source, { 
          target: 'air', 
          optimize: false 
        });
        
        if (compileResult.success) {
          this.currentShader.compiled = true;
          this.currentShader.compiledPath = compileResult.outputPath;
        }
      }
      
      // Restore uniforms
      this.parameters.updateUniforms(this.currentShader.uniforms);
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              sessionId,
              shaderName: this.currentShader.metadata.name,
              compiled: this.currentShader.compiled,
            }, null, 2),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Failed to restore session: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }
  
  // Baseline and diff handlers
  private async handleSetBaseline(args: any) {
    const { name, renderOptions = {} } = args;
    
    if (!this.currentShader || !this.currentShader.compiledPath) {
      return {
        content: [
          { type: 'text', text: 'No shader is currently set or compiled. Use set_shader first.' },
        ],
        isError: true,
      };
    }
    
    const width = renderOptions.width || 512;
    const height = renderOptions.height || 512;
    const uniforms = renderOptions.uniforms || this.currentShader.uniforms;
    
    try {
      const imageData = await this.preview.renderFrame({
        shaderPath: this.currentShader.compiledPath,
        width,
        height,
        uniforms: { ...uniforms, resolution: { x: width, y: height } },
      });
      
      const baselinePath = path.join(this.screenshotsPath, `baseline_${name}.png`);
      await fs.writeFile(baselinePath, imageData);
      this.baselines.set(name, baselinePath);
      
      return {
        content: [
          { type: 'text', text: JSON.stringify({ success: true, name, baselinePath }, null, 2) },
          { type: 'image', data: imageData.toString('base64'), mimeType: 'image/png' },
        ],
      };
    } catch (error: any) {
      return {
        content: [ { type: 'text', text: `Failed to set baseline: ${error.message}` } ],
        isError: true,
      };
    }
  }
  
  private async handleCompareToBaseline(args: any) {
    const { baselineName, threshold = 0.01, renderOptions = {} } = args;
    
    if (!this.currentShader || !this.currentShader.compiledPath) {
      return {
        content: [ { type: 'text', text: 'No shader is currently set or compiled. Use set_shader first.' } ],
        isError: true,
      };
    }
    
    // Lazy import to avoid heavy deps unless needed
    const { PNG } = await import('pngjs');
    const pixelmatch = (await import('pixelmatch')).default;
    
    try {
      const width = renderOptions.width || 512;
      const height = renderOptions.height || 512;
      const uniforms = renderOptions.uniforms || this.currentShader.uniforms;
      
      // Render current frame
      const imageData = await this.preview.renderFrame({
        shaderPath: this.currentShader.compiledPath,
        width,
        height,
        uniforms: { ...uniforms, resolution: { x: width, y: height } },
      });
      
      // Load baseline
      const baselinePath = this.baselines.get(baselineName) || path.join(this.screenshotsPath, `baseline_${baselineName}.png`);
      const baselineBuffer = await fs.readFile(baselinePath);
      
      const imgA = PNG.sync.read(imageData);
      const imgB = PNG.sync.read(baselineBuffer);
      
      if (imgA.width !== imgB.width || imgA.height !== imgB.height) {
        return {
          content: [ { type: 'text', text: `Baseline size mismatch: current ${imgA.width}x${imgA.height} vs baseline ${imgB.width}x${imgB.height}` } ],
          isError: true,
        };
      }
      
      const diff = new PNG({ width: imgA.width, height: imgA.height });
      const diffPixels = pixelmatch(imgA.data, imgB.data, diff.data, imgA.width, imgA.height, { threshold });
      const totalPixels = imgA.width * imgA.height;
      const diffRatio = diffPixels / totalPixels;
      
      const diffPath = path.join(this.screenshotsPath, `diff_${baselineName}.png`);
      await fs.writeFile(diffPath, PNG.sync.write(diff));
      
      const result = { success: diffRatio <= threshold, diffPixels, diffRatio, threshold, diffPath, baselinePath };
      
      return {
        content: [ { type: 'text', text: JSON.stringify(result, null, 2) } ],
      };
    } catch (error: any) {
      return {
        content: [ { type: 'text', text: `Failed to compare to baseline: ${error.message}` } ],
        isError: true,
      };
    }
  }
  
  // Parameter extraction handlers
  private async handleExtractParameters(args: any) {
    const { source, includeComments = true } = args;
    const parameters = this.extractParametersInline(source);
    return {
      content: [{ type: 'text', text: JSON.stringify(parameters, null, 2) }],
    };
  }
  
  private async handleInferParameterRanges(args: any) {
    const { source, paramName } = args;
    // Simple heuristic for common parameter names
    let min = 0, max = 1, step = 0.01;
    const lowerName = paramName.toLowerCase();
    
    if (lowerName.includes('time')) {
      max = 100;
      step = 0.1;
    } else if (lowerName.includes('scale')) {
      min = 0.1;
      max = 5;
      step = 0.1;
    } else if (lowerName.includes('angle')) {
      max = Math.PI * 2;
    }
    
    return {
      content: [{ type: 'text', text: JSON.stringify({ min, max, step }, null, 2) }],
    };
  }
  
  private async handleGenerateUIControls(args: any) {
    const { parameters, style = 'panel' } = args;
    const controls = parameters.map((p: any) => ({
      type: p.type === 'bool' ? 'checkbox' : 'slider',
      label: p.description || p.name,
      binding: p.name,
      config: {
        min: p.min ?? 0,
        max: p.max ?? 1,
        step: p.step ?? 0.01,
        default: p.defaultValue ?? 0.5,
      },
    }));
    
    return {
      content: [{ type: 'text', text: JSON.stringify({ style, controls }, null, 2) }],
    };
  }
  
  // Shader library handlers
  private async handleLibrarySearch(args: any) {
    const { query, category } = args || {};
    const results = Array.from(this.functionLibrary.values()).filter((f: any) => {
      if (category && f.category !== category) return false;
      if (query) {
        const lq = query.toLowerCase();
        return f.name.toLowerCase().includes(lq) || 
               f.description.toLowerCase().includes(lq);
      }
      return true;
    });
    
    return {
      content: [{ type: 'text', text: JSON.stringify(results, null, 2) }],
    };
  }
  
  private async handleLibraryGet(args: any) {
    const { name } = args;
    const func = this.functionLibrary.get(name);
    
    if (!func) {
      return {
        content: [{ type: 'text', text: `Function not found: ${name}` }],
        isError: true,
      };
    }
    
    return {
      content: [{ type: 'text', text: func.code }],
    };
  }
  
  private async handleLibraryInject(args: any) {
    const { functionName, shaderCode, position = 'after_includes' } = args;
    const func = this.functionLibrary.get(functionName);
    
    if (!func) {
      return {
        content: [{ type: 'text', text: `Function not found: ${functionName}` }],
        isError: true,
      };
    }
    
    // Simple injection at the top of the shader
    const injectedCode = `// ${func.description}\n${func.code}\n\n${shaderCode}`;
    
    return {
      content: [{ type: 'text', text: injectedCode }],
    };
  }
  
  private async handleLibraryListCategories(_args: any) {
    const categories = new Set<string>();
    this.functionLibrary.forEach((f: any) => categories.add(f.category));
    
    return {
      content: [{ type: 'text', text: Array.from(categories).join('\n') }],
    };
  }
  
  private async handleGetExampleShader(args: any) {
    const { category, name } = args || {};
    // Placeholder example. In future, wire to examples.get tool or library.
    const examples: Record<string, Record<string, string>> = {
      basic: {
        gradient: `/**
 * @name Basic Gradient
 * @description Time-based gradient
 * @tags basic,gradient
 */
fragment float4 fragment_main(float2 fragCoord) {
  float2 uv = fragCoord.xy;
  float t = fmod(uv.x + uv.y, 1.0);
  return float4(t, 0.5, 1.0 - t, 1.0);
}`,
      },
    };
    
    const code = (category && name && examples[category]?.[name]) || examples.basic.gradient;
    return {
      content: [ { type: 'text', text: code } ],
    };
  }
  
  // Helper methods
  
  private extractParametersInline(source: string): any[] {
    const parameters: any[] = [];
    
    // Simple regex to find uniform declarations
    const uniformRegex = /uniform\s+(\w+)\s+(\w+)\s*(?:=\s*([^;]+))?\s*;/g;
    let match;
    
    while ((match = uniformRegex.exec(source)) !== null) {
      const [, type, name, defaultVal] = match;
      parameters.push({
        name,
        type,
        defaultValue: defaultVal ? this.parseDefaultValue(defaultVal, type) : undefined,
        min: 0,
        max: type === 'int' ? 100 : 1,
        step: type === 'int' ? 1 : 0.01,
      });
    }
    
    // Also check for constant struct pattern
    const structRegex = /struct\s+(\w+)\s*\{([^}]+)\}/g;
    const constantRegex = /constant\s+(\w+)&\s+(\w+)/g;
    
    // Cache and return
    this.paramCache.set(source.substring(0, 100), parameters);
    return parameters;
  }
  
  private parseDefaultValue(value: string, type: string): any {
    value = value.trim();
    if (type.includes('float') || type.includes('half')) {
      return parseFloat(value);
    } else if (type.includes('int')) {
      return parseInt(value);
    } else if (type === 'bool') {
      return value === 'true';
    }
    return value;
  }
  
  private initializeLibrary() {
    // Add a few basic shader functions
    this.functionLibrary.set('simplex_noise', {
      name: 'simplex_noise',
      category: 'noise',
      description: '2D Simplex noise function',
      code: `float simplex_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    // Simplified implementation
    return mix(0.0, 1.0, f.x * f.y);
}`,
    });
    
    this.functionLibrary.set('hsv2rgb', {
      name: 'hsv2rgb',
      category: 'color',
      description: 'Convert HSV to RGB color space',
      code: `float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}`,
    });
  }

async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Metal Shader MCP Server running on stdio');
  }
}

// CLI entrypoint: run only when executed directly
const isDirectRun = Boolean(process.argv[1] && /index\.(m?js|ts)$/.test(process.argv[1]));

if (isDirectRun) {
  const server = new MetalShaderMCPServer();
  server.run().catch(console.error);

  // Keep the process alive and handle stdio properly
  process.stdin.resume();

  // Handle parent process termination (for when launched from Swift)
  if (process.argv.includes('--stdio')) {
    // Monitor stdin for EOF (parent process terminated)
    process.stdin.on('end', () => {
      console.error('Parent process terminated, shutting down...');
      process.exit(0);
    });
    
    // Handle SIGINT and SIGTERM gracefully
    process.on('SIGINT', () => {
      console.error('Received SIGINT, shutting down gracefully...');
      process.exit(0);
    });
    
    process.on('SIGTERM', () => {
      console.error('Received SIGTERM, shutting down gracefully...');
      process.exit(0);
    });
    
    // Prevent uncaught exceptions from crashing
    process.on('uncaughtException', (err) => {
      console.error('Uncaught exception:', err);
    });
    
    process.on('unhandledRejection', (reason, promise) => {
      console.error('Unhandled rejection at:', promise, 'reason:', reason);
    });
  }
}

export default MetalShaderMCPServer;
