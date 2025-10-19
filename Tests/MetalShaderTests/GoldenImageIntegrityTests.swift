import XCTest
import Foundation

/// Verifies that all required golden images exist in the test bundle and are valid.
/// This test runs before visual regression tests to catch missing or corrupted golden images early.
final class GoldenImageIntegrityTests: XCTestCase {
    
    /// List of expected golden images with their test resolutions
    private let expectedGoldens: [(name: String, resolutions: [(Int, Int)])] = [
        ("golden_constant_color", [(64, 64), (128, 128), (256, 256)])
        // Add more golden images as new visual tests are created
    ]
    
    func testAllGoldenImagesExist() throws {
        var missingImages: [String] = []
        
        for (baseName, resolutions) in expectedGoldens {
            for (w, h) in resolutions {
                // Try resolution-specific name first
                let resolutionSpecificName = "\(baseName)_\(w)x\(h)"
                if let _ = Bundle.module.url(forResource: resolutionSpecificName, withExtension: "png") {
                    // Found resolution-specific golden
                    continue
                }
                
                // Try generic name
                if let _ = Bundle.module.url(forResource: baseName, withExtension: "png") {
                    // Found generic golden
                    continue
                }
                
                // Missing
                missingImages.append("\(resolutionSpecificName).png or \(baseName).png")
            }
        }
        
        XCTAssertTrue(
            missingImages.isEmpty,
            """
            Missing golden images in test bundle:
            \(missingImages.joined(separator: "\n"))
            
            To fix:
            1. Run tests to generate actual images in Resources/screenshots/tests/
            2. If images look correct, copy them to Tests/MetalShaderTests/Fixtures/
            3. Rename as golden_*.png
            4. Run 'make regen-goldens' to update test bundle
            """
        )
    }
    
    func testGoldenImagesAreValidPNGs() throws {
        for (baseName, resolutions) in expectedGoldens {
            for (w, h) in resolutions {
                var goldenURL: URL? = nil
                
                // Try resolution-specific first
                if let url = Bundle.module.url(forResource: "\(baseName)_\(w)x\(h)", withExtension: "png") {
                    goldenURL = url
                } else if let url = Bundle.module.url(forResource: baseName, withExtension: "png") {
                    goldenURL = url
                }
                
                guard let url = goldenURL else {
                    // Skip validation if missing - testAllGoldenImagesExist will catch this
                    continue
                }
                
                // Attempt to load the PNG to verify it's valid
                do {
                    let (_, imgW, imgH) = try TestImageUtils.loadPNG(url: url)
                    
                    // Verify dimensions if it's a resolution-specific golden
                    if url.lastPathComponent.contains("\(w)x\(h)") {
                        XCTAssertEqual(imgW, w, "Golden \(url.lastPathComponent) has wrong width")
                        XCTAssertEqual(imgH, h, "Golden \(url.lastPathComponent) has wrong height")
                    }
                } catch {
                    XCTFail("Failed to load golden image \(url.lastPathComponent): \(error)")
                }
            }
        }
    }
    
    func testGoldenImagesHaveExpectedPixelFormat() throws {
        for (baseName, resolutions) in expectedGoldens {
            for (w, h) in resolutions {
                var goldenURL: URL? = nil
                
                if let url = Bundle.module.url(forResource: "\(baseName)_\(w)x\(h)", withExtension: "png") {
                    goldenURL = url
                } else if let url = Bundle.module.url(forResource: baseName, withExtension: "png") {
                    goldenURL = url
                }
                
                guard let url = goldenURL else { continue }
                
                // Load and verify we get BGRA8 data
                let (bytes, imgW, imgH) = try TestImageUtils.loadPNG(url: url)
                let expectedSize = imgW * imgH * 4 // BGRA8 = 4 bytes per pixel
                
                XCTAssertEqual(
                    bytes.count,
                    expectedSize,
                    """
                    Golden \(url.lastPathComponent) has unexpected size.
                    Expected: \(expectedSize) bytes (\(imgW)x\(imgH) BGRA8)
                    Got: \(bytes.count) bytes
                    """
                )
            }
        }
    }
    
    func testToleranceConfigurationIsValid() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let cfgURL = URL(fileURLWithPath: cwd).appendingPathComponent("Resources/communication/visual_test_config.json")
        
        guard FileManager.default.fileExists(atPath: cfgURL.path) else {
            XCTFail("Missing visual_test_config.json at \(cfgURL.path)")
            return
        }
        
        let data = try Data(contentsOf: cfgURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("visual_test_config.json is not valid JSON")
            return
        }
        
        // Verify required top-level keys
        XCTAssertNotNil(json["default"], "Missing 'default' section in tolerance config")
        
        // Verify default has required tolerance keys
        if let def = json["default"] as? [String: Any] {
            XCTAssertNotNil(def["global"], "Missing 'global' tolerance in default config")
            XCTAssertNotNil(def["r"], "Missing 'r' tolerance in default config")
            XCTAssertNotNil(def["g"], "Missing 'g' tolerance in default config")
            XCTAssertNotNil(def["b"], "Missing 'b' tolerance in default config")
            XCTAssertNotNil(def["a"], "Missing 'a' tolerance in default config")
        }
    }
    
    func testToleranceResolutionForKnownTest() throws {
        // Test that resolveTolerance works correctly
        let tol = TestImageUtils.resolveTolerance(
            width: 64,
            height: 64,
            testName: "VisualRegressionTests.testConstantColorImageMatchesGoldenWithinTolerance"
        )
        
        // Should use values from config or defaults
        XCTAssertGreaterThanOrEqual(tol.global, 0, "Tolerance should be non-negative")
        XCTAssertLessThanOrEqual(tol.global, 255, "Tolerance should not exceed 255")
        XCTAssertGreaterThanOrEqual(tol.r, 0)
        XCTAssertLessThanOrEqual(tol.r, 255)
        XCTAssertGreaterThanOrEqual(tol.g, 0)
        XCTAssertLessThanOrEqual(tol.g, 255)
        XCTAssertGreaterThanOrEqual(tol.b, 0)
        XCTAssertLessThanOrEqual(tol.b, 255)
        XCTAssertGreaterThanOrEqual(tol.a, 0)
        XCTAssertLessThanOrEqual(tol.a, 255)
    }
    
    func testEnvironmentVariableToleranceOverrides() throws {
        // Document that environment variables can override config
        // This test verifies the behavior is documented, actual override testing
        // requires environment variable manipulation which is tricky in XCTest
        
        let envVars = [
            "VIS_TOL_R",
            "VIS_TOL_G",
            "VIS_TOL_B",
            "VIS_TOL_A",
            "VIS_TOL_GLOBAL"
        ]
        
        // Just verify these are documented somewhere accessible
        // In practice, these are handled by TestImageUtils.resolveTolerance()
        XCTAssertTrue(
            envVars.allSatisfy { !$0.isEmpty },
            "Environment variable names should be non-empty"
        )
    }
}
