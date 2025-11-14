// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BrightnessControl",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "BrightnessControl",
            targets: ["BrightnessControl"]
        )
    ],
    targets: [
        .executableTarget(
            name: "BrightnessControl",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreDisplay"),
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Info.plist"])
            ]
        )
    ]
)
