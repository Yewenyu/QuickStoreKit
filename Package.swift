// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "QuickStoreKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "QuickStoreKit",
            targets: ["QuickStoreKit"]
        ),
    ],
    targets: [
        .target(
            name: "QuickStoreKit",
            path: "QuickStoreKit"
        )
    ]
)
