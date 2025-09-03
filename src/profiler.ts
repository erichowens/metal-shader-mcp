/**
 * Performance Profiler for Metal Shaders
 * Measures GPU and CPU performance metrics
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';

const execAsync = promisify(exec);

export interface PerformanceMetrics {
  averageFrameTime: number;  // milliseconds
  fps: number;
  gpuTime: number;           // milliseconds
  cpuTime: number;           // milliseconds
  memoryUsage: number;       // bytes
  powerUsage: 'low' | 'medium' | 'high';
  threadCount: number;
  drawCalls: number;
  verticesProcessed: number;
  fragmentsProcessed: number;
}

export interface ProfileOptions {
  shaderPath: string;
  iterations: number;
  resolution: {
    width: number;
    height: number;
  };
  warmupIterations?: number;
}

export class PerformanceProfiler {
  private metricsHistory: Map<string, PerformanceMetrics[]> = new Map();
  
  /**
   * Profile shader performance
   */
  async profileShader(options: ProfileOptions): Promise<PerformanceMetrics> {
    const { 
      shaderPath, 
      iterations, 
      resolution, 
      warmupIterations = 10 
    } = options;
    
    // Create profiling program
    const profileProgram = this.generateProfileProgram(options);
    const tempDir = path.join(os.tmpdir(), 'metal-shader-profiler');
    await fs.mkdir(tempDir, { recursive: true });
    
    const programPath = path.join(tempDir, 'profiler.swift');
    const executablePath = path.join(tempDir, 'profiler');
    
    try {
      // Write and compile profiling program
      await fs.writeFile(programPath, profileProgram);
      
      const compileCmd = `swiftc -O -o ${executablePath} ${programPath}`;
      await execAsync(compileCmd);
      
      // Run profiler
      const runCmd = `${executablePath} ${shaderPath} ${iterations} ${resolution.width} ${resolution.height} ${warmupIterations}`;
      const { stdout } = await execAsync(runCmd);
      
      // Parse metrics
      const metrics = this.parseMetrics(stdout);
      
      // Store in history
      if (!this.metricsHistory.has(shaderPath)) {
        this.metricsHistory.set(shaderPath, []);
      }
      this.metricsHistory.get(shaderPath)!.push(metrics);
      
      // Cleanup
      await fs.rm(tempDir, { recursive: true, force: true });
      
      return metrics;
      
    } catch (error) {
      await fs.rm(tempDir, { recursive: true, force: true }).catch(() => {});
      throw error;
    }
  }
  
  /**
   * Run comparative benchmark between shaders
   */
  async compareShaders(
    shaderPaths: string[],
    options: Omit<ProfileOptions, 'shaderPath'>
  ): Promise<Map<string, PerformanceMetrics>> {
    const results = new Map<string, PerformanceMetrics>();
    
    for (const shaderPath of shaderPaths) {
      const metrics = await this.profileShader({
        ...options,
        shaderPath,
      });
      results.set(shaderPath, metrics);
    }
    
    return results;
  }
  
  /**
   * Get performance history for a shader
   */
  getHistory(shaderPath: string): PerformanceMetrics[] {
    return this.metricsHistory.get(shaderPath) || [];
  }
  
  /**
   * Generate performance report
   */
  generateReport(metrics: PerformanceMetrics): string {
    const report = [
      '═══════════════════════════════════════',
      '       PERFORMANCE PROFILING REPORT     ',
      '═══════════════════════════════════════',
      '',
      '📊 Frame Performance',
      `   Average Frame Time: ${metrics.averageFrameTime.toFixed(2)}ms`,
      `   Frames Per Second: ${metrics.fps.toFixed(1)} FPS`,
      `   ${this.getFPSRating(metrics.fps)}`,
      '',
      '⏱️  Processing Time',
      `   GPU Time: ${metrics.gpuTime.toFixed(2)}ms`,
      `   CPU Time: ${metrics.cpuTime.toFixed(2)}ms`,
      `   GPU/CPU Ratio: ${(metrics.gpuTime / metrics.cpuTime).toFixed(2)}x`,
      '',
      '💾 Resource Usage',
      `   Memory: ${(metrics.memoryUsage / 1024 / 1024).toFixed(1)}MB`,
      `   Power Usage: ${metrics.powerUsage}`,
      `   Thread Count: ${metrics.threadCount}`,
      '',
      '🎨 Rendering Stats',
      `   Draw Calls: ${metrics.drawCalls}`,
      `   Vertices: ${this.formatNumber(metrics.verticesProcessed)}`,
      `   Fragments: ${this.formatNumber(metrics.fragmentsProcessed)}`,
      '',
      '═══════════════════════════════════════',
    ];
    
    return report.join('\n');
  }
  
  /**
   * Generate Swift profiling program
   */
  private generateProfileProgram(options: ProfileOptions): string {
    return `
import Metal
import MetalKit
import QuartzCore
import Foundation

// Command line arguments
let args = CommandLine.arguments
guard args.count >= 6 else {
    print("Usage: profiler <shader.metallib> <iterations> <width> <height> <warmup>")
    exit(1)
}

let shaderPath = args[1]
let iterations = Int(args[2]) ?? 100
let width = Int(args[3]) ?? 512
let height = Int(args[4]) ?? 512
let warmupIterations = Int(args[5]) ?? 10

// Setup Metal
guard let device = MTLCreateSystemDefaultDevice() else {
    print("Metal is not supported")
    exit(1)
}

let commandQueue = device.makeCommandQueue()!

// Load shader library
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
textureDescriptor.storageMode = .private
let texture = device.makeTexture(descriptor: textureDescriptor)!

// Setup render pass
let renderPassDescriptor = MTLRenderPassDescriptor()
renderPassDescriptor.colorAttachments[0].texture = texture
renderPassDescriptor.colorAttachments[0].loadAction = .clear
renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
renderPassDescriptor.colorAttachments[0].storeAction = .store

// Uniforms
struct Uniforms {
    var time: Float = 0.0
    var resolution: SIMD2<Float> = SIMD2<Float>(Float(width), Float(height))
    var touchPoint: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
}

// Warmup
for _ in 0..<warmupIterations {
    var uniformData = Uniforms(time: Float.random(in: 0...1))
    let uniformBuffer = device.makeBuffer(bytes: &uniformData, length: MemoryLayout<Uniforms>.size, options: [])
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
    
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
    renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    renderEncoder.endEncoding()
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
}

// Profiling
var frameTimes: [TimeInterval] = []
var gpuTimes: [TimeInterval] = []
var cpuTimes: [TimeInterval] = []
let startMemory = getMemoryUsage()

for i in 0..<iterations {
    let frameStart = CACurrentMediaTime()
    let cpuStart = CACurrentMediaTime()
    
    var uniformData = Uniforms(time: Float(i) / Float(iterations))
    let uniformBuffer = device.makeBuffer(bytes: &uniformData, length: MemoryLayout<Uniforms>.size, options: [])
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    
    let cpuEnd = CACurrentMediaTime()
    cpuTimes.append((cpuEnd - cpuStart) * 1000)
    
    // GPU timing
    let gpuStart = CACurrentMediaTime()
    
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
    renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    renderEncoder.endEncoding()
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    let gpuEnd = CACurrentMediaTime()
    gpuTimes.append((gpuEnd - gpuStart) * 1000)
    
    let frameEnd = CACurrentMediaTime()
    frameTimes.append((frameEnd - frameStart) * 1000)
}

let endMemory = getMemoryUsage()

// Calculate metrics
let averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
let averageGPUTime = gpuTimes.reduce(0, +) / Double(gpuTimes.count)
let averageCPUTime = cpuTimes.reduce(0, +) / Double(cpuTimes.count)
let fps = 1000.0 / averageFrameTime
let memoryUsage = endMemory - startMemory

// Determine power usage based on frame time
let powerUsage: String
if averageFrameTime < 8.33 { // 120fps
    powerUsage = "high"
} else if averageFrameTime < 16.67 { // 60fps
    powerUsage = "medium"
} else {
    powerUsage = "low"
}

// Output metrics as JSON
let metrics: [String: Any] = [
    "averageFrameTime": averageFrameTime,
    "fps": fps,
    "gpuTime": averageGPUTime,
    "cpuTime": averageCPUTime,
    "memoryUsage": memoryUsage,
    "powerUsage": powerUsage,
    "threadCount": Thread.activeCount,
    "drawCalls": iterations,
    "verticesProcessed": 4 * iterations,
    "fragmentsProcessed": width * height * iterations
]

let jsonData = try! JSONSerialization.data(withJSONObject: metrics)
print(String(data: jsonData, encoding: .utf8)!)

// Helper function to get memory usage
func getMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
}

// Extension for thread count
extension Thread {
    static var activeCount: Int {
        return Thread.isMultiThreaded() ? ProcessInfo.processInfo.activeProcessorCount : 1
    }
}
`;
  }
  
  /**
   * Parse metrics from profiler output
   */
  private parseMetrics(output: string): PerformanceMetrics {
    try {
      const metrics = JSON.parse(output);
      return {
        averageFrameTime: metrics.averageFrameTime,
        fps: metrics.fps,
        gpuTime: metrics.gpuTime,
        cpuTime: metrics.cpuTime,
        memoryUsage: metrics.memoryUsage,
        powerUsage: metrics.powerUsage,
        threadCount: metrics.threadCount,
        drawCalls: metrics.drawCalls,
        verticesProcessed: metrics.verticesProcessed,
        fragmentsProcessed: metrics.fragmentsProcessed,
      };
    } catch (error) {
      throw new Error(`Failed to parse metrics: ${error}`);
    }
  }
  
  /**
   * Get FPS rating emoji
   */
  private getFPSRating(fps: number): string {
    if (fps >= 120) return '🚀 Blazing Fast (120+ FPS)';
    if (fps >= 60) return '✅ Smooth (60+ FPS)';
    if (fps >= 30) return '⚠️ Acceptable (30+ FPS)';
    return '❌ Poor Performance (<30 FPS)';
  }
  
  /**
   * Format large numbers
   */
  private formatNumber(num: number): string {
    if (num >= 1e9) return `${(num / 1e9).toFixed(1)}B`;
    if (num >= 1e6) return `${(num / 1e6).toFixed(1)}M`;
    if (num >= 1e3) return `${(num / 1e3).toFixed(1)}K`;
    return num.toString();
  }
}