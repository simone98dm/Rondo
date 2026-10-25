// swift-tools-version:5.10
// File conversion engine (formats, tools, wheel logic) used by Rondo's File Converter.
// UI-free and fully unit-tested.
import PackageDescription

let package = Package(
    name: "RondoCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RondoCore", targets: ["RondoCore"]),
    ],
    targets: [
        .target(name: "RondoCore"),
        .testTarget(name: "RondoCoreTests", dependencies: ["RondoCore"]),
    ]
)
