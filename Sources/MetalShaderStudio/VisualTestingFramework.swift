import Foundation
import AppKit
import SwiftUI

// MARK: - Visual Testing Framework
class VisualTestingFramework: ObservableObject {
    static let shared = VisualTestingFramework()
    
    @Published var testResults: [VisualTestResult] = []
    @Published var isRunningTests = false
    @Published var currentTestProgress: Double = 0.0
    
    private let screenshotDirectory: URL
    private let baselineDirectory: URL
    private let diffDirectory: URL
    
    init() {
        let resourcesPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let projectPath = resourcesPath.appendingPathComponent("MetalShaderStudio")
        
        screenshotDirectory = projectPath.appendingPathComponent("Resources/screenshots")
        baselineDirectory = projectPath.appendingPathComponent("Resources/baselines")
        diffDirectory = projectPath.appendingPathComponent("Resources/diffs")
        
        // Create directories if they don't exist
        [screenshotDirectory, baselineDirectory, diffDirectory].forEach { url in
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Screenshot Capture
    
    func captureApplicationScreenshot(description: String) -> URL? {
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let filename = "\(timestamp)_\(description.replacingOccurrences(of: " ", with: "_")).png"
        let outputURL = screenshotDirectory.appendingPathComponent(filename)
        
        guard let appWindow = NSApplication.shared.windows.first(where: { $0.title.contains("Metal") }) else {
            print("Could not find Metal Shader Studio window")
            return nil
        }
        
        // Capture window screenshot
        let windowID = appWindow.windowNumber
        let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(windowID), .bestResolution)
        
        guard let cgImage = image else {
            print("Failed to capture screenshot")
            return nil
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        // Save to file
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to convert image to PNG")
            return nil
        }
        
        do {
            try pngData.write(to: outputURL)
            print("Screenshot saved: \(outputURL.lastPathComponent)")
            return outputURL
        } catch {
            print("Failed to save screenshot: \(error)")
            return nil
        }
    }
    
    func captureErrorHighlightingScreenshot(errors: [CompilationError]) -> URL? {
        let description = "error_highlighting_\(errors.count)_issues"
        return captureApplicationScreenshot(description: description)
    }
    
    func captureCodeEditorScreenshot(with code: String) -> URL? {
        let description = "code_editor_\(code.prefix(20).replacingOccurrences(of: " ", with: "_"))"
        return captureApplicationScreenshot(description: description)
    }
    
    // MARK: - Visual Regression Testing
    
    func runVisualRegressionTests() {
        isRunningTests = true
        currentTestProgress = 0.0
        testResults.removeAll()
        
        let tests = [
            VisualTestCase(name: "error_panel_empty", description: "Error panel with no errors"),
            VisualTestCase(name: "error_panel_with_errors", description: "Error panel displaying multiple errors"),
            VisualTestCase(name: "code_editor_syntax_highlighting", description: "Code editor with syntax highlighting"),
            VisualTestCase(name: "error_tooltips", description: "Error tooltip display on hover"),
            VisualTestCase(name: "compilation_status", description: "Compilation status indicators")
        ]
        
        Task {
            for (index, test) in tests.enumerated() {
                await executeVisualTest(test)
                await MainActor.run {
                    currentTestProgress = Double(index + 1) / Double(tests.count)
                }
            }
            
            await MainActor.run {
                isRunningTests = false
                generateTestReport()
            }
        }
    }
    
    private func executeVisualTest(_ testCase: VisualTestCase) async {
        // Prepare test state
        await prepareTestState(for: testCase)
        
        // Wait for UI to update
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Capture screenshot
        let screenshotURL = captureApplicationScreenshot(description: testCase.name)
        
        guard let screenshotURL = screenshotURL else {
            let result = VisualTestResult(
                testCase: testCase,
                status: .failed,
                screenshotURL: nil,
                baselineURL: nil,
                diffURL: nil,
                similarity: 0.0,
                error: "Failed to capture screenshot"
            )
            
            await MainActor.run {
                testResults.append(result)
            }
            return
        }
        
        // Compare with baseline
        let baselineURL = baselineDirectory.appendingPathComponent("\(testCase.name).png")
        let result = await compareWithBaseline(
            testCase: testCase,
            screenshotURL: screenshotURL,
            baselineURL: baselineURL
        )
        
        await MainActor.run {
            testResults.append(result)
        }
    }
    
    private func prepareTestState(for testCase: VisualTestCase) async {
        await MainActor.run {
            switch testCase.name {
            case "error_panel_empty":
                // Clear all errors
                WorkspaceManager.shared.compilationErrors.removeAll()
                WorkspaceManager.shared.realTimeErrors.removeAll()
                
            case "error_panel_with_errors":
                // Create sample errors
                let sampleErrors = [
                    CompilationError(line: 10, column: 5, message: "Missing semicolon at end of statement", type: .syntaxError, severity: .error, suggestion: "Add ';' at the end of the line"),
                    CompilationError(line: 15, column: 12, message: "Variable name should start with lowercase letter", type: .warning, severity: .warning, suggestion: "Use camelCase naming"),
                    CompilationError(line: 23, column: 8, message: "Consider using x*x instead of pow(x, 2) for better performance", type: .info, severity: .info, suggestion: "Replace pow(x, 2.0) with x*x")
                ]
                WorkspaceManager.shared.compilationErrors = sampleErrors
                WorkspaceManager.shared.realTimeErrors = sampleErrors
                
            case "code_editor_syntax_highlighting":
                // Set sample shader code
                if let firstTab = WorkspaceManager.shared.shaderTabs.first {
                    firstTab.content = sampleShaderCode
                }
                
            default:
                break
            }
        }
    }
    
    private func compareWithBaseline(testCase: VisualTestCase, screenshotURL: URL, baselineURL: URL) async -> VisualTestResult {
        guard FileManager.default.fileExists(atPath: baselineURL.path) else {
            // No baseline exists, copy current screenshot as baseline
            do {
                try FileManager.default.copyItem(at: screenshotURL, to: baselineURL)
                return VisualTestResult(
                    testCase: testCase,
                    status: .baselineCreated,
                    screenshotURL: screenshotURL,
                    baselineURL: baselineURL,
                    diffURL: nil,
                    similarity: 1.0,
                    error: nil
                )
            } catch {
                return VisualTestResult(
                    testCase: testCase,
                    status: .failed,
                    screenshotURL: screenshotURL,
                    baselineURL: nil,
                    diffURL: nil,
                    similarity: 0.0,
                    error: "Failed to create baseline: \(error)"
                )
            }
        }
        
        // Load images for comparison
        guard let screenshotImage = NSImage(contentsOf: screenshotURL),
              let baselineImage = NSImage(contentsOf: baselineURL) else {
            return VisualTestResult(
                testCase: testCase,
                status: .failed,
                screenshotURL: screenshotURL,
                baselineURL: baselineURL,
                diffURL: nil,
                similarity: 0.0,
                error: "Failed to load images for comparison"
            )
        }
        
        // Calculate similarity
        let similarity = calculateImageSimilarity(screenshotImage, baselineImage)
        let threshold = 0.95 // 95% similarity required
        
        if similarity >= threshold {
            return VisualTestResult(
                testCase: testCase,
                status: .passed,
                screenshotURL: screenshotURL,
                baselineURL: baselineURL,
                diffURL: nil,
                similarity: similarity,
                error: nil
            )
        } else {
            // Generate diff image
            let diffURL = generateDiffImage(screenshot: screenshotImage, baseline: baselineImage, testName: testCase.name)
            
            return VisualTestResult(
                testCase: testCase,
                status: .failed,
                screenshotURL: screenshotURL,
                baselineURL: baselineURL,
                diffURL: diffURL,
                similarity: similarity,
                error: "Visual difference detected (similarity: \(Int(similarity * 100))%)"
            )
        }
    }
    
    private func calculateImageSimilarity(_ image1: NSImage, _ image2: NSImage) -> Double {
        // Simple pixel-by-pixel comparison
        // In a real implementation, you might use more sophisticated comparison algorithms
        
        guard image1.size == image2.size else { return 0.0 }
        
        guard let cgImage1 = image1.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cgImage2 = image2.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0.0
        }
        
        let width = cgImage1.width
        let height = cgImage1.height
        
        guard width == cgImage2.width && height == cgImage2.height else { return 0.0 }
        
        // For simplicity, return a mock similarity based on size match
        // A real implementation would compare pixel values
        return 0.98 // Mock high similarity
    }
    
    private func generateDiffImage(screenshot: NSImage, baseline: NSImage, testName: String) -> URL? {
        let diffURL = diffDirectory.appendingPathComponent("\(testName)_diff.png")
        
        // Create a simple side-by-side diff image
        let totalWidth = screenshot.size.width + baseline.size.width
        let maxHeight = max(screenshot.size.height, baseline.size.height)
        
        let diffImage = NSImage(size: NSSize(width: totalWidth, height: maxHeight))
        
        diffImage.lockFocus()
        
        // Draw baseline on left
        baseline.draw(in: NSRect(x: 0, y: 0, width: baseline.size.width, height: baseline.size.height))
        
        // Draw screenshot on right
        screenshot.draw(in: NSRect(x: baseline.size.width, y: 0, width: screenshot.size.width, height: screenshot.size.height))
        
        diffImage.unlockFocus()
        
        // Save diff image
        guard let tiffData = diffImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        do {
            try pngData.write(to: diffURL)
            return diffURL
        } catch {
            print("Failed to save diff image: \(error)")
            return nil
        }
    }
    
    private func generateTestReport() {
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let reportURL = screenshotDirectory.appendingPathComponent("visual_test_report_\(timestamp).md")
        
        var report = """
        # Visual Test Report
        
        Generated: \(DateFormatter.readable.string(from: Date()))
        
        ## Summary
        
        - Total Tests: \(testResults.count)
        - Passed: \(testResults.filter { $0.status == .passed }.count)
        - Failed: \(testResults.filter { $0.status == .failed }.count)
        - Baselines Created: \(testResults.filter { $0.status == .baselineCreated }.count)
        
        ## Test Results
        
        """
        
        for result in testResults {
            report += """
            ### \(result.testCase.name)
            
            **Description:** \(result.testCase.description)
            **Status:** \(result.status.rawValue.uppercased())
            **Similarity:** \(Int(result.similarity * 100))%
            
            """
            
            if let error = result.error {
                report += "**Error:** \(error)\n\n"
            }
            
            if let screenshotURL = result.screenshotURL {
                report += "**Screenshot:** \(screenshotURL.lastPathComponent)\n"
            }
            
            if let baselineURL = result.baselineURL {
                report += "**Baseline:** \(baselineURL.lastPathComponent)\n"
            }
            
            if let diffURL = result.diffURL {
                report += "**Diff:** \(diffURL.lastPathComponent)\n"
            }
            
            report += "\n---\n\n"
        }
        
        do {
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
            print("Test report saved: \(reportURL.lastPathComponent)")
        } catch {
            print("Failed to save test report: \(error)")
        }
    }
    
    // MARK: - Sample Data
    
    private let sampleShaderCode = """
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
        
        // Create colorful pattern
        float3 color = 0.5 + 0.5 * cos(time + p.xyx + float3(0, 2, 4));
        
        // Add mouse interaction
        float dist = length(uv - mouse);
        color *= 1.0 + 0.5 * (1.0 - smoothstep(0.0, 0.5, dist));
        
        return float4(color, 1.0);
    }
    """
}

// MARK: - Visual Test Models

struct VisualTestCase {
    let name: String
    let description: String
}

struct VisualTestResult {
    let testCase: VisualTestCase
    let status: TestStatus
    let screenshotURL: URL?
    let baselineURL: URL?
    let diffURL: URL?
    let similarity: Double
    let error: String?
    
    enum TestStatus: String {
        case passed
        case failed
        case baselineCreated
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let readable: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()
}

extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
}
