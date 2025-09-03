/**
 * Metal Shader Preview Engine
 * Renders shader output to images or live preview
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import sharp from 'sharp';
import crypto from 'crypto';

const execAsync = promisify(exec);

export interface RenderOptions {
  shaderPath: string;
  width: number;
  height: number;
  uniforms: Record<string, any>;
  format?: 'png' | 'jpeg' | 'webp';
}

export interface PreviewServer {
  port: number;
  url: string;
  stop: () => Promise<void>;
}

export class PreviewEngine {
  private previewServer?: PreviewServer;
  private renderCache: Map<string, Buffer> = new Map();
  
  /**
   * Render a single frame using the compiled shader
   */
  async renderFrame(options: RenderOptions): Promise<Buffer> {
    const { shaderPath, width, height, uniforms, format = 'png' } = options;
    
    // Generate cache key
    const cacheKey = this.generateCacheKey(options);
    if (this.renderCache.has(cacheKey)) {
      return this.renderCache.get(cacheKey)!;
    }
    
    // Create temporary render program
    const hash = crypto.createHash('md5').update(cacheKey).digest('hex');
    const tempDir = path.join(os.tmpdir(), 'metal-shader-preview', hash);
    await fs.mkdir(tempDir, { recursive: true });
    
    try {
      // Generate Metal render program
      const renderProgram = this.generateRenderProgram(uniforms);
      const programPath = path.join(tempDir, 'render.swift');
      await fs.writeFile(programPath, renderProgram);
      
      // Compile and run the render program
      const outputPath = path.join(tempDir, `output.${format}`);
      const compileCmd = `swiftc -O -o ${path.join(tempDir, 'render')} ${programPath}`;
      await execAsync(compileCmd);
      
      const runCmd = `${path.join(tempDir, 'render')} ${shaderPath} ${width} ${height} ${outputPath}`;
      await execAsync(runCmd);
      
      // Read and cache the output
      const imageBuffer = await fs.readFile(outputPath);
      
      // Process with sharp if needed
      const processedBuffer = await sharp(imageBuffer)
        .resize(width, height, { fit: 'contain' })
        .toFormat(format)
        .toBuffer();
      
      this.renderCache.set(cacheKey, processedBuffer);
      
      // Cleanup temp files
      await fs.rm(tempDir, { recursive: true, force: true });
      
      return processedBuffer;
      
    } catch (error) {
      // Cleanup on error
      await fs.rm(tempDir, { recursive: true, force: true }).catch(() => {});
      throw error;
    }
  }
  
  /**
   * Start a live preview server
   */
  async startPreviewServer(port: number = 8080): Promise<PreviewServer> {
    const express = await import('express');
    const { WebSocketServer } = await import('ws');
    
    const app = express.default();
    const server = app.listen(port);
    const wss = new WebSocketServer({ server });
    
    // Serve preview page
    app.get('/', (req, res) => {
      res.send(this.getPreviewHTML());
    });
    
    // Serve rendered frames
    app.get('/frame/:id', async (req, res) => {
      const frameId = req.params.id;
      if (this.renderCache.has(frameId)) {
        const buffer = this.renderCache.get(frameId)!;
        res.type('image/png').send(buffer);
      } else {
        res.status(404).send('Frame not found');
      }
    });
    
    // WebSocket for live updates
    wss.on('connection', (ws) => {
      ws.on('message', async (message) => {
        try {
          const data = JSON.parse(message.toString());
          if (data.type === 'render') {
            const buffer = await this.renderFrame(data.options);
            ws.send(JSON.stringify({
              type: 'frame',
              data: buffer.toString('base64'),
            }));
          }
        } catch (error: any) {
          ws.send(JSON.stringify({
            type: 'error',
            message: error.message,
          }));
        }
      });
    });
    
    this.previewServer = {
      port,
      url: `http://localhost:${port}`,
      stop: async () => {
        wss.close();
        await new Promise((resolve) => server.close(resolve));
      },
    };
    
    return this.previewServer;
  }
  
  /**
   * Stop the preview server
   */
  async stopPreviewServer(): Promise<void> {
    if (this.previewServer) {
      await this.previewServer.stop();
      this.previewServer = undefined;
    }
  }
  
  /**
   * Generate Swift program for rendering
   */
  private generateRenderProgram(uniforms: Record<string, any>): string {
    return `
import Metal
import MetalKit
import CoreImage
import AppKit

// Command line arguments
let args = CommandLine.arguments
guard args.count >= 5 else {
    print("Usage: render <shader.metallib> <width> <height> <output.png>")
    exit(1)
}

let shaderPath = args[1]
let width = Int(args[2]) ?? 512
let height = Int(args[3]) ?? 512
let outputPath = args[4]

// Setup Metal
guard let device = MTLCreateSystemDefaultDevice() else {
    print("Metal is not supported")
    exit(1)
}

let commandQueue = device.makeCommandQueue()!
let library = try! device.makeLibrary(filepath: shaderPath)

// Create render pipeline
let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

let pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

// Create texture
let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .bgra8Unorm,
    width: width,
    height: height,
    mipmapped: false
)
textureDescriptor.usage = [.renderTarget, .shaderRead]
let texture = device.makeTexture(descriptor: textureDescriptor)!

// Setup uniforms
struct Uniforms {
    var time: Float = ${uniforms.time || 0}
    var resolution: SIMD2<Float> = SIMD2<Float>(Float(${uniforms.resolution?.x || 'width'}), Float(${uniforms.resolution?.y || 'height'}))
    var touchPoint: SIMD2<Float> = SIMD2<Float>(${uniforms.touchPoint?.x || 0.5}, ${uniforms.touchPoint?.y || 0.5})
}

var uniformData = Uniforms()
let uniformBuffer = device.makeBuffer(bytes: &uniformData, length: MemoryLayout<Uniforms>.size, options: [])

// Render
let renderPassDescriptor = MTLRenderPassDescriptor()
renderPassDescriptor.colorAttachments[0].texture = texture
renderPassDescriptor.colorAttachments[0].loadAction = .clear
renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
renderPassDescriptor.colorAttachments[0].storeAction = .store

let commandBuffer = commandQueue.makeCommandBuffer()!
let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

renderEncoder.setRenderPipelineState(pipelineState)
renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
renderEncoder.endEncoding()

commandBuffer.commit()
commandBuffer.waitUntilCompleted()

// Export to image
let ciImage = CIImage(mtlTexture: texture, options: nil)!
let ciContext = CIContext(mtlDevice: device)
let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)!

let url = URL(fileURLWithPath: outputPath)
let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil)!
CGImageDestinationAddImage(destination, cgImage, nil)
CGImageDestinationFinalize(destination)

print("Rendered to \\(outputPath)")
`;
  }
  
  /**
   * Generate cache key for render options
   */
  private generateCacheKey(options: RenderOptions): string {
    const keyData = {
      shader: options.shaderPath,
      width: options.width,
      height: options.height,
      uniforms: options.uniforms,
      format: options.format,
    };
    return crypto
      .createHash('md5')
      .update(JSON.stringify(keyData))
      .digest('hex');
  }
  
  /**
   * Get HTML for preview page
   */
  private getPreviewHTML(): string {
    return `
<!DOCTYPE html>
<html>
<head>
    <title>Metal Shader Preview</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .preview {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
        }
        
        #canvas {
            width: 100%;
            height: 600px;
            background: #000;
            border-radius: 8px;
        }
        
        .controls {
            margin-top: 20px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        
        .control {
            display: flex;
            flex-direction: column;
        }
        
        label {
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 5px;
            color: #666;
        }
        
        input[type="range"] {
            width: 100%;
        }
        
        .status {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 10px 20px;
            background: white;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .status.connected {
            background: #4CAF50;
            color: white;
        }
        
        .status.disconnected {
            background: #f44336;
            color: white;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 style="color: white; text-align: center;">Metal Shader Live Preview</h1>
        
        <div class="preview">
            <canvas id="canvas"></canvas>
            
            <div class="controls">
                <div class="control">
                    <label>Time</label>
                    <input type="range" id="time" min="0" max="1" step="0.01" value="0">
                </div>
                
                <div class="control">
                    <label>Touch X</label>
                    <input type="range" id="touchX" min="0" max="1" step="0.01" value="0.5">
                </div>
                
                <div class="control">
                    <label>Touch Y</label>
                    <input type="range" id="touchY" min="0" max="1" step="0.01" value="0.5">
                </div>
            </div>
        </div>
    </div>
    
    <div class="status" id="status">Disconnected</div>
    
    <script>
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        const status = document.getElementById('status');
        
        // WebSocket connection
        const ws = new WebSocket('ws://localhost:8080');
        
        ws.onopen = () => {
            status.textContent = 'Connected';
            status.className = 'status connected';
            requestRender();
        };
        
        ws.onclose = () => {
            status.textContent = 'Disconnected';
            status.className = 'status disconnected';
        };
        
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            
            if (data.type === 'frame') {
                const img = new Image();
                img.onload = () => {
                    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                };
                img.src = 'data:image/png;base64,' + data.data;
            } else if (data.type === 'error') {
                console.error('Render error:', data.message);
            }
        };
        
        // Controls
        let renderTimeout;
        function requestRender() {
            clearTimeout(renderTimeout);
            renderTimeout = setTimeout(() => {
                const options = {
                    width: canvas.width,
                    height: canvas.height,
                    uniforms: {
                        time: parseFloat(document.getElementById('time').value),
                        touchPoint: {
                            x: parseFloat(document.getElementById('touchX').value),
                            y: parseFloat(document.getElementById('touchY').value),
                        },
                        resolution: {
                            x: canvas.width,
                            y: canvas.height,
                        },
                    },
                };
                
                ws.send(JSON.stringify({
                    type: 'render',
                    options: options,
                }));
            }, 50);
        }
        
        // Bind controls
        document.getElementById('time').addEventListener('input', requestRender);
        document.getElementById('touchX').addEventListener('input', requestRender);
        document.getElementById('touchY').addEventListener('input', requestRender);
        
        // Canvas setup
        function resizeCanvas() {
            const rect = canvas.getBoundingClientRect();
            canvas.width = rect.width * window.devicePixelRatio;
            canvas.height = rect.height * window.devicePixelRatio;
            requestRender();
        }
        
        window.addEventListener('resize', resizeCanvas);
        resizeCanvas();
    </script>
</body>
</html>
`;
  }
}