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
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("MetalKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "MetalShaderTests",
            dependencies: ["MetalShaderCore"],
            path: "Tests/MetalShaderTests"
        )
    ]
)

