/**
 * Shader Parameters Management
 * Manages uniform parameters and shader configurations
 */

export interface UniformValue {
  value: number | number[] | boolean;
  type: 'float' | 'vec2' | 'vec3' | 'vec4' | 'mat4' | 'bool' | 'int';
  min?: number;
  max?: number;
  step?: number;
  description?: string;
}

export interface ShaderConfig {
  name: string;
  uniforms: Record<string, UniformValue>;
  metadata?: {
    author?: string;
    version?: string;
    description?: string;
    tags?: string[];
  };
}

export class ShaderParameters {
  private configs: Map<string, ShaderConfig> = new Map();
  private currentUniforms: Record<string, any> = {};
  
  /**
   * Register a shader configuration
   */
  registerConfig(config: ShaderConfig): void {
    this.configs.set(config.name, config);
  }
  
  /**
   * Load configuration by name
   */
  loadConfig(name: string): ShaderConfig | undefined {
    const config = this.configs.get(name);
    if (config) {
      // Set current uniforms from config
      this.currentUniforms = {};
      for (const [key, uniform] of Object.entries(config.uniforms)) {
        this.currentUniforms[key] = uniform.value;
      }
    }
    return config;
  }
  
  /**
   * Update uniform values
   */
  updateUniforms(updates: Record<string, any>): void {
    Object.assign(this.currentUniforms, updates);
  }
  
  /**
   * Get current uniform values
   */
  getUniforms(): Record<string, any> {
    return { ...this.currentUniforms };
  }
  
  /**
   * Generate Metal buffer data for uniforms
   */
  generateBufferData(): ArrayBuffer {
    // Calculate total size needed
    let totalSize = 0;
    const layout: Array<{ key: string; offset: number; size: number }> = [];
    
    for (const [key, value] of Object.entries(this.currentUniforms)) {
      const size = this.getUniformSize(value);
      layout.push({ key, offset: totalSize, size });
      totalSize += size;
    }
    
    // Align to 16 bytes
    totalSize = Math.ceil(totalSize / 16) * 16;
    
    // Create buffer
    const buffer = new ArrayBuffer(totalSize);
    const view = new DataView(buffer);
    
    // Write values
    for (const { key, offset } of layout) {
      const value = this.currentUniforms[key];
      this.writeValue(view, offset, value);
    }
    
    return buffer;
  }
  
  /**
   * Create preset configurations
   */
  static createPresets(): ShaderParameters {
    const params = new ShaderParameters();
    
    // Kaleidoscope preset
    params.registerConfig({
      name: 'kaleidoscope',
      uniforms: {
        time: {
          value: 0,
          type: 'float',
          min: 0,
          max: 1,
          description: 'Animation time',
        },
        segments: {
          value: 6,
          type: 'int',
          min: 3,
          max: 12,
          description: 'Number of kaleidoscope segments',
        },
        rotation: {
          value: 0,
          type: 'float',
          min: 0,
          max: Math.PI * 2,
          description: 'Rotation angle',
        },
        zoom: {
          value: 1,
          type: 'float',
          min: 0.5,
          max: 3,
          description: 'Zoom level',
        },
        center: {
          value: [0.5, 0.5],
          type: 'vec2',
          description: 'Center point',
        },
        colorShift: {
          value: [1, 1, 1],
          type: 'vec3',
          description: 'RGB color multipliers',
        },
      },
      metadata: {
        author: 'Shimmer Team',
        version: '1.0.0',
        description: 'Classic kaleidoscope effect with rotation and zoom',
        tags: ['kaleidoscope', 'mirror', 'symmetric'],
      },
    });
    
    // Prismatic dissolve preset
    params.registerConfig({
      name: 'prismatic_dissolve',
      uniforms: {
        progress: {
          value: 0,
          type: 'float',
          min: 0,
          max: 1,
          description: 'Dissolve progress',
        },
        blockSize: {
          value: 32,
          type: 'float',
          min: 8,
          max: 128,
          description: 'Size of color blocks',
        },
        noiseScale: {
          value: 2,
          type: 'float',
          min: 0.5,
          max: 10,
          description: 'Noise pattern scale',
        },
        chromaticAberration: {
          value: 0.01,
          type: 'float',
          min: 0,
          max: 0.1,
          description: 'Chromatic aberration amount',
        },
        breathingRate: {
          value: 0.4,
          type: 'float',
          min: 0.1,
          max: 2,
          description: 'Breathing animation rate (Hz)',
        },
      },
      metadata: {
        author: 'Shimmer Team',
        version: '1.0.0',
        description: 'Prismatic RGBY block dissolve effect',
        tags: ['dissolve', 'prismatic', 'transition'],
      },
    });
    
    // Liquid geometry preset
    params.registerConfig({
      name: 'liquid_geometry',
      uniforms: {
        time: {
          value: 0,
          type: 'float',
          description: 'Animation time',
        },
        viscosity: {
          value: 0.95,
          type: 'float',
          min: 0.8,
          max: 0.99,
          description: 'Liquid viscosity',
        },
        turbulence: {
          value: 0.5,
          type: 'float',
          min: 0,
          max: 1,
          description: 'Turbulence amount',
        },
        flowDirection: {
          value: [1, 0],
          type: 'vec2',
          description: 'Flow direction vector',
        },
        colorBleed: {
          value: 0.2,
          type: 'float',
          min: 0,
          max: 1,
          description: 'Color bleeding between regions',
        },
      },
      metadata: {
        author: 'Shimmer Team',
        version: '1.0.0',
        description: 'Liquid flow geometry effect',
        tags: ['liquid', 'flow', 'organic'],
      },
    });
    
    // Mondrian grid preset
    params.registerConfig({
      name: 'mondrian_grid',
      uniforms: {
        gridDensity: {
          value: 8,
          type: 'int',
          min: 2,
          max: 20,
          description: 'Grid subdivision density',
        },
        lineThickness: {
          value: 2,
          type: 'float',
          min: 0.5,
          max: 10,
          description: 'Grid line thickness',
        },
        primaryColors: {
          value: [1, 0, 0, 1],  // RGBA
          type: 'vec4',
          description: 'Primary color palette',
        },
        randomSeed: {
          value: 42,
          type: 'int',
          description: 'Random seed for grid generation',
        },
        animationPhase: {
          value: 0,
          type: 'float',
          min: 0,
          max: 1,
          description: 'Animation phase',
        },
      },
      metadata: {
        author: 'Shimmer Team',
        version: '1.0.0',
        description: 'Mondrian-style grid layout',
        tags: ['grid', 'mondrian', 'geometric'],
      },
    });
    
    return params;
  }
  
  /**
   * Export configuration to JSON
   */
  exportConfig(name: string): string | undefined {
    const config = this.configs.get(name);
    if (config) {
      return JSON.stringify(config, null, 2);
    }
    return undefined;
  }
  
  /**
   * Import configuration from JSON
   */
  importConfig(json: string): void {
    try {
      const config = JSON.parse(json) as ShaderConfig;
      this.registerConfig(config);
    } catch (error) {
      throw new Error(`Failed to import config: ${error}`);
    }
  }
  
  /**
   * Get size of uniform value in bytes
   */
  private getUniformSize(value: any): number {
    if (typeof value === 'number') return 4;
    if (typeof value === 'boolean') return 4;
    if (Array.isArray(value)) {
      return value.length * 4;
    }
    return 4;
  }
  
  /**
   * Write value to buffer
   */
  private writeValue(view: DataView, offset: number, value: any): void {
    if (typeof value === 'number') {
      view.setFloat32(offset, value, true);
    } else if (typeof value === 'boolean') {
      view.setInt32(offset, value ? 1 : 0, true);
    } else if (Array.isArray(value)) {
      for (let i = 0; i < value.length; i++) {
        view.setFloat32(offset + i * 4, value[i], true);
      }
    }
  }
  
  /**
   * Validate uniform value against its type
   */
  validateUniform(key: string, value: any): boolean {
    // Find the uniform definition
    for (const config of this.configs.values()) {
      const uniform = config.uniforms[key];
      if (uniform) {
        switch (uniform.type) {
          case 'float':
          case 'int':
            return typeof value === 'number';
          case 'bool':
            return typeof value === 'boolean';
          case 'vec2':
            return Array.isArray(value) && value.length === 2;
          case 'vec3':
            return Array.isArray(value) && value.length === 3;
          case 'vec4':
            return Array.isArray(value) && value.length === 4;
          case 'mat4':
            return Array.isArray(value) && value.length === 16;
          default:
            return false;
        }
      }
    }
    
    // If no definition found, accept any value
    return true;
  }
}