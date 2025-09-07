// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MetalShaderStudioMCP",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MetalShaderStudio", targets: ["MetalShaderStudio"])
    ],
    dependencies: [
        // No external dependencies needed - using only system frameworks
    ],
    targets: [
        .executableTarget(
            name: "MetalShaderStudio",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources"),
                .process("shaders")
            ]
        )
    ]
)
