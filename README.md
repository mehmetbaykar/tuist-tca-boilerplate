# Swift App Boilerplate

iOS app boilerplate.

## Status

Early development. Architecture, design system, scaffolding, and reference feature in place — ready to clone and build on.

## Tech stack

- **SwiftUI** + **The Composable Architecture** (TCA) — unidirectional state management
- **Tuist 4.x** — project generation; pinned via `.tuist-version`
- **Swift Testing** — unit tests (no XCTest)
- **swift-snapshot-testing** — UI regression tests
- **swift-dependencies** — dependency injection (bundled with TCA)
- **SwiftLintPlugins** + **SwiftFormat** — code style enforcement

iOS 17+ deployment target.

## Repository layout

```
.                                   # Tuist workspace root
├── Tuist.swift                     # Tuist version compatibility
├── Project.swift                   # All targets in one project
├── Makefile                        # Common dev commands (default goal: generate)
├── .tuist-version                  # Pinned Tuist version
├── Package.swift               # SPM deps + command plugin targets (Tuist reads this too)
├── Package.resolved            # Locked SPM versions (committed)
├── Tuist/
│   └── ProjectDescriptionHelpers/
│       ├── AppConfig.swift         # project name, bundle prefix, deployment target
│       ├── TargetDependency+Named.swift    # .composableArchitecture, .designSystem, etc.
│       ├── InfoPlist+Default.swift         # InfoPlist.appDefault
│       ├── FeatureTargetBuilder.swift      # builder + isRoot validation
│       └── LayerEnforcement.swift          # assertNoRootDependencies free function
├── plugins/                        # SPM command plugins
│   ├── bootstrap/                  # Downloads/links Tuist to .tuist-bin/ (compiled Swift binary)
│   ├── generate-secrets/           # Generates Secrets.swift from .env
│   ├── new-feature/                # Scaffolds Features/<Name>Feature/
│   └── new-client/                 # Scaffolds Features/<Name>Client/ (Interface/LiveKey/TestKey)
├── App/                            # App target — entry point only
│   ├── Sources/
│   └── Resources/
└── Features/
    ├── AppCoreFeature/             # Root reducer + view (NavigationStack push + sheet @Presents)
    ├── DesignSystem/               # Tokens, asset-catalog colors, button styles, Localizable.strings
    ├── ExampleFeature/             # Reference counter feature, reachable via push and sheet
    └── HapticClient/               # Reference dependency client (Interface/LiveKey/TestKey)
```

## Getting started

```bash
make setup                       # First-time: install tools, download Tuist, generate
```

After setup, common commands (run from project root):

```bash
make                             # Regenerate the Xcode project (default goal)
make deps                        # Resolve/install Swift Package Manager dependencies
make edit                        # Open Tuist's manifest editor for live-editing helpers with autocomplete
make test                        # Run all tests
make test-scheme SCHEME=HapticClient  # Run tests for one scheme (use Tuist scheme names)
make lint                        # SwiftLint strict check
make lint-fix                    # Auto-fix SwiftLint violations
make format                      # SwiftFormat (2-space indent)
make graph                       # Render a target dependency graph PNG (requires: brew install graphviz)
make feature NAME=Settings                       # Scaffold Features/SettingsFeature/ + auto-wire into Project.swift
make feature NAME=Settings WITH_CLIENT=Settings  # Scaffold SettingsFeature + paired SettingsClient, wire the dependency
make client NAME=Auth            # Scaffold Features/AuthClient/ (Interface/LiveKey/TestKey)
make env                         # Create .env from .env.example (errors if .env already exists)
make clean                       # Remove generated Xcode project and build artifacts
make clean-tools                 # Remove downloaded Tuist binary and bootstrap build artifacts
```

## Secrets

API keys and URLs live in a gitignored `.env` file and are baked into a generated `Secrets.swift` at build time.

```bash
make env                       # one-time: create .env from .env.example
# fill in the values, then:
make secrets                   # regenerate Secrets.swift (or just `make`)
```

Keys in `.env` use `SCREAMING_SNAKE_CASE` and are exposed in Swift as `Secrets.<camelCase>`:

```
EXAMPLE_API_KEY=abc123        →   Secrets.exampleApiKey
BACKEND_BASE_URL=https://…   →   Secrets.backendBaseUrl
```

- `.env` is gitignored — never committed
- `.env.example` is committed and documents the expected keys (values left blank)
- If `.env` is missing, `make secrets` prints a **yellow warning** and generates empty strings so the build doesn't break
- **Add a new key**: add `MY_KEY=` to `.env.example` (committed) and the real value to `.env` (local only), then add a `SecretEntry` to `plugins/generate-secrets/schema.swift` — the entry controls both the camelCase name and which Swift file it lands in (supports per-feature secrets files)

## Customize for your app

After cloning, swap in your own values:

- **App icon** — replace `App/Resources/Icon.xcassets/AppIcon.appiconset/icon.png` with your own 1024×1024 PNG (square, no rounded corners — iOS applies the mask)
- **Project name + bundle prefix** — edit `Tuist/ProjectDescriptionHelpers/AppConfig.swift` (e.g. change `projectName = "App"` and `bundlePrefix = "com.app"` to your reverse-DNS)
- **Brand colors** — edit `Features/DesignSystem/Sources/Tokens/DesignColors.swift` (the `Color(hex:)` defaults for `brandPrimary`, `brandPrimaryForeground`)
- **Strings** — edit `Features/DesignSystem/Resources/en.lproj/Localizable.strings`; drop in additional `<lang>.lproj/Localizable.strings` for more locales
- **Secrets** — run `make env` and fill in API keys / URLs. `make` regenerates `App/Sources/Generated/Secrets.swift` (gitignored) so they're accessible from Swift as e.g. `Secrets.exampleApiKey`. Declare new keys in `plugins/generate-secrets/schema.swift` to control their Swift name and destination file

## Architecture

- **Single TCA project**, all targets live in `Project.swift`
- **Independent design tokens** via separate `EnvironmentValues`: `\.designColors`, `\.designSpacing`, `\.designRadius`, `\.designFonts` — no central `Theme` god-object
- **Semantic colors** via asset catalog (auto-adapt for dark mode + high contrast); brand colors in Swift via `Color(hex:)`
- **Native button style ergonomics**: `.buttonStyle(.primary)` / `.buttonStyle(.secondary)`
- **Dependency clients** follow the `Interface.swift` / `LiveKey.swift` / `TestKey.swift` split (see `HapticClient` for the reference shape) — UIKit confined to `LiveKey.swift` only
- **Navigation patterns** demonstrated end-to-end: `StackState` + `@Reducer enum Path` for push, `@Presents` + `PresentationAction` for modal sheets — see `AppCoreFeature` wired to `ExampleFeature`
- **Root features** (e.g., `AppCoreFeature`) are flagged `isRoot: true` in `Project.swift`; a Tuist manifest validator fails generation if any sibling feature tries to depend on a root
- **Localization centralized** in `DesignSystem/Resources/en.lproj/Localizable.strings` — designed for sync from a translation service (POEditor, Crowdin). Views use Tuist-generated `DesignSystemStrings.<key>` accessors. Add a locale by dropping a `<lang>.lproj/Localizable.strings` next to `en.lproj/`
- **Productized scaffolding** — `make feature` and `make client` auto-edit `Project.swift` between marker comments. No manual paste step

## License

[MIT](./LICENSE) — Copyright (c) 2026 Oleksii Skliarenko
