# Cerberus

Swift package wrapping BoringSSL as an xcframework for Apple platforms.

## Targets

- **`Cerberus`** — Swift facade. Initial surface: `Cerberus.sha256(_:)`. Extend as needed.
- **`CCerberus`** — `binaryTarget` xcframework with `libcrypto.a` + `libssl.a`. Exported as a product so sibling packages can link BoringSSL directly.

## Build

The prebuilt **`CCerberus.xcframework` is committed** (~90MB stripped, all 10 slices) so consumers don't need to rebuild BoringSSL. Just:

```bash
swift build
swift test
```

To rebuild from source (after bumping the boringssl submodule, or to verify the binary):

```bash
git submodule update --init --recursive
make build-quick           # iOS arm64 + iOS sim arm64 + macOS arm64 (~30 min)
# OR
make build-all             # all 16 Apple slices (~3 hours)
make create-xcframework    # bundles + strips → 90MB xcframework
swift test
```

Per-platform: `make build-ios-arm64`, `make build-macos-arm64`, etc.

## Consume

App / Swift package:

```swift
.package(path: "../Cerberus"),
// in target.dependencies:
.product(name: "Cerberus", package: "Cerberus"),
```

Sibling C target that needs `-lcrypto` (e.g. Calypso compiling `sqlite3.c`):

```swift
.product(name: "CCerberus", package: "Cerberus"),
```

## Layout

```
Cerberus/
├── Package.swift
├── Makefile                                  # → scripts/build.sh
├── scripts/build.sh                          # CMake per-platform → libtool → lipo → xcframework
├── Sources/
│   ├── Cerberus/Cerberus.swift               # Swift facade
│   └── CCerberus/
│       ├── extra/                            # gitignored — produced by `make`
│       │   ├── CCerberus.xcframework/
│       │   └── headers/openssl/              # for sibling headerSearchPath
│       └── vendor/
│           ├── boringssl/                    # git submodule
│           └── build/                        # gitignored — per-platform installs
└── Tests/CerberusTests/                      # SHA-256 known-answer tests
```

## Notes

`scripts/build.sh` carries three Apple-specific BoringSSL workarounds:
- `CMAKE_MACOSX_BUNDLE=OFF` — required on iOS/tvOS/watchOS/visionOS or `install(TARGETS bssl)` fails configure.
- Mac Catalyst slices skip `CMAKE_OSX_DEPLOYMENT_TARGET` — already in the `-macabi` triple; passing both triggers `-Werror,-Woverriding-option`.
- The xcframework's `module.modulemap` excludes `openssl/span.h` and `openssl/pki/*` — they include C++ stdlib headers without `__cplusplus` guards and break Swift's clang importer.
