/**
 * Metal Shader Hot Reload Tool
 * MCP Tool #1: Live shader reloading without restart
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { promises as fs } from 'fs';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as path from 'path';
import * as crypto from 'crypto';

const execAsync = promisify(exec);

interface ShaderState {
  source: string;
  hash: string;
  lastCompiled: Date;
  parameters: Map<string, any>;
  errors: string[];
}

interface WatchedShader {
  path: string;
  state: ShaderState;
  watcher?: fs.FileHandle;
}

export class HotReloadTool {
  private watchers = new Map<string, WatchedShader>();
  private compiledCache = new Map<string, string>();
  private server: Server;

  constructor() {
    this.server = new Server({
      name: "metal-hot-reload",
      version: "1.0.0",
    }, {
      capabilities: {
        tools: {}
      }
    });

    this.setupHandlers();
  }

  private setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: "shader_watch",
          description: "Watch a Metal shader file for changes and auto-recompile",
          inputSchema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Path to Metal shader file" },
              preserveState: { type: "boolean", description: "Preserve parameters on reload" }
            },
            required: ["path"]
          }
        },
        {
          name: "shader_reload",
          description: "Manually reload and recompile a shader",
          inputSchema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Path to Metal shader file" },
              source: { type: "string", description: "Optional new source code" }
            },
            required: ["path"]
          }
        },
        {
          name: "shader_compile",
          description: "Compile Metal shader and return compiled binary",
          inputSchema: {
            type: "object",
            properties: {
              source: { type: "string", description: "Metal shader source code" },
              target: { type: "string", enum: ["air", "metallib"], description: "Compilation target" }
            },
            required: ["source"]
          }
        },
        {
          name: "shader_validate",
          description: "Validate shader syntax without full compilation",
          inputSchema: {
            type: "object",
            properties: {
              source: { type: "string", description: "Metal shader source code" }
            },
            required: ["source"]
          }
        },
        {
          name: "shader_state",
          description: "Get current state of a watched shader",
          inputSchema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Path to Metal shader file" }
            },
            required: ["path"]
          }
        },
        {
          name: "shader_stop_watch",
          description: "Stop watching a shader file",
          inputSchema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Path to Metal shader file" }
            },
            required: ["path"]
          }
        },
        {
          name: "shader_list_watched",
          description: "List all currently watched shader files",
          inputSchema: {
            type: "object",
            properties: {}
          }
        }
      ]
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      switch (name) {
        case "shader_watch":
          return await this.watchShader((args as any).path as string, (args as any).preserveState as boolean);
        
        case "shader_reload":
          return await this.reloadShader((args as any).path as string, (args as any).source as string);
        
        case "shader_compile":
          return await this.compileShader((args as any).source as string, (args as any).target as string);
        
        case "shader_validate":
          return await this.validateShader((args as any).source as string);
        
        case "shader_state":
          return await this.getShaderState((args as any).path as string);
        
        case "shader_stop_watch":
          return await this.stopWatching((args as any).path as string);
        
        case "shader_list_watched":
          return await this.listWatched();
        
        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    });
  }

  private async watchShader(shaderPath: string, preserveState: boolean = true) {
    try {
      const absolutePath = path.resolve(shaderPath);
      const source = await fs.readFile(absolutePath, 'utf-8');
      const hash = crypto.createHash('md5').update(source).digest('hex');

      const watcher: WatchedShader = {
        path: absolutePath,
        state: {
          source,
          hash,
          lastCompiled: new Date(),
          parameters: new Map(),
          errors: []
        }
      };

      // Set up file watcher
      const watchInterval = setInterval(async () => {
        try {
          const newSource = await fs.readFile(absolutePath, 'utf-8');
          const newHash = crypto.createHash('md5').update(newSource).digest('hex');
          
          if (newHash !== watcher.state.hash) {
            console.log(`Shader changed: ${shaderPath}`);
            
            // Compile new version
            const result = await this.compileShader(newSource, 'air');
            
            if (result.success) {
              const oldParams = preserveState ? watcher.state.parameters : new Map();
              watcher.state = {
                source: newSource,
                hash: newHash,
                lastCompiled: new Date(),
                parameters: oldParams,
                errors: []
              };
              
              // Emit reload event
              console.log(`Shader reloaded successfully: ${shaderPath}`);
            } else {
              watcher.state.errors = [result.error || 'Compilation failed'];
              console.error(`Shader compilation failed: ${result.error}`);
            }
          }
        } catch (error) {
          console.error(`Watch error: ${error}`);
        }
      }, 500); // Check every 500ms

      this.watchers.set(absolutePath, watcher);

      return {
        content: [{
          type: "text",
          text: `Watching shader: ${shaderPath}\nInitial hash: ${hash}\nPreserving state: ${preserveState}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: "text",
          text: `Error watching shader: ${error}`
        }],
        isError: true
      };
    }
  }

  private async reloadShader(shaderPath: string, newSource?: string) {
    try {
      const absolutePath = path.resolve(shaderPath);
      const source = newSource || await fs.readFile(absolutePath, 'utf-8');
      
      // Compile
      const result = await this.compileShader(source, 'air');
      
      if (result.success) {
        // Update watched state if exists
        const watcher = this.watchers.get(absolutePath);
        if (watcher) {
          watcher.state.source = source;
          watcher.state.hash = crypto.createHash('md5').update(source).digest('hex');
          watcher.state.lastCompiled = new Date();
          watcher.state.errors = [];
        }
        
        return {
          content: [{
            type: "text",
            text: `Shader reloaded successfully\nCompilation time: ${result.compilationTime}ms`
          }]
        };
      } else {
        return {
          content: [{
            type: "text",
            text: `Reload failed: ${result.error}`
          }],
          isError: true
        };
      }
    } catch (error) {
      return {
        content: [{
          type: "text",
          text: `Error reloading shader: ${error}`
        }],
        isError: true
      };
    }
  }

  private async compileShader(source: string, target: string = 'air') {
    const startTime = Date.now();
    
    try {
      // Write to temp file
      const tempPath = `/tmp/shader_${Date.now()}.metal`;
      await fs.writeFile(tempPath, source);
      
      // Compile based on target
      let command = '';
      let outputPath = '';
      
      if (target === 'metallib') {
        outputPath = tempPath.replace('.metal', '.metallib');
        command = `xcrun -sdk macosx metal -c ${tempPath} -o ${tempPath}.air && xcrun -sdk macosx metallib ${tempPath}.air -o ${outputPath}`;
      } else {
        outputPath = tempPath.replace('.metal', '.air');
        command = `xcrun -sdk macosx metal -c ${tempPath} -o ${outputPath}`;
      }
      
      const { stdout, stderr } = await execAsync(command);
      
      if (stderr && !stderr.includes('warning')) {
        throw new Error(stderr);
      }
      
      // Read compiled output
      const compiled = await fs.readFile(outputPath);
      const compilationTime = Date.now() - startTime;
      
      // Cache result
      const hash = crypto.createHash('md5').update(source).digest('hex');
      this.compiledCache.set(hash, outputPath);
      
      // Clean up temp files
      await fs.unlink(tempPath).catch(() => {});
      
      return {
        success: true,
        compiledPath: outputPath,
        compilationTime,
        content: [{
          type: "text",
          text: `Compilation successful (${compilationTime}ms)\nOutput: ${outputPath}`
        }]
      };
    } catch (error) {
      return {
        success: false,
        error: (error as Error).toString(),
        compilationTime: Date.now() - startTime,
        content: [{
          type: "text",
          text: `Compilation failed: ${error}`
        }],
        isError: true
      };
    }
  }

  private async validateShader(source: string) {
    try {
      // Quick syntax validation using Metal compiler
      const tempPath = `/tmp/validate_${Date.now()}.metal`;
      await fs.writeFile(tempPath, source);
      
      const { stdout, stderr } = await execAsync(
        `xcrun -sdk macosx metal -fsyntax-only ${tempPath}`
      );
      
      await fs.unlink(tempPath).catch(() => {});
      
      if (stderr && !stderr.includes('warning')) {
        return {
          content: [{
            type: "text",
            text: `Validation failed:\n${stderr}`
          }],
          isError: true
        };
      }
      
      return {
        content: [{
          type: "text",
          text: "Shader validation passed"
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: "text",
          text: `Validation error: ${error}`
        }],
        isError: true
      };
    }
  }

  private async getShaderState(shaderPath: string) {
    const absolutePath = path.resolve(shaderPath);
    const watcher = this.watchers.get(absolutePath);
    
    if (!watcher) {
      return {
        content: [{
          type: "text",
          text: `No watcher found for: ${shaderPath}`
        }],
        isError: true
      };
    }
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          path: watcher.path,
          hash: watcher.state.hash,
          lastCompiled: watcher.state.lastCompiled,
          hasErrors: watcher.state.errors.length > 0,
          errors: watcher.state.errors,
          parameters: Array.from(watcher.state.parameters.entries())
        }, null, 2)
      }]
    };
  }

  private async stopWatching(shaderPath: string) {
    const absolutePath = path.resolve(shaderPath);
    const watcher = this.watchers.get(absolutePath);
    
    if (watcher) {
      this.watchers.delete(absolutePath);
      return {
        content: [{
          type: "text",
          text: `Stopped watching: ${shaderPath}`
        }]
      };
    }
    
    return {
      content: [{
        type: "text",
        text: `No watcher found for: ${shaderPath}`
      }],
      isError: true
    };
  }

  private async listWatched() {
    const watched = Array.from(this.watchers.keys()).map(p => path.basename(p));
    
    return {
      content: [{
        type: "text",
        text: watched.length > 0 
          ? `Watching ${watched.length} shaders:\n${watched.join('\n')}` 
          : "No shaders currently being watched"
      }]
    };
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Hot Reload MCP server running");
  }
}

// Start server if run directly
if (require.main === module) {
  const tool = new HotReloadTool();
  tool.start().catch(console.error);
}