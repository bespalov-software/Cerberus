# ============================================================================
# Cerberus — BoringSSL → CCerberus.xcframework Makefile
# ============================================================================
# Mirrors Kalliope's per-platform build pattern, but uses CMake (BoringSSL's
# build system) instead of autotools. All heavy lifting is in scripts/build.sh.
#
# Typical workflow:
#   1.  make build-quick         # iOS device + iOS sim + macOS — first iteration
#   2.  make create-xcframework  # bundle built slices into CCerberus.xcframework
#   3.  swift test               # link & run smoke tests
#
# To build for every Apple platform (slow, ~30–60 min):
#   make build-all && make create-xcframework
#
# ============================================================================

PLATFORMS := ios-arm64 ios-simulator-arm64 ios-simulator-x86_64 \
             macos-arm64 macos-x86_64 \
             maccatalyst-arm64 maccatalyst-x86_64 \
             tvos-arm64 tvos-simulator-arm64 tvos-simulator-x86_64 \
             watchos-arm64 watchos-simulator-arm64 watchos-simulator-x86_64 \
             visionos-arm64 visionos-simulator-arm64 visionos-simulator-x86_64

QUICK_PLATFORMS := ios-arm64 ios-simulator-arm64 macos-arm64

# ----------------------------------------------------------------------------
# Per-platform build targets, generated programmatically.
# ----------------------------------------------------------------------------
define build-platform-rule
build-$(1):
	@scripts/build.sh build $(1)
.PHONY: build-$(1)
endef
$(foreach p,$(PLATFORMS),$(eval $(call build-platform-rule,$(p))))

# ----------------------------------------------------------------------------
# Aggregate builds.
# ----------------------------------------------------------------------------
build-quick: $(addprefix build-,$(QUICK_PLATFORMS))
	@echo "✓ Quick build complete ($(QUICK_PLATFORMS))"

build-ios-simulator: build-ios-simulator-arm64 build-ios-simulator-x86_64
build-tvos-simulator: build-tvos-simulator-arm64 build-tvos-simulator-x86_64
build-watchos-simulator: build-watchos-simulator-arm64 build-watchos-simulator-x86_64
build-visionos-simulator: build-visionos-simulator-arm64 build-visionos-simulator-x86_64
build-maccatalyst: build-maccatalyst-arm64 build-maccatalyst-x86_64
build-macos: build-macos-arm64 build-macos-x86_64

build-all: $(addprefix build-,$(PLATFORMS))
	@echo "✓ All BoringSSL platforms built"

# ----------------------------------------------------------------------------
# XCFramework assembly.
# ----------------------------------------------------------------------------
create-xcframework:
	@scripts/build.sh xcframework

# ----------------------------------------------------------------------------
# Cleanup.
# ----------------------------------------------------------------------------
clean:
	rm -rf Sources/CCerberus/vendor/build \
	       Sources/CCerberus/extra/CCerberus.xcframework \
	       Sources/CCerberus/extra/headers

clean-build:
	rm -rf Sources/CCerberus/vendor/build

# ----------------------------------------------------------------------------
help:
	@echo "Cerberus — BoringSSL → CCerberus.xcframework build"
	@echo ""
	@echo "Quick start:"
	@echo "  make build-quick           # iOS arm64 + iOS sim arm64 + macOS arm64"
	@echo "  make create-xcframework"
	@echo "  swift test"
	@echo ""
	@echo "Full build (slow):"
	@echo "  make build-all && make create-xcframework"
	@echo ""
	@echo "Per-platform: make build-<platform>"
	@echo "Platforms: $(PLATFORMS)"

.PHONY: build-quick build-ios-simulator build-tvos-simulator \
        build-watchos-simulator build-visionos-simulator build-maccatalyst \
        build-macos build-all create-xcframework clean clean-build help
