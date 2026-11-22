// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PixelBlaster",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PixelBlaster", targets: ["PixelBlaster"])
    ],
    targets: [
        .executableTarget(
            name: "PixelBlaster",
            path: "Sources/PixelBlaster",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SpriteKit"),
                .linkedFramework("GameController"),
                .linkedFramework("CoreHaptics"),
                .linkedFramework("AVFoundation")
            ]
        )
    ]
)
