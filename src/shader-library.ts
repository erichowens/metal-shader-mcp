/**
 * Metal Shader Library Tool
 * MCP Tool #3: Searchable collection of shader functions and snippets
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";

interface ShaderFunction {
  name: string;
  category: string;
  description: string;
  code: string;
  parameters?: string[];
  returnType?: string;
  tags: string[];
  usage?: string;
}

export class ShaderLibrary {
  private server: Server;
  private library: Map<string, ShaderFunction>;

  constructor() {
    this.server = new Server({
      name: "metal-shader-library",
      version: "1.0.0",
    }, {
      capabilities: {
        tools: {}
      }
    });

    this.library = new Map();
    this.initializeLibrary();
    this.setupHandlers();
  }

  private initializeLibrary() {
    // Noise functions
    this.addFunction({
      name: "simplex_noise",
      category: "noise",
      description: "2D Simplex noise function",
      tags: ["noise", "procedural", "organic"],
      code: `float simplex_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + float2(1, 0));
    float c = hash(i + float2(0, 1));
    float d = hash(i + float2(1, 1));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}`,
      returnType: "float",
      parameters: ["float2 p"],
      usage: "float n = simplex_noise(uv * 10.0);"
    });

    this.addFunction({
      name: "fbm",
      category: "noise",
      description: "Fractal Brownian Motion",
      tags: ["noise", "fractal", "terrain"],
      code: `float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * simplex_noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}`,
      returnType: "float",
      parameters: ["float2 p", "int octaves"],
      usage: "float terrain = fbm(uv * 5.0, 6);"
    });

    // Color functions
    this.addFunction({
      name: "hsv2rgb",
      category: "color",
      description: "Convert HSV to RGB color space",
      tags: ["color", "conversion", "hsv", "rgb"],
      code: `float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}`,
      returnType: "float3",
      parameters: ["float3 c"],
      usage: "float3 color = hsv2rgb(float3(hue, 1.0, 1.0));"
    });

    this.addFunction({
      name: "palette",
      category: "color",
      description: "Cosine gradient palette generator",
      tags: ["color", "gradient", "palette"],
      code: `float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}`,
      returnType: "float3",
      parameters: ["float t", "float3 a", "float3 b", "float3 c", "float3 d"],
      usage: `float3 color = palette(
    t,
    float3(0.5, 0.5, 0.5),
    float3(0.5, 0.5, 0.5),
    float3(1.0, 1.0, 1.0),
    float3(0.0, 0.10, 0.20)
);`
    });

    // Math functions
    this.addFunction({
      name: "rotate2D",
      category: "math",
      description: "2D rotation matrix",
      tags: ["math", "transform", "rotation", "2d"],
      code: `float2x2 rotate2D(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2x2(c, -s, s, c);
}`,
      returnType: "float2x2",
      parameters: ["float angle"],
      usage: "uv = rotate2D(time) * uv;"
    });

    this.addFunction({
      name: "smoothMin",
      category: "math",
      description: "Smooth minimum for SDF blending",
      tags: ["math", "sdf", "blending"],
      code: `float smoothMin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}`,
      returnType: "float",
      parameters: ["float a", "float b", "float k"],
      usage: "float d = smoothMin(sphere1, sphere2, 0.1);"
    });

    // SDF primitives
    this.addFunction({
      name: "sdSphere",
      category: "sdf",
      description: "Signed distance function for sphere",
      tags: ["sdf", "3d", "primitive", "sphere"],
      code: `float sdSphere(float3 p, float radius) {
    return length(p) - radius;
}`,
      returnType: "float",
      parameters: ["float3 p", "float radius"],
      usage: "float d = sdSphere(pos, 0.5);"
    });

    this.addFunction({
      name: "sdBox",
      category: "sdf",
      description: "Signed distance function for box",
      tags: ["sdf", "3d", "primitive", "box"],
      code: `float sdBox(float3 p, float3 size) {
    float3 q = abs(p) - size;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}`,
      returnType: "float",
      parameters: ["float3 p", "float3 size"],
      usage: "float d = sdBox(pos, float3(0.3, 0.4, 0.5));"
    });

    // Effects
    this.addFunction({
      name: "chromatic_aberration",
      category: "effects",
      description: "Chromatic aberration post-processing effect",
      tags: ["effects", "post-process", "chromatic"],
      code: `float3 chromatic_aberration(texture2d<float> tex, float2 uv, float amount) {
    float2 offset = (uv - 0.5) * amount;
    float r = tex.sample(sampler, uv + offset * 0.0).r;
    float g = tex.sample(sampler, uv + offset * 0.5).g;
    float b = tex.sample(sampler, uv + offset * 1.0).b;
    return float3(r, g, b);
}`,
      returnType: "float3",
      parameters: ["texture2d<float> tex", "float2 uv", "float amount"],
      usage: "color = chromatic_aberration(texture, uv, 0.01);"
    });

    this.addFunction({
      name: "vignette",
      category: "effects",
      description: "Vignette darkening effect",
      tags: ["effects", "post-process", "vignette"],
      code: `float vignette(float2 uv, float intensity, float extent) {
    uv *= 1.0 - uv;
    float vig = uv.x * uv.y * intensity;
    return pow(vig, extent);
}`,
      returnType: "float",
      parameters: ["float2 uv", "float intensity", "float extent"],
      usage: "color *= vignette(uv, 15.0, 0.25);"
    });
  }

  private addFunction(func: ShaderFunction) {
    this.library.set(func.name, func);
  }

  private setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: "search_functions",
          description: "Search shader library for functions",
          inputSchema: {
            type: "object",
            properties: {
              query: { type: "string", description: "Search query (name, category, or tags)" },
              category: { type: "string", enum: ["noise", "color", "math", "sdf", "effects"] }
            }
          }
        },
        {
          name: "get_function",
          description: "Get a specific shader function by name",
          inputSchema: {
            type: "object",
            properties: {
              name: { type: "string", description: "Function name" }
            },
            required: ["name"]
          }
        },
        {
          name: "inject_function",
          description: "Inject function into shader code",
          inputSchema: {
            type: "object",
            properties: {
              functionName: { type: "string", description: "Function to inject" },
              shaderCode: { type: "string", description: "Existing shader code" },
              position: { type: "string", enum: ["before_vertex", "before_fragment", "after_includes"] }
            },
            required: ["functionName", "shaderCode"]
          }
        },
        {
          name: "list_categories",
          description: "List all function categories",
          inputSchema: {
            type: "object",
            properties: {}
          }
        },
        {
          name: "add_custom_function",
          description: "Add a custom function to the library",
          inputSchema: {
            type: "object",
            properties: {
              name: { type: "string" },
              category: { type: "string" },
              description: { type: "string" },
              code: { type: "string" },
              tags: { type: "array", items: { type: "string" } }
            },
            required: ["name", "category", "code"]
          }
        }
      ]
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      switch (name) {
        case "search_functions":
          return await this.searchFunctions((args as any)?.query as string, (args as any)?.category as string);
        
        case "get_function":
          return await this.getFunction((args as any).name as string);
        
        case "inject_function":
          return await this.injectFunction(
            (args as any).functionName as string,
            (args as any).shaderCode as string,
            (args as any).position as string
          );
        
        case "list_categories":
          return await this.listCategories();
        
        case "add_custom_function":
          return await this.addCustomFunction(args as any);
        
        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    });
  }

  private async searchFunctions(query?: string, category?: string) {
    let results: ShaderFunction[] = Array.from(this.library.values());
    
    if (category) {
      results = results.filter(f => f.category === category);
    }
    
    if (query) {
      const lowerQuery = query.toLowerCase();
      results = results.filter(f => 
        f.name.toLowerCase().includes(lowerQuery) ||
        f.description.toLowerCase().includes(lowerQuery) ||
        f.tags.some(t => t.toLowerCase().includes(lowerQuery))
      );
    }
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(results.map(f => ({
          name: f.name,
          category: f.category,
          description: f.description,
          tags: f.tags
        })), null, 2)
      }]
    };
  }

  private async getFunction(name: string) {
    const func = this.library.get(name);
    
    if (!func) {
      return {
        content: [{
          type: "text",
          text: `Function not found: ${name}`
        }],
        isError: true
      };
    }
    
    return {
      content: [{
        type: "text",
        text: func.code + (func.usage ? `\n\n// Usage:\n// ${func.usage}` : "")
      }]
    };
  }

  private async injectFunction(functionName: string, shaderCode: string, position: string = "after_includes") {
    const func = this.library.get(functionName);
    
    if (!func) {
      return {
        content: [{
          type: "text",
          text: `Function not found: ${functionName}`
        }],
        isError: true
      };
    }
    
    let injectedCode = shaderCode;
    const functionWithComment = `\n// ${func.description}\n${func.code}\n`;
    
    if (position === "before_vertex") {
      const vertexMatch = shaderCode.match(/vertex\s+\w+\s+\w+/);
      if (vertexMatch) {
        const index = vertexMatch.index!;
        injectedCode = shaderCode.slice(0, index) + functionWithComment + shaderCode.slice(index);
      }
    } else if (position === "before_fragment") {
      const fragmentMatch = shaderCode.match(/fragment\s+\w+\s+\w+/);
      if (fragmentMatch) {
        const index = fragmentMatch.index!;
        injectedCode = shaderCode.slice(0, index) + functionWithComment + shaderCode.slice(index);
      }
    } else {
      // After includes
      const includeMatch = shaderCode.match(/#include\s+<[^>]+>\n/g);
      if (includeMatch) {
        const lastInclude = includeMatch[includeMatch.length - 1];
        const index = shaderCode.lastIndexOf(lastInclude) + lastInclude.length;
        injectedCode = shaderCode.slice(0, index) + functionWithComment + shaderCode.slice(index);
      }
    }
    
    return {
      content: [{
        type: "text",
        text: injectedCode
      }]
    };
  }

  private async listCategories() {
    const categories = new Set<string>();
    this.library.forEach(f => categories.add(f.category));
    
    return {
      content: [{
        type: "text",
        text: Array.from(categories).join("\n")
      }]
    };
  }

  private async addCustomFunction(params: any) {
    const func: ShaderFunction = {
      name: params.name,
      category: params.category,
      description: params.description || "",
      code: params.code,
      tags: params.tags || [],
      parameters: params.parameters,
      returnType: params.returnType,
      usage: params.usage
    };
    
    this.addFunction(func);
    
    return {
      content: [{
        type: "text",
        text: `Added function: ${func.name}`
      }]
    };
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Shader Library MCP server running");
  }
}

// Start server if run directly
if (require.main === module) {
  const tool = new ShaderLibrary();
  tool.start().catch(console.error);
}