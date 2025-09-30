// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MetalShaderMCP",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "MetalShaderStudio", targets: ["MetalShaderStudio"]),
        .library(name: "MetalShaderCore", targets: ["MetalShaderCore"])
    ],
    targets: [
        .target(
            name: "MetalShaderCore",
            path: "Sources/MetalShaderCore"
        ),
.executableTarget(
            name: "MetalShaderStudio",
            dependencies: ["MetalShaderCore"],
            path: "Apps/MetalShaderStudio",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Metal"),
                .linkedFramework("AppKit"),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedFramework("CoreML"),
                .linkedFramework("CoreVideo")
            ]
        ),
        .executableTarget(
            name: "ShaderRenderCLI",
            dependencies: ["MetalShaderCore"],
            path: "Tools/ShaderRenderCLI",
            linkerSettings: [
                .linkedFramework("MetalKit"),
                .linkedFramework("Metal"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO")
            ]
        ),
        .testTarget(
            name: "MetalShaderTests",
            dependencies: ["MetalShaderCore"],
            path: "Tests/MetalShaderTests",
            resources: [
                .process("Fixtures")
            ]
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["MetalShaderStudio"],
            path: "Tests/Integration",
            resources: [
                .copy("mock-mcp-server.js")
            ]
        )
    ]
)

