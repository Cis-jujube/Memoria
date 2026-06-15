// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Memorial",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MemoriaCore", targets: ["MemoriaCore"]),
        .executable(name: "Memorial", targets: ["MemoriaMac"])
    ],
    targets: [
        .target(
            name: "MemoriaCore",
            path: "Sources/MemoriaMac",
            exclude: [
                "App",
                "Views",
                "Support"
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "MemoriaMac",
            dependencies: ["MemoriaCore"],
            path: "Sources/MemoriaMac",
            exclude: [
                "Models",
                "Stores",
                "Persistence",
                "Services"
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "MemoriaProtocolChecks",
            dependencies: ["MemoriaCore"],
            path: "Tests",
            sources: [
                "MemoriaProtocolChecks/main.swift"
            ],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
