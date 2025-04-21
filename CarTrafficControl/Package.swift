// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CarTrafficControl",
    platforms: [.iOS(.v15)],
    products: [
        .executable(name: "CarTrafficControl", targets: ["CarTrafficControl"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CarTrafficControl",
            dependencies: []),
    ]
)
