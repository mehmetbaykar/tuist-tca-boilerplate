SHELL := /bin/bash

# Load .env if present — makes all keys available as Make variables and exports them to subprocesses
ifneq (,$(wildcard ./.env))
  include .env
  export $(shell sed 's/=.*//' .env)
endif

LOCAL_TUIST := .tuist-bin/tuist
SWIFTLINT := Tuist/.build/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint

# Use local binary if available, otherwise fall back to global tuist on PATH
ifeq ($(wildcard $(LOCAL_TUIST)),)
TUIST := tuist
else
TUIST := $(LOCAL_TUIST)
endif

# Dynamic linking locally for fast incremental builds; static on CI for faster app startup
export TUIST_LINKING_STRATEGY ?= DYNAMIC

tuist-generate-args :=
ifeq ($(CI),true)
  tuist-generate-args += --no-open
  TUIST_LINKING_STRATEGY := STATIC
endif

# bootstrap is the only compiled binary — new-feature/new-client/generate-secrets run as SPM plugins.
plugins/.build/bootstrap: $(wildcard plugins/bootstrap/*.swift)
	@mkdir -p plugins/.build
	@echo "→ Compiling bootstrap..."
	@swiftc -O -parse-as-library -o $@ $(wildcard plugins/bootstrap/*.swift)

secrets:
	@swift package --allow-writing-to-package-directory generate-secrets

.DEFAULT_GOAL := generate

.PHONY: setup generate edit test test-scheme lint lint-fix format install-tools clean clean-tools bootstrap feature client secrets graph deps help env

## First-time setup: install tools, download/link Tuist, generate Secrets.swift, resolve SPM deps, generate Xcode project
setup: install-tools bootstrap secrets deps
	$(TUIST) generate --no-open

## Download or link Tuist binary to .tuist-bin/
bootstrap: plugins/.build/bootstrap
	@plugins/.build/bootstrap

## Scaffold a new feature: make feature NAME=Settings [WITH_CLIENT=Settings]
feature:
	@swift package --allow-writing-to-package-directory new-feature -- $(NAME) $(if $(WITH_CLIENT),--with-client $(WITH_CLIENT),)

## Scaffold a new dependency client: make client NAME=Auth
client:
	@swift package --allow-writing-to-package-directory new-client -- $(NAME)

## Resolve/install Swift Package Manager dependencies (idempotent — Tuist caches)
deps:
	$(TUIST) install

## Regenerate Xcode project after any Project.swift or Package.swift change
generate: secrets deps
	$(TUIST) generate $(tuist-generate-args)

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

## Run tests for a specific scheme: make test-scheme SCHEME=HapticClient  (use tuist scheme names, not target names)
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

## Remove downloaded Tuist binary and compiled script binaries
clean-tools:
	rm -rf .tuist-bin plugins/.build

## Bootstrap .env from .env.example (fails with a clear message if .env already exists)
env: .env.example
	@test ! -f .env || (printf '%b' "$$DOTENV_ERROR" && exit 1)
	@cp .env.example .env
	@echo "✓ .env created — fill in your secrets and run: make"

help:
	@grep -E '^##' Makefile | sed 's/## //'

define DOTENV_ERROR
 🛑  .env already exists.

    Edit it directly, or delete it and re-run 'make env' to reset from the example.
    Check .env.example for any newly added keys.

endef
export DOTENV_ERROR
