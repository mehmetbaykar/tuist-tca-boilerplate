LOCAL_TUIST := .tuist-bin/tuist
SWIFTLINT := Tuist/.build/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint

# Use local binary if available, otherwise fall back to global tuist on PATH
ifeq ($(wildcard $(LOCAL_TUIST)),)
TUIST := tuist
else
TUIST := $(LOCAL_TUIST)
endif

.DEFAULT_GOAL := generate

.PHONY: setup generate edit test test-scheme lint lint-fix format install-tools clean clean-tools bootstrap feature client secrets graph deps help

## First-time setup: install tools, download/link Tuist, generate Secrets.swift, resolve SPM deps, generate Xcode project
setup: install-tools bootstrap secrets deps
	$(TUIST) generate --no-open

## Download or link Tuist binary to .tuist-bin/
bootstrap:
	@bash scripts/bootstrap.sh

## Scaffold a new feature: make feature NAME=Settings [WITH_CLIENT=Settings]
feature:
	@bash scripts/new-feature.sh $(NAME)

## Scaffold a new dependency client: make client NAME=Auth
client:
	@bash scripts/new-client.sh $(NAME)

## Generate App/Sources/Generated/Secrets.swift from .env (idempotent — no-op if unchanged)
secrets:
	@bash scripts/generate-secrets.sh

## Resolve/install Swift Package Manager dependencies (idempotent — Tuist caches)
deps:
	$(TUIST) install

## Regenerate Xcode project after any Project.swift or Package.swift change
generate: secrets deps
	$(TUIST) generate

## Open a temporary Xcode workspace to edit Tuist manifests (Project.swift, helpers, Package.swift) with autocomplete
edit:
	$(TUIST) edit

## Render a target dependency graph (PNG, app targets only; requires: brew install graphviz)
graph:
	@command -v dot &>/dev/null || (echo "✗ graphviz not installed. Run: brew install graphviz" && exit 1)
	$(TUIST) graph --skip-external-dependencies

## Run all unit tests
test: secrets deps
	$(TUIST) test

## Run tests for a specific scheme: make test-scheme SCHEME=AppCoreFeature
test-scheme:
	$(TUIST) test $(SCHEME)

## Run SwiftLint across the project (requires: make setup first)
lint:
	@$(SWIFTLINT) lint --strict

## Auto-fix SwiftLint violations
lint-fix:
	@$(SWIFTLINT) lint --fix

## Auto-format code with SwiftFormat (2-space indent)
format: install-tools
	swiftformat App Features

## Install development tools: SwiftFormat
install-tools:
	@command -v swiftformat &>/dev/null || brew install swiftformat

## Remove generated Xcode project and build artifacts
clean:
	$(TUIST) clean
	find . -maxdepth 4 \( -name "*.xcodeproj" -o -name "*.xcworkspace" \) \
		-not -path "*/.tuist-bin/*" -exec rm -rf {} + 2>/dev/null || true
	rm -rf .build

## Remove downloaded Tuist binary (forces re-download on next setup)
clean-tools:
	rm -rf .tuist-bin

help:
	@grep -E '^##' Makefile | sed 's/## //'
