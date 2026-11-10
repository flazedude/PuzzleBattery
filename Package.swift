// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PuzzleBattery",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PuzzleBattery", targets: ["PuzzleBattery"])],
    targets: [
        .target(name: "BatteryCore"),
        .executableTarget(name: "PuzzleBattery", dependencies: ["BatteryCore"]),
        .testTarget(name: "BatteryCoreTests", dependencies: ["BatteryCore"])
    ]
)
