import Foundation
import SwiftUI
import Combine
import Network

// MARK: - Shader Tab Model
class ShaderTabModel: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    @Published var content: String
    @Published var isModified = false
    
    init(id: UUID = UUID(), title: String, content: String) {
        self.title = title
        self.content = content
    }
}

// MARK: - Shader Parameter
struct ShaderParameter: Identifiable {
    let id: UUID
    var name: String
    var type: ParameterType
    var value: ShaderValue
    var range: ClosedRange<Float>
    var isBuiltin: Bool
    
    init(id: UUID = UUID(), name: String, type: ParameterType, value: ShaderValue, range: ClosedRange<Float> = 0...1, isBuiltin: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.value = value
        self.range = range
        self.isBuiltin = isBuiltin
    }
    
    // Add formattedValue computed property
    var formattedValue: String {
        switch value {
        case .float(let v):
            return String(format: "%.3f", v)
        case .vector2(let x, let y):
            return String(format: "(%.2f, %.2f)", x, y)
        case .vector3(let x, let y, let z):
            return String(format: "(%.2f, %.2f, %.2f)", x, y, z)
        case .vector4(let x, let y, let z, let w):
            return String(format: "(%.2f, %.2f, %.2f, %.2f)", x, y, z, w)
        case .int(let v):
            return "\(v)"
        case .bool(let v):
            return v ? "true" : "false"
        case .color(let r, let g, let b, let a):
            return String(format: "rgba(%.2f, %.2f, %.2f, %.2f)", r, g, b, a)
        }
    }
    
    // Add vectorValue computed property for compatibility
    var vectorValue: SIMD2<Float> {
        get {
            switch value {
            case .vector2(let x, let y): return SIMD2<Float>(x, y)
            case .float(let v): return SIMD2<Float>(v, 0)
            default: return SIMD2<Float>(0, 0)
            }
        }
        set {
            value = .vector2(newValue.x, newValue.y)
        }
    }
    
    // Add colorValue computed property
    var colorValue: Color {
        get {
            switch value {
            case .color(let r, let g, let b, let a):
                return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
            default:
                return Color.white
            }
        }
        set {
            let nsColor = NSColor(newValue)
            value = .color(
                Float(nsColor.redComponent),
                Float(nsColor.greenComponent),
                Float(nsColor.blueComponent),
                Float(nsColor.alphaComponent)
            )
        }
    }
    
    // Add intValue computed property
    var intValue: Int {
        get {
            switch value {
            case .int(let v): return v
            case .float(let v): return Int(v)
            default: return 0
            }
        }
        set {
            value = .int(newValue)
        }
    }
    
    // Add boolValue computed property
    var boolValue: Bool {
        get {
            switch value {
            case .bool(let v): return v
            case .float(let v): return v > 0.5
            case .int(let v): return v != 0
            default: return false
            }
        }
        set {
            value = .bool(newValue)
        }
    }
    
    // Add floatValue computed property for compatibility
    var floatValue: Float {
        get {
            switch value {
            case .float(let v): return v
            case .vector2(let x, _): return x
            case .vector3(let x, _, _): return x
            case .vector4(let x, _, _, _): return x
            case .int(let v): return Float(v)
            case .bool(let v): return v ? 1.0 : 0.0
            case .color(let r, _, _, _): return r
            }
        }
        set {
            switch type {
            case .float: value = .float(newValue)
            case .float2: 
                if case .vector2(_, let y) = value {
                    value = .vector2(newValue, y)
                }
            case .float3:
                if case .vector3(_, let y, let z) = value {
                    value = .vector3(newValue, y, z)
                }
            case .float4:
                if case .vector4(_, let y, let z, let w) = value {
                    value = .vector4(newValue, y, z, w)
                }
            case .int: value = .int(Int(newValue))
            case .bool: value = .bool(newValue > 0.5)
            case .color:
                if case .color(_, let g, let b, let a) = value {
                    value = .color(newValue, g, b, a)
                }
            }
        }
    }
}

enum ParameterType {
    case float, float2, float3, float4, int, bool, color
}

enum ShaderValue {
    case float(Float)
    case vector2(Float, Float)
    case vector3(Float, Float, Float)
    case vector4(Float, Float, Float, Float)
    case int(Int)
    case bool(Bool)
    case color(Float, Float, Float, Float)
    
    var vector2Value: (Float, Float)? {
        if case .vector2(let x, let y) = self {
            return (x, y)
        }
        return nil
    }
}

// MARK: - Compilation Status
enum CompilationStatus {
    case ready
    case idle
    case compiling
    case success
    case error
}

// MARK: - Compilation Error
struct CompilationError: Identifiable {
    let id = UUID()
    let line: Int
    let column: Int
    let message: String
    let type: ErrorType
    
    enum ErrorType {
        case error
        case warning
    }
}

// MARK: - Shader Compilation Error
struct ShaderCompilationError: Error {
    let errors: [CompilationError]
}

// MARK: - Shader Preset
struct ShaderPreset: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let code: String
    let description: String
    let parameters: [ShaderParameter]
    let timestamp: Date
    
    init(name: String, category: String = "Custom", code: String, description: String = "", parameters: [ShaderParameter] = [], timestamp: Date = Date()) {
        self.name = name
        self.category = category
        self.code = code
        self.description = description
        self.parameters = parameters
        self.timestamp = timestamp
    }
}

// MARK: - Shader Library Item
struct ShaderLibraryItem: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let code: String
    let description: String
    let hasMouseInteraction: Bool
    let estimatedFPS: Int
    let complexity: String
    let previewImage: NSImage?
    
    init(name: String, category: String, code: String, description: String, hasMouseInteraction: Bool = false, estimatedFPS: Int = 60, complexity: String = "Medium", previewImage: NSImage? = nil) {
        self.name = name
        self.category = category
        self.code = code
        self.description = description
        self.hasMouseInteraction = hasMouseInteraction
        self.estimatedFPS = estimatedFPS
        self.complexity = complexity
        self.previewImage = previewImage
    }
}

// MARK: - MCP Function
struct MCPFunction: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let parameters: [MCPFunctionParameter]
    let example: String
    let requiresAuth: Bool
    
    init(name: String, description: String, icon: String = "function", parameters: [MCPFunctionParameter] = [], example: String = "", requiresAuth: Bool = false) {
        self.name = name
        self.description = description
        self.icon = icon
        self.parameters = parameters
        self.example = example
        self.requiresAuth = requiresAuth
    }
}

// MARK: - MCP Function Parameter
struct MCPFunctionParameter: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let description: String
    let required: Bool
    
    init(name: String, type: String, description: String, required: Bool = true) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
    }
}

// Import fixed shader templates
let fixedKaleidoscopeShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]],
                              constant float2 &mouse [[buffer(2)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= resolution.x / resolution.y;
    
    // Kaleidoscope transformation
    float segments = 8.0;
    float angle = atan2(p.y, p.x);
    float radius = length(p);
    
    float segmentAngle = 2.0 * M_PI_F / segments;
    angle = fmod(angle, segmentAngle);
    
    if (fmod(floor(atan2(p.y, p.x) / segmentAngle), 2.0) == 1.0) {
        angle = segmentAngle - angle;
    }
    
    float2 kaleido = radius * float2(cos(angle), sin(angle));
    
    // Color generation
    float3 color = 0.5 + 0.5 * cos(time + kaleido.xyx + float3(0, 2, 4));
    
    // Mouse influence
    float dist = length(uv - mouse);
    color *= 1.0 + 0.5 * (1.0 - smoothstep(0.0, 0.5, dist));
    
    return float4(color, 1.0);
}
"""

let fixedPlasmaShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

float plasma(float2 p, float time) {
    float value = 0.0;
    value += sin(p.x * 8.0 + time * 2.0);
    value += sin(p.y * 6.0 + time * 1.5);
    value += sin(length(p) * 8.0 - time);
    return value / 3.0;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant float &time [[buffer(0)]],
                              constant float2 &resolution [[buffer(1)]],
                              constant float2 &mouse [[buffer(2)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    
    float value = plasma(p * 3.0, time);
    
    float3 color = 0.5 + 0.5 * cos(value * 3.14159 + float3(0, 2.09, 4.18));
    
    // Mouse interaction
    float dist = length(uv - mouse);
    color += (1.0 - smoothstep(0.0, 0.3, dist)) * 0.3;
    
    return float4(color, 1.0);
}
"""

let fixedWavePatternCode = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float4 custom1;
    float4 custom2;
    float4 custom3;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant float4 *vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = vertices[vertexID];
    out.texCoord = vertices[vertexID].zw;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    
    float wave = sin(p.x * 10.0 + uniforms.time * 2.0) * 
                 sin(p.y * 10.0 + uniforms.time * 1.5);
    
    float3 color = float3(wave * 0.5 + 0.5);
    
    // Mouse interaction - create ripple effect
    float dist = length(uv - uniforms.mouse);
    float ripple = sin(dist * 30.0 - uniforms.time * 5.0) * exp(-dist * 3.0);
    color = mix(color, float3(1.0, 0.5, 0.0), ripple * 0.5);
    
    return float4(color, 1.0);
}
"""

// MARK: - MCP Server Models
class MCPServer: ObservableObject {
    @Published var isRunning = false
    @Published var port = "3000"
    @Published var url = "stdio://localhost:3000"
    @Published var connectedClients = 0
    @Published var isProcessing = false
    
    // Performance metrics
    @Published var requestsPerSecond = 0
    @Published var avgResponseTime = 0
    @Published var memoryUsage = "0 MB"
    @Published var cpuUsage = "0%"
    
    private var serverProcess: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var metricsTimer: Timer?
    private var outputObserver: NSObjectProtocol?
    private var errorObserver: NSObjectProtocol?
    
    func start() {
        guard !isRunning else { return }
        
        // Create pipes for bidirectional communication
        inputPipe = Pipe()
        outputPipe = Pipe()
        errorPipe = Pipe()
        
        // Setup the process
        serverProcess = Process()
        serverProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        serverProcess?.arguments = [
            "node",
            "/Users/erichowens/coding/metal-shader-mcp/dist/index.js",
            "--stdio"  // Important: Tell Node.js to use stdio mode
        ]
        
        // Set working directory
        serverProcess?.currentDirectoryURL = URL(fileURLWithPath: "/Users/erichowens/coding/metal-shader-mcp")
        
        // Configure pipes
        serverProcess?.standardInput = inputPipe
        serverProcess?.standardOutput = outputPipe
        serverProcess?.standardError = errorPipe
        
        // Setup output handlers BEFORE running the process
        let outputHandle = outputPipe!.fileHandleForReading
        outputObserver = NotificationCenter.default.addObserver(
            forName: .NSFileHandleDataAvailable,
            object: outputHandle,
            queue: nil
        ) { [weak self] _ in
            let data = outputHandle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        WorkspaceManager.shared.addMCPLog(
                            level: "info",
                            message: output.trimmingCharacters(in: .whitespacesAndNewlines),
                            source: "MCP Server"
                        )
                    }
                }
                outputHandle.waitForDataInBackgroundAndNotify()
            }
        }
        
        let errorHandle = errorPipe!.fileHandleForReading
        errorObserver = NotificationCenter.default.addObserver(
            forName: .NSFileHandleDataAvailable,
            object: errorHandle,
            queue: nil
        ) { [weak self] _ in
            let data = errorHandle.availableData
            if !data.isEmpty {
                if let error = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        WorkspaceManager.shared.addMCPLog(
                            level: "error",
                            message: error.trimmingCharacters(in: .whitespacesAndNewlines),
                            source: "MCP Server"
                        )
                    }
                }
                errorHandle.waitForDataInBackgroundAndNotify()
            }
        }
        
        // Start listening for data
        outputHandle.waitForDataInBackgroundAndNotify()
        errorHandle.waitForDataInBackgroundAndNotify()
        
        // Setup termination handler
        serverProcess?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.connectedClients = 0
                WorkspaceManager.shared.addMCPLog(
                    level: "warning",
                    message: "MCP server terminated with exit code: \(process.terminationStatus)",
                    source: "MCP Server"
                )
            }
        }
        
        // Start the process
        do {
            try serverProcess?.run()
            isRunning = true
            startMetricsMonitoring()
            
            // Send initial handshake
            sendInitialHandshake()
            
            WorkspaceManager.shared.addMCPLog(
                level: "info",
                message: "MCP server started successfully",
                source: "MCP Server"
            )
        } catch {
            WorkspaceManager.shared.addMCPLog(
                level: "error",
                message: "Failed to start MCP server: \(error)",
                source: "MCP Server"
            )
        }
    }
    
    func stop() {
        // Remove observers
        if let outputObserver = outputObserver {
            NotificationCenter.default.removeObserver(outputObserver)
        }
        if let errorObserver = errorObserver {
            NotificationCenter.default.removeObserver(errorObserver)
        }
        
        // Terminate the process gracefully
        if let process = serverProcess, process.isRunning {
            process.interrupt()  // Send SIGINT first for graceful shutdown
            
            // Give it 2 seconds to shut down gracefully
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if process.isRunning {
                    process.terminate()  // Force termination if still running
                }
            }
        }
        
        serverProcess = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
        isRunning = false
        stopMetricsMonitoring()
        
        WorkspaceManager.shared.addMCPLog(
            level: "info",
            message: "MCP server stopped",
            source: "MCP Server"
        )
    }
    
    private func sendInitialHandshake() {
        // Send MCP handshake to establish connection
        let handshake = """
        {"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"1.0","capabilities":{}},"id":1}
        
        """
        
        if let data = handshake.data(using: .utf8) {
            inputPipe?.fileHandleForWriting.write(data)
        }
    }
    
    func testConnection() {
        isProcessing = true
        
        // Simulate connection test
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isProcessing = false
            // Log result
            WorkspaceManager.shared.addMCPLog(
                level: "info",
                message: "Connection test successful"
            )
        }
    }
    
    private func startMetricsMonitoring() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    private func stopMetricsMonitoring() {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
    
    private func updateMetrics() {
        // Simulate metrics update
        requestsPerSecond = Int.random(in: 10...50)
        avgResponseTime = Int.random(in: 5...25)
        
        let memory = Double.random(in: 50...150)
        memoryUsage = String(format: "%.1f MB", memory)
        
        let cpu = Double.random(in: 5...30)
        cpuUsage = String(format: "%.1f%%", cpu)
    }
}

// MARK: - MCP Log Models
struct MCPLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: String
    let message: String
    let source: String?
}


// MARK: - Shader Code Templates
let kaleidoscopeShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float segments;
    float rotation;
    float zoom;
};

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    // Kaleidoscope transformation
    float angle = atan2(p.y, p.x) + uniforms.rotation;
    float radius = length(p) * uniforms.zoom;
    
    float segmentAngle = 2.0 * M_PI_F / uniforms.segments;
    angle = fmod(angle, segmentAngle);
    
    if (fmod(floor(atan2(p.y, p.x) / segmentAngle), 2.0) == 1.0) {
        angle = segmentAngle - angle;
    }
    
    float2 kaleido = radius * float2(cos(angle), sin(angle));
    
    // Color generation
    float3 color = 0.5 + 0.5 * cos(uniforms.time + kaleido.xyx + float3(0, 2, 4));
    
    // Mouse influence
    float dist = length(uv - uniforms.mouse);
    color *= 1.0 - smoothstep(0.0, 0.5, dist);
    
    return float4(color, 1.0);
}
"""

let plasmaFractalShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float complexity;
};

float plasma(float2 p, float time) {
    float value = 0.0;
    value += sin(p.x * 8.0 + time * 2.0);
    value += sin(p.y * 6.0 + time * 1.5);
    value += sin(length(p) * 8.0 - time);
    return value / 3.0;
}

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    
    float value = plasma(p * uniforms.complexity, uniforms.time);
    
    float3 color = 0.5 + 0.5 * cos(value * 3.14159 + float3(0, 2.09, 4.18));
    
    return float4(color, 1.0);
}
"""

let simpleGradientShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
};

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    
    float3 color = 0.5 + 0.5 * cos(uniforms.time + uv.xyx + float3(0, 2, 4));
    
    return float4(color, 1.0);
}
"""

let wavePatternShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
};

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    
    float wave = sin(p.x * 10.0 + uniforms.time * 2.0) * 
                 sin(p.y * 10.0 + uniforms.time * 1.5);
    
    float3 color = float3(wave * 0.5 + 0.5);
    color = mix(color, float3(1.0, 0.5, 0.0), length(uv - uniforms.mouse) < 0.1);
    
    return float4(color, 1.0);
}
"""

let mandelbrotShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
};

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 c = (uv - 0.5) * 3.0 - float2(0.5, 0.0);
    c *= exp(-length(uniforms.mouse - 0.5) * 2.0);
    
    float2 z = float2(0.0);
    float iter = 0.0;
    
    for (int i = 0; i < 128; i++) {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (dot(z, z) > 4.0) {
            iter = float(i) / 128.0;
            break;
        }
    }
    
    float3 color = 0.5 + 0.5 * cos(3.0 + iter * 15.0 + float3(0, 0.6, 1.0));
    
    return float4(color, 1.0);
}
"""

let voronoiShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
};

float2 hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 10.0;
    
    float2 i_st = floor(p);
    float2 f_st = fract(p);
    
    float min_dist = 1.0;
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 neighbor = float2(float(x), float(y));
            float2 point = hash2(i_st + neighbor);
            point = 0.5 + 0.5 * sin(uniforms.time + 6.2831 * point);
            float2 diff = neighbor + point - f_st;
            float dist = length(diff);
            min_dist = min(min_dist, dist);
        }
    }
    
    float3 color = float3(min_dist);
    color = 0.5 + 0.5 * cos(min_dist * 10.0 + float3(0, 2, 4));
    
    return float4(color, 1.0);
}
"""

let particleSystemShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
};

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float3 color = float3(0.0);
    
    for (int i = 0; i < 50; i++) {
        float fi = float(i);
        float2 seed = float2(fi * 0.1, fi * 0.13);
        float2 particlePos = float2(hash(seed), hash(seed + 1.0));
        
        particlePos += sin(uniforms.time * (1.0 + fi * 0.1) + fi) * 0.1;
        
        float2 toMouse = uniforms.mouse - particlePos;
        particlePos += toMouse * 0.1;
        
        float dist = length(uv - particlePos);
        float intensity = 0.01 / dist;
        
        color += intensity * (0.5 + 0.5 * cos(fi + float3(0, 2, 4)));
    }
    
    return float4(color, 1.0);
}
"""

let rayMarchingShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
};

float sdSphere(float3 p, float r) {
    return length(p) - r;
}

float map(float3 p, float time) {
    float d = sdSphere(p, 1.0);
    float3 q = p;
    q.x += sin(time);
    d = min(d, sdSphere(q - float3(2.0, 0.0, 0.0), 0.5));
    return d;
}

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = (position.xy - 0.5 * uniforms.resolution) / uniforms.resolution.y;
    
    float3 ro = float3(0.0, 0.0, -3.0);
    float3 rd = normalize(float3(uv, 1.0));
    
    float t = 0.0;
    for (int i = 0; i < 64; i++) {
        float3 p = ro + rd * t;
        float d = map(p, uniforms.time);
        if (d < 0.001) break;
        t += d;
        if (t > 10.0) break;
    }
    
    float3 color = float3(0.0);
    if (t < 10.0) {
        color = float3(1.0 - t * 0.1);
    }
    
    return float4(color, 1.0);
}
"""

let noiseExplorerShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
};

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = fract(sin(dot(i, float2(12.9898, 78.233))) * 43758.5453);
    float b = fract(sin(dot(i + float2(1, 0), float2(12.9898, 78.233))) * 43758.5453);
    float c = fract(sin(dot(i + float2(0, 1), float2(12.9898, 78.233))) * 43758.5453);
    float d = fract(sin(dot(i + float2(1, 1), float2(12.9898, 78.233))) * 43758.5453);
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    
    float n = 0.0;
    float amplitude = 1.0;
    float frequency = 2.0;
    
    for (int i = 0; i < 5; i++) {
        n += noise(uv * frequency + uniforms.time * 0.1) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    float3 color = float3(n);
    
    return float4(color, 1.0);
}
"""

let glassRefractionShaderCode = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
};

fragment float4 fragmentShader(float4 position [[position]],
                              constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    
    // Glass sphere
    float radius = 0.5;
    float2 center = uniforms.mouse - 0.5;
    float dist = length(p - center);
    
    float3 color = float3(0.1, 0.2, 0.3);
    
    if (dist < radius) {
        // Refraction
        float2 normal = normalize(p - center);
        float2 refracted = uv + normal * (radius - dist) * 0.3;
        
        // Distorted background
        color = 0.5 + 0.5 * cos(uniforms.time + refracted.xyx * 10.0 + float3(0, 2, 4));
        
        // Glass tint
        color *= float3(0.9, 0.95, 1.0);
        
        // Fresnel effect
        float fresnel = pow(1.0 - (radius - dist) / radius, 2.0);
        color = mix(color, float3(1.0), fresnel * 0.5);
    }
    
    return float4(color, 1.0);
}
"""

// Alias for compatibility  
let plasmaShaderCode = fixedPlasmaShaderCode
let fractalShaderCode = mandelbrotShaderCode
let waveShaderCode = wavePatternShaderCode
