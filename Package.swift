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
            path: ".",
            sources: [
                "ShaderPlayground.swift",
                "AppShellView.swift",
                "HistoryTabView.swift",
                "SessionRecorder.swift"
            ],
            exclude: [
                ".git",
                ".github",
                ".claude",
                "node_modules",
                "dist",
                "build",
                "docs",
                "scripts",
                "src",
                "shaders",
                "Tests",
                "Resources/exports",
                "Resources/screenshots",
                "Resources/sessions",
                "Resources/communication",
                "Resources/Assets.xcassets",
                "TestApp.xcodeproj",
                "MetalShaderStudioMCP.xcodeproj",
                "ShaderPlayground",
                "MetalStudioMCPFixed",
                "project.yml",
                "project_basic.yml",
                "project_min.yml",
                "compile.sh",
                "jest.config.cjs",
                "tsconfig.json",
                "package.json",
                "package-lock.json"
            ],
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
            path: "Tests/MetalShaderTests"
        )
    ]
)

