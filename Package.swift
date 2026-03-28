// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting]? = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "ft-swift",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11)],
    products: [
        // Libraries
        .library(name: "FlaschenTaschenServerKit", targets: ["FlaschenTaschenServerKit"]),
        .library(name: "FlaschenTaschenClientKit", targets: ["FlaschenTaschenClientKit"]),
        .library(name: "FlaschenTaschenDemoKit", targets: ["FlaschenTaschenDemoKit"]),

        // Clients
        .executable(name: "send-text", targets: ["send-text"]),
        .executable(name: "send-image", targets: ["send-image"]),
        .executable(name: "send-video", targets: ["send-video"]),

        // Debugger
        .executable(name: "ft-debugger", targets: ["ft-debugger"]),

        // Demos

        // Simple Examples
        .executable(name: "simple-example", targets: ["simple-example"]),
        .executable(name: "simple-animation", targets: ["simple-animation"]),

        // Display Control
        .executable(name: "black", targets: ["black"]),

        // Generative Graphics
        .executable(name: "random-dots", targets: ["random-dots"]),
        .executable(name: "plasma", targets: ["plasma"]),
        .executable(name: "matrix", targets: ["matrix"]),
        .executable(name: "blur", targets: ["blur"]),
        .executable(name: "quilt", targets: ["quilt"]),
        .executable(name: "firefly", targets: ["firefly"]),
        .executable(name: "depth", targets: ["depth"]),
        .executable(name: "grayscale", targets: ["grayscale"]),

        // Mathematical & Algorithmic
        .executable(name: "life", targets: ["life"]),
        .executable(name: "fractal", targets: ["fractal"]),
        .executable(name: "sierpinski", targets: ["sierpinski"]),
        .executable(name: "maze", targets: ["maze"]),
        .executable(name: "lines", targets: ["lines"]),

        // Text & Font Rendering
        .executable(name: "hack", targets: ["hack"]),
        .executable(name: "words", targets: ["words"]),
        .executable(name: "nb-logo", targets: ["nb-logo"]),
        .executable(name: "sf-logo", targets: ["sf-logo"]),

        // Audio & Interactive
        .executable(name: "midi", targets: ["midi"]),
        .executable(name: "kbd2midi", targets: ["kbd2midi"]),
    ],
    targets: [
        // Server, Client and Demos Libraries
        .target(name: "FlaschenTaschenServerKit", swiftSettings: swiftSettings),

        .target(name: "FlaschenTaschenClientKit"),
        .target(name: "FlaschenTaschenDemoKit", dependencies: ["FlaschenTaschenClientKit"]),

        // Clients
        .executableTarget(name: "send-text", dependencies: ["FlaschenTaschenClientKit"]),
        .executableTarget(name: "send-image", dependencies: ["FlaschenTaschenClientKit"]),
        .executableTarget(name: "send-video", dependencies: ["FlaschenTaschenClientKit"]),

        // Debugger
        .executableTarget(name: "ft-debugger", dependencies: ["FlaschenTaschenClientKit", "FlaschenTaschenDemoKit"]),

        // Demos

        // Simple Examples
        .executableTarget(name: "simple-example", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "simple-animation", dependencies: ["FlaschenTaschenDemoKit"]),

        // Display Control
        .executableTarget(name: "black", dependencies: ["FlaschenTaschenDemoKit"]),

        // Generative Graphics
        .executableTarget(name: "random-dots", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "plasma", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "matrix", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "blur", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "quilt", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "firefly", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "depth", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "grayscale", dependencies: ["FlaschenTaschenDemoKit"]),

        // Mathematical & Algorithmic
        .executableTarget(name: "life", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "fractal", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "sierpinski", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "maze", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "lines", dependencies: ["FlaschenTaschenDemoKit"]),

        // Text & Font Rendering
        .executableTarget(name: "hack", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "words", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "nb-logo", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "sf-logo", dependencies: ["FlaschenTaschenDemoKit"]),

        // Audio & Interactive
        .executableTarget(name: "midi", dependencies: ["FlaschenTaschenDemoKit"]),
        .executableTarget(name: "kbd2midi", dependencies: ["FlaschenTaschenDemoKit"]),

        // Tests
        .testTarget(name: "FlaschenTaschenServerKitTests", dependencies: ["FlaschenTaschenServerKit"]),
        .testTarget(name: "FlaschenTaschenClientKitTests", dependencies: ["FlaschenTaschenClientKit"]),
    ]
)
