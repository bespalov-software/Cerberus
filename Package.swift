// swift-tools-version: 6.2
//
// Cerberus — BoringSSL wrapper for the Heaven constellation.
//
// CCerberus is a binaryTarget xcframework built from the BoringSSL submodule
// at Sources/CCerberus/vendor/boringssl by `make create-xcframework`.
//
// Both `Cerberus` (Swift facade) and `CCerberus` (binary target) are exported
// as products so sibling packages (e.g. Calypso) can link the static libs.

import PackageDescription

let package = Package(
    name: "Cerberus",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
        .macCatalyst(.v15),
    ],
    products: [
        .library(
            name: "Cerberus",
            targets: ["Cerberus"]
        ),
        // Exposed as a product so that sibling packages can link BoringSSL
        // statically without going through the Swift facade. Calypso needs this
        // to compile sqlite3 against -lcrypto.
        .library(
            name: "CCerberus",
            targets: ["CCerberus"]
        ),
    ],
    targets: [
        .target(
            name: "Cerberus",
            dependencies: ["CCerberus"]
        ),
        .testTarget(
            name: "CerberusTests",
            dependencies: ["Cerberus"]
        ),
        .binaryTarget(
            name: "CCerberus",
            path: "./Sources/CCerberus/extra/CCerberus.xcframework"
        ),
    ]
)
