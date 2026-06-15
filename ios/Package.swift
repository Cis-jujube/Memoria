// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MemoriaIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MemoriaIOS", targets: ["MemoriaIOS"])
    ],
    targets: [
        .target(
            name: "MemoriaIOS",
            path: "Memoria",
            exclude: ["MemoriaApp.swift"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
