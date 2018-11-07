// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BigQuerySwift",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "BigQuerySwift",
            targets: ["BigQuerySwift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/IBM-Swift/SwiftyRequest.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/saga-dash/auth-library-swift.git", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "BigQuerySwift",
            dependencies: ["SwiftyRequest", "OAuth2"]),
        .testTarget(
            name: "BigQuerySwiftTests",
            dependencies: ["BigQuerySwift"]),
    ]
)
