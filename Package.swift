// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MQTTKit",
    platforms: [
        .macOS("10.15.4"),
        .iOS("13.4"),
        .tvOS("13.4"),
        .watchOS("6"),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MQTTKit",
            targets: ["MQTTKit"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
//      .package(url: "https://github.com/leisurehound/CornucopiaStreams.git", .branch("master"))
      .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.2.0"),
//      .package(url: "https://github.com/leisurehound/CornucopiaStreams.git", .branch("issue/1/hasBytesAvailable"))
        
    ],
    targets: [
        // Targets are the basic building blocks of a package.
        // A target can define a module or a test suite.
        // Targets can depend on other targets in this package,
        // and on products in packages which this package depends on.
        .target(
            name: "MQTTKit",
            dependencies: [
//              "CornucopiaStreams",
              "WebSocketKit",
            ],
            path: "Sources"
            ),
        .testTarget(
            name: "MQTTKitTests",
            dependencies: ["MQTTKit"],
            path: "Tests"
          )

    ]
)
