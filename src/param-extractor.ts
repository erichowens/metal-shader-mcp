/**
 * Metal Shader Parameter Extraction Tool
 * MCP Tool #2: Auto-extract uniforms and generate UI controls
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";

interface ShaderParameter {
  name: string;
  type: string;
  defaultValue?: any;
  min?: number;
  max?: number;
  step?: number;
  description?: string;
  uiControl?: 'slider' | 'checkbox' | 'color' | 'dropdown' | 'vector';
}

interface UIControl {
  type: string;
  label: string;
  binding: string;
  config: any;
}

export class ParameterExtractor {
  private server: Server;
  private paramCache = new Map<string, ShaderParameter[]>();

  constructor() {
    this.server = new Server({
      name: "metal-param-extractor",
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
          name: "extract_parameters",
          description: "Extract uniform parameters from Metal shader source",
          inputSchema: {
            type: "object",
            properties: {
              source: { type: "string", description: "Metal shader source code" },
              includeComments: { type: "boolean", description: "Parse comments for hints" }
            },
            required: ["source"]
          }
        },
        {
          name: "generate_ui",
          description: "Generate UI control configuration from parameters",
          inputSchema: {
            type: "object",
            properties: {
              parameters: { 
                type: "array", 
                description: "Array of shader parameters",
                items: { type: "object" }
              },
              style: { 
                type: "string", 
                enum: ["panel", "overlay", "modal"],
                description: "UI layout style" 
              }
            },
            required: ["parameters"]
          }
        },
        {
          name: "infer_ranges",
          description: "Infer reasonable ranges for numeric parameters",
          inputSchema: {
            type: "object",
            properties: {
              source: { type: "string", description: "Metal shader source code" },
              paramName: { type: "string", description: "Parameter name to analyze" }
            },
            required: ["source", "paramName"]
          }
        },
        {
          name: "export_ui_config",
          description: "Export UI configuration as JSON or Swift code",
          inputSchema: {
            type: "object",
            properties: {
              parameters: { type: "array", items: { type: "object" } },
              format: { type: "string", enum: ["json", "swift", "html"] }
            },
            required: ["parameters", "format"]
          }
        }
      ]
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      switch (name) {
        case "extract_parameters":
          return await this.extractParameters(
            (args as any).source as string, 
            (args as any).includeComments as boolean
          );
        
        case "generate_ui":
          return await this.generateUI(
            (args as any).parameters as ShaderParameter[],
            (args as any).style as string
          );
        
        case "infer_ranges":
          return await this.inferRanges(
            (args as any).source as string,
            (args as any).paramName as string
          );
        
        case "export_ui_config":
          return await this.exportUIConfig(
            (args as any).parameters as ShaderParameter[],
            (args as any).format as string
          );
        
        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    });
  }

  async extractParameters(source: string, includeComments: boolean = true) {
    const parameters: ShaderParameter[] = [];
    
    // Match struct definitions for uniforms
    const structRegex = /struct\s+(\w+)\s*\{([^}]+)\}/g;
    const uniformStructs = new Map<string, string>();
    
    let match;
    while ((match = structRegex.exec(source)) !== null) {
      const structName = match[1];
      const structBody = match[2];
      
      if (structName.toLowerCase().includes('uniform') || 
          source.includes(`constant ${structName}&`)) {
        uniformStructs.set(structName, structBody);
      }
    }
    
    // Parse each uniform struct
    for (const [structName, body] of uniformStructs) {
      const lines = body.split('\n');
      
      for (const line of lines) {
        // Parse field: type name; // optional comment
        const fieldMatch = line.match(/^\s*(\w+(?:<[^>]+>)?)\s+(\w+)\s*(?:=\s*([^;]+))?\s*;\s*(?:\/\/\s*(.*))?/);
        
        if (fieldMatch) {
          const [, type, name, defaultVal, comment] = fieldMatch;
          const param: ShaderParameter = {
            name,
            type: this.normalizeType(type)
          };
          
          // Parse default value
          if (defaultVal) {
            param.defaultValue = this.parseDefaultValue(defaultVal, type);
          }
          
          // Parse comment for hints
          if (includeComments && comment) {
            const rangeMatch = comment.match(/\[([^\]]+)\]/);
            if (rangeMatch) {
              const range = rangeMatch[1].split(',').map(s => parseFloat(s.trim()));
              if (range.length >= 2) {
                param.min = range[0];
                param.max = range[1];
                if (range[2]) param.step = range[2];
              }
            }
            
            // Extract description
            const descMatch = comment.replace(/\[[^\]]+\]/, '').trim();
            if (descMatch) {
              param.description = descMatch;
            }
          }
          
          // Infer UI control type
          param.uiControl = this.inferUIControl(param);
          
          parameters.push(param);
        }
      }
    }
    
    // Cache results
    const cacheKey = source.substring(0, 100); // Use first 100 chars as key
    this.paramCache.set(cacheKey, parameters);
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(parameters, null, 2)
      }]
    };
  }

  private normalizeType(type: string): string {
    // Normalize Metal types to standard types
    const typeMap: Record<string, string> = {
      'float': 'float',
      'float2': 'vec2',
      'float3': 'vec3',
      'float4': 'vec4',
      'int': 'int',
      'int2': 'ivec2',
      'bool': 'bool',
      'half': 'float',
      'half2': 'vec2',
      'half3': 'vec3',
      'half4': 'vec4',
      'SIMD2<Float>': 'vec2',
      'SIMD3<Float>': 'vec3',
      'SIMD4<Float>': 'vec4'
    };
    
    return typeMap[type] || type;
  }

  private parseDefaultValue(value: string, type: string): any {
    value = value.trim();
    
    if (type.includes('float') || type.includes('half')) {
      if (value.includes('(')) {
        // Vector constructor
        const nums = value.match(/[\d.]+/g);
        return nums ? nums.map(n => parseFloat(n)) : null;
      }
      return parseFloat(value);
    } else if (type.includes('int')) {
      return parseInt(value);
    } else if (type === 'bool') {
      return value === 'true';
    }
    
    return value;
  }

  private inferUIControl(param: ShaderParameter): 'slider' | 'checkbox' | 'color' | 'dropdown' | 'vector' {
    const { name, type } = param;
    const lowerName = name.toLowerCase();
    
    // Infer from name
    if (lowerName.includes('color') || lowerName.includes('tint')) {
      return 'color';
    }
    if (lowerName.includes('enable') || lowerName.includes('use') || type === 'bool') {
      return 'checkbox';
    }
    if (type.includes('vec') || type.includes('SIMD')) {
      return 'vector';
    }
    
    // Default to slider for numeric types
    if (type.includes('float') || type.includes('int')) {
      return 'slider';
    }
    
    return 'slider';
  }

  async generateUI(parameters: ShaderParameter[], style: string = 'panel') {
    const controls: UIControl[] = [];
    
    for (const param of parameters) {
      let control: UIControl;
      
      switch (param.uiControl) {
        case 'slider':
          control = {
            type: 'slider',
            label: param.description || param.name,
            binding: param.name,
            config: {
              min: param.min ?? 0,
              max: param.max ?? 1,
              step: param.step ?? 0.01,
              default: param.defaultValue ?? 0.5
            }
          };
          break;
        
        case 'checkbox':
          control = {
            type: 'checkbox',
            label: param.description || param.name,
            binding: param.name,
            config: {
              default: param.defaultValue ?? false
            }
          };
          break;
        
        case 'color':
          control = {
            type: 'color',
            label: param.description || param.name,
            binding: param.name,
            config: {
              format: 'rgb',
              default: param.defaultValue ?? [1, 1, 1]
            }
          };
          break;
        
        case 'vector':
          const dims = parseInt(param.type.match(/\d/)?.[0] || '2');
          control = {
            type: 'vector',
            label: param.description || param.name,
            binding: param.name,
            config: {
              dimensions: dims,
              min: param.min ?? -1,
              max: param.max ?? 1,
              default: param.defaultValue ?? new Array(dims).fill(0)
            }
          };
          break;
        
        default:
          control = {
            type: 'text',
            label: param.name,
            binding: param.name,
            config: {}
          };
      }
      
      controls.push(control);
    }
    
    const uiConfig = {
      style,
      controls,
      layout: style === 'panel' ? 'vertical' : 'grid'
    };
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(uiConfig, null, 2)
      }]
    };
  }

  async inferRanges(source: string, paramName: string) {
    // Analyze usage patterns to infer reasonable ranges
    const usageRegex = new RegExp(`${paramName}\\s*([*+\\-/])\\s*([\\d.]+)`, 'g');
    const comparisons = new RegExp(`${paramName}\\s*([<>]=?)\\s*([\\d.]+)`, 'g');
    
    const values: number[] = [];
    let match;
    
    // Find multipliers/divisors
    while ((match = usageRegex.exec(source)) !== null) {
      const [, op, value] = match;
      const num = parseFloat(value);
      
      if (op === '*') {
        // If multiplied by large number, param is probably 0-1
        if (num > 10) {
          values.push(0, 1);
        } else {
          values.push(0, num);
        }
      } else if (op === '/') {
        // If divided, might be larger
        values.push(0, 1 / num);
      }
    }
    
    // Find comparisons
    while ((match = comparisons.exec(source)) !== null) {
      const [, op, value] = match;
      values.push(parseFloat(value));
    }
    
    // Common patterns
    if (paramName.toLowerCase().includes('time')) {
      return { min: 0, max: 100, step: 0.1 };
    }
    if (paramName.toLowerCase().includes('angle')) {
      return { min: 0, max: Math.PI * 2, step: 0.01 };
    }
    if (paramName.toLowerCase().includes('scale') || paramName.toLowerCase().includes('zoom')) {
      return { min: 0.1, max: 5, step: 0.1 };
    }
    if (paramName.toLowerCase().includes('intensity') || paramName.toLowerCase().includes('strength')) {
      return { min: 0, max: 2, step: 0.05 };
    }
    
    // Calculate from found values
    if (values.length > 0) {
      const min = Math.min(...values);
      const max = Math.max(...values);
      const range = max - min;
      const step = range > 10 ? 1 : range > 1 ? 0.1 : 0.01;
      
      return {
        content: [{
          type: "text",
          text: JSON.stringify({ min, max, step }, null, 2)
        }]
      };
    }
    
    // Default ranges based on type
    return {
      content: [{
        type: "text",
        text: JSON.stringify({ min: 0, max: 1, step: 0.01 }, null, 2)
      }]
    };
  }

  private async exportUIConfig(parameters: ShaderParameter[], format: string) {
    if (format === 'swift') {
      return this.exportSwiftUI(parameters);
    } else if (format === 'html') {
      return this.exportHTML(parameters);
    } else {
      // Default JSON
      return {
        content: [{
          type: "text",
          text: JSON.stringify(parameters, null, 2)
        }]
      };
    }
  }

  private exportSwiftUI(parameters: ShaderParameter[]) {
    let code = `import SwiftUI

struct ShaderControlPanel: View {
    @Binding var uniforms: Uniforms
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {\n`;
    
    for (const param of parameters) {
      const label = param.description || param.name;
      
      if (param.uiControl === 'slider') {
        code += `            HStack {
                Text("${label}")
                    .frame(width: 120, alignment: .trailing)
                Slider(value: $uniforms.${param.name}, in: ${param.min ?? 0}...${param.max ?? 1})
                Text(String(format: "%.2f", uniforms.${param.name}))
                    .frame(width: 50)
            }\n`;
      } else if (param.uiControl === 'checkbox') {
        code += `            Toggle("${label}", isOn: $uniforms.${param.name})\n`;
      }
    }
    
    code += `        }
        .padding()
    }
}`;
    
    return {
      content: [{
        type: "text",
        text: code
      }]
    };
  }

  private exportHTML(parameters: ShaderParameter[]) {
    let html = `<div class="shader-controls">\n`;
    
    for (const param of parameters) {
      const label = param.description || param.name;
      
      if (param.uiControl === 'slider') {
        html += `  <div class="control-group">
    <label for="${param.name}">${label}</label>
    <input type="range" id="${param.name}" 
           min="${param.min ?? 0}" max="${param.max ?? 1}" 
           step="${param.step ?? 0.01}" value="${param.defaultValue ?? 0.5}">
    <span class="value">0.5</span>
  </div>\n`;
      } else if (param.uiControl === 'checkbox') {
        html += `  <div class="control-group">
    <label>
      <input type="checkbox" id="${param.name}" ${param.defaultValue ? 'checked' : ''}>
      ${label}
    </label>
  </div>\n`;
      }
    }
    
    html += `</div>`;
    
    return {
      content: [{
        type: "text",
        text: html
      }]
    };
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Parameter Extractor MCP server running");
  }
}

// Start server if run directly
if (require.main === module) {
  const tool = new ParameterExtractor();
  tool.start().catch(console.error);
}