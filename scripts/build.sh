#!/usr/bin/env bash
# ============================================================================
# Cerberus — BoringSSL per-platform build helper
# ============================================================================
# Used by the Makefile. Two sub-commands:
#
#   scripts/build.sh build <platform>     # configure + build BoringSSL for one slice
#   scripts/build.sh xcframework          # bundle all built slices into CCerberus.xcframework
#
# Each per-platform build produces:
#   Sources/CCerberus/vendor/build/<platform>/install/lib/libcrypto.a
#   Sources/CCerberus/vendor/build/<platform>/install/lib/libssl.a
#
# The xcframework step combines crypto+ssl per arch (libtool), then lipo's
# universal slices, then xcodebuild -create-xcframework.
#
# IMPORTANT: BoringSSL's CMake build for non-macOS Apple platforms is finicky.
# This script is a starter that should work for arm64/x86_64 device + simulator
# slices on iOS and macOS. Other platforms (tvOS/watchOS/visionOS/macCatalyst)
# may need additional CMAKE_SYSTEM_NAME tweaks — adjust per_platform_cmake_args.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BORINGSSL_SRC="$REPO_ROOT/Sources/CCerberus/vendor/boringssl"
BUILD_ROOT="$REPO_ROOT/Sources/CCerberus/vendor/build"
EXTRA_DIR="$REPO_ROOT/Sources/CCerberus/extra"
HEADERS_DIR="$EXTRA_DIR/headers"
XCFRAMEWORK="$EXTRA_DIR/CCerberus.xcframework"

# ----------------------------------------------------------------------------
# Platform table: platform-name → "sdk arch min-version cmake-system-name"
# ----------------------------------------------------------------------------
platform_config() {
    case "$1" in
        ios-arm64)                  echo "iphoneos arm64 13.0 iOS";;
        ios-simulator-arm64)        echo "iphonesimulator arm64 13.0 iOS";;
        ios-simulator-x86_64)       echo "iphonesimulator x86_64 13.0 iOS";;
        macos-arm64)                echo "macosx arm64 11.0 Darwin";;
        macos-x86_64)               echo "macosx x86_64 11.0 Darwin";;
        maccatalyst-arm64)          echo "macosx arm64 15.0 Darwin";;
        maccatalyst-x86_64)         echo "macosx x86_64 15.0 Darwin";;
        tvos-arm64)                 echo "appletvos arm64 15.0 tvOS";;
        tvos-simulator-arm64)       echo "appletvsimulator arm64 15.0 tvOS";;
        tvos-simulator-x86_64)      echo "appletvsimulator x86_64 15.0 tvOS";;
        watchos-arm64)              echo "watchos arm64 8.0 watchOS";;
        watchos-simulator-arm64)    echo "watchsimulator arm64 8.0 watchOS";;
        watchos-simulator-x86_64)   echo "watchsimulator x86_64 8.0 watchOS";;
        visionos-arm64)             echo "xros arm64 1.0 visionOS";;
        visionos-simulator-arm64)   echo "xrsimulator arm64 1.0 visionOS";;
        visionos-simulator-x86_64)  echo "xrsimulator x86_64 1.0 visionOS";;
        *) echo "ERROR: unknown platform '$1'" >&2; exit 1;;
    esac
}

target_triple() {
    local sdk="$1" arch="$2" min_ver="$3" platform="$4"
    case "$sdk" in
        iphoneos)         echo "${arch}-apple-ios${min_ver}";;
        iphonesimulator)  echo "${arch}-apple-ios${min_ver}-simulator";;
        macosx)
            if [[ "$platform" == maccatalyst-* ]]; then
                echo "${arch}-apple-ios${min_ver}-macabi"
            else
                echo "${arch}-apple-macos${min_ver}"
            fi
            ;;
        appletvos)        echo "${arch}-apple-tvos${min_ver}";;
        appletvsimulator) echo "${arch}-apple-tvos${min_ver}-simulator";;
        watchos)          echo "${arch}-apple-watchos${min_ver}";;
        watchsimulator)   echo "${arch}-apple-watchos${min_ver}-simulator";;
        xros)             echo "${arch}-apple-xros${min_ver}";;
        xrsimulator)      echo "${arch}-apple-xros${min_ver}-simulator";;
    esac
}

build_platform() {
    local platform="$1"
    read -r sdk arch min_ver cmake_system_name <<< "$(platform_config "$platform")"

    local build_dir="$BUILD_ROOT/$platform"
    local install_dir="$build_dir/install"
    local sdk_path
    sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
    local triple
    triple="$(target_triple "$sdk" "$arch" "$min_ver" "$platform")"

    echo "==> Building BoringSSL for $platform"
    echo "    sdk=$sdk arch=$arch min=$min_ver triple=$triple"
    echo "    sysroot=$sdk_path"

    mkdir -p "$build_dir"

    # CMake configure.
    # Notes:
    #  - BUILD_SHARED_LIBS=OFF: we want libcrypto.a / libssl.a (static).
    #  - CMAKE_SYSTEM_NAME varies per Apple platform; macOS uses "Darwin",
    #    iOS/tvOS/watchOS use their own names. CMake then selects the right
    #    cross-compile defaults.
    #  - CMAKE_OSX_ARCHITECTURES restricts to a single arch (we lipo later).
    #  - BUILD_TESTING=OFF — BoringSSL tests need Go + a real socket layer,
    #    don't run cleanly on cross-compile slices.
    #  - CMAKE_MACOSX_BUNDLE=OFF — on iOS/tvOS/watchOS/visionOS, executable
    #    targets default to MACOSX_BUNDLE, which then requires a BUNDLE
    #    DESTINATION in install() rules. BoringSSL's `install(TARGETS bssl)`
    #    has no BUNDLE DESTINATION, so configure fails. Setting this to OFF
    #    makes the bssl CLI tool a plain executable, sidestepping the issue.
    #    (We don't ship bssl anyway — only libcrypto.a/libssl.a.)
    #  - For Mac Catalyst the deployment target lives inside the triple
    #    (`-ios15.0-macabi`); ALSO setting CMAKE_OSX_DEPLOYMENT_TARGET emits
    #    `-mmacosx-version-min=`, which clang then warns about as overriding
    #    the triple — and BoringSSL's `-Werror` makes that a build failure.
    #    So omit deployment-target for maccatalyst slices.
    local deployment_arg=()
    if [[ "$platform" != maccatalyst-* ]]; then
        deployment_arg+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=$min_ver")
    fi

    cmake -S "$BORINGSSL_SRC" -B "$build_dir" \
        -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$install_dir" \
        -DCMAKE_SYSTEM_NAME="$cmake_system_name" \
        -DCMAKE_OSX_SYSROOT="$sdk_path" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        "${deployment_arg[@]}" \
        -DCMAKE_C_COMPILER_TARGET="$triple" \
        -DCMAKE_CXX_COMPILER_TARGET="$triple" \
        -DCMAKE_ASM_COMPILER_TARGET="$triple" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF \
        -DCMAKE_MACOSX_BUNDLE=OFF

    cmake --build "$build_dir" --target crypto ssl

    # BoringSSL doesn't ship an `install` target that lays things out the way
    # we want — collect the .a files and headers manually.
    mkdir -p "$install_dir/lib" "$install_dir/include"
    cp "$build_dir/libcrypto.a" "$install_dir/lib/" 2>/dev/null \
      || cp "$build_dir/crypto/libcrypto.a" "$install_dir/lib/"
    cp "$build_dir/libssl.a" "$install_dir/lib/" 2>/dev/null \
      || cp "$build_dir/ssl/libssl.a" "$install_dir/lib/"
    rm -rf "$install_dir/include/openssl"
    cp -R "$BORINGSSL_SRC/include/openssl" "$install_dir/include/"

    echo "✓ Built $platform → $install_dir/lib/{libcrypto.a,libssl.a}"
}

# Combine libcrypto.a + libssl.a → libCCerberus.a for one arch slice, then
# `strip -S` to drop debug symbols (~7× size reduction; 59MB → 8.5MB per slice).
# 2>/dev/null suppresses the noisy per-object "already stripped" warnings for
# arch-specific .S files that are no-ops on this slice.
combine_archive() {
    local platform="$1" out="$2"
    libtool -static -o "$out" \
        "$BUILD_ROOT/$platform/install/lib/libcrypto.a" \
        "$BUILD_ROOT/$platform/install/lib/libssl.a"
    strip -S "$out" 2>/dev/null || true
}

# Build one xcframework slice. If $2 is empty we copy the single-arch combined
# archive; if $2 is given we lipo arm64+x86_64 into a universal slice.
make_slice() {
    local slice_name="$1" arm64_platform="$2" x86_64_platform="${3:-}"
    local slice_dir="$BUILD_ROOT/sliced/$slice_name"
    mkdir -p "$slice_dir"

    if [ -z "$x86_64_platform" ]; then
        combine_archive "$arm64_platform" "$slice_dir/libCCerberus.a"
    else
        combine_archive "$arm64_platform" "$slice_dir/libCCerberus-arm64.a"
        combine_archive "$x86_64_platform" "$slice_dir/libCCerberus-x86_64.a"
        lipo -create \
            "$slice_dir/libCCerberus-arm64.a" \
            "$slice_dir/libCCerberus-x86_64.a" \
            -output "$slice_dir/libCCerberus.a"
    fi
    echo "$slice_dir/libCCerberus.a"
}

create_xcframework() {
    rm -rf "$XCFRAMEWORK" "$HEADERS_DIR"
    mkdir -p "$EXTRA_DIR" "$HEADERS_DIR"

    # Headers are arch/platform-independent — copy once.
    cp -R "$BORINGSSL_SRC/include/openssl" "$HEADERS_DIR/"

    # Module map at the headers root so Swift can `import CCerberus`. The
    # umbrella covers the entire openssl/ tree; `module * { export * }` makes
    # every header an auto-exported submodule. The `exclude header` lines drop
    # BoringSSL's C++17 public API (openssl/pki/* and openssl/span.h) — Clang's
    # C-mode module compile chokes on their unguarded `#include <memory>` etc.
    # Swift can't call those C++ APIs directly anyway; Calypso reaches them via
    # headerSearchPath if it ever needs them.
    cat > "$HEADERS_DIR/module.modulemap" <<'MODMAP'
module CCerberus {
    umbrella "openssl"
    export *
    module * { export * }

    exclude header "openssl/span.h"
    exclude header "openssl/pki/certificate.h"
    exclude header "openssl/pki/ocsp.h"
    exclude header "openssl/pki/signature_verify_cache.h"
    exclude header "openssl/pki/verify.h"
    exclude header "openssl/pki/verify_error.h"
}
MODMAP

    local args=()

    # Add a slice if at least one of its archs is built. If only one arch of a
    # universal slice is present, ship a single-arch slice — useful for fast
    # iteration (e.g. validating macos-arm64 alone before building x86_64).
    add_slice() {
        local slice="$1" a="$2" b="${3:-}"
        local a_built=0 b_built=0
        [ -d "$BUILD_ROOT/$a/install" ] && a_built=1
        [ -n "$b" ] && [ -d "$BUILD_ROOT/$b/install" ] && b_built=1

        local lib
        if [ "$a_built" = 1 ] && [ "$b_built" = 1 ]; then
            lib="$(make_slice "$slice" "$a" "$b")"               # universal
        elif [ "$a_built" = 1 ]; then
            lib="$(make_slice "$slice" "$a")"                    # single-arch (a)
        elif [ "$b_built" = 1 ]; then
            lib="$(make_slice "$slice" "$b")"                    # single-arch (b)
        else
            echo "  (skipping $slice — not built)"
            return
        fi
        args+=("-library" "$lib" "-headers" "$HEADERS_DIR")
    }

    add_slice "ios-arm64"           "ios-arm64"
    add_slice "ios-simulator"       "ios-simulator-arm64"     "ios-simulator-x86_64"
    add_slice "macos"               "macos-arm64"             "macos-x86_64"
    add_slice "maccatalyst"         "maccatalyst-arm64"       "maccatalyst-x86_64"
    add_slice "tvos-arm64"          "tvos-arm64"
    add_slice "tvos-simulator"      "tvos-simulator-arm64"    "tvos-simulator-x86_64"
    add_slice "watchos-arm64"       "watchos-arm64"
    add_slice "watchos-simulator"   "watchos-simulator-arm64" "watchos-simulator-x86_64"
    add_slice "visionos-arm64"      "visionos-arm64"
    add_slice "visionos-simulator"  "visionos-simulator-arm64" "visionos-simulator-x86_64"

    if [ ${#args[@]} -eq 0 ]; then
        echo "ERROR: no per-platform builds found under $BUILD_ROOT — run 'make build-quick' first" >&2
        exit 1
    fi

    xcodebuild -create-xcframework "${args[@]}" -output "$XCFRAMEWORK"
    echo "✓ Created $XCFRAMEWORK"
}

case "${1:-help}" in
    build)        build_platform "$2";;
    xcframework)  create_xcframework;;
    help|*)
        cat <<'EOF'
Cerberus — BoringSSL build helper.

Usage:
  scripts/build.sh build <platform>     Build BoringSSL for one Apple slice
  scripts/build.sh xcframework          Bundle built slices into CCerberus.xcframework

Platforms:
  ios-arm64, ios-simulator-arm64, ios-simulator-x86_64
  macos-arm64, macos-x86_64
  maccatalyst-arm64, maccatalyst-x86_64
  tvos-arm64, tvos-simulator-arm64, tvos-simulator-x86_64
  watchos-arm64, watchos-simulator-arm64, watchos-simulator-x86_64
  visionos-arm64, visionos-simulator-arm64, visionos-simulator-x86_64
EOF
        ;;
esac
