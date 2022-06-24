// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xcode-package",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "xcode-package",
            targets: ["xcode-package"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.2"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(name: "xcode-package",
                          dependencies: [
                            .product(name: "ArgumentParser",
                                     package: "swift-argument-parser"),
                            .product(name: "Rainbow",
                                     package: "Rainbow")
                          ]),
        .testTarget(
            name: "xcode-packageTests",
            dependencies: ["xcode-package"]),
    ]
)
