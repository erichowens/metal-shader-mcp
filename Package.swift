// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MetalShaderMCP",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "MetalShaderCore", targets: ["MetalShaderCore"])
    ],
    targets: [
        .target(
            name: "MetalShaderCore",
            path: "Sources/MetalShaderCore"
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
    ]
)

