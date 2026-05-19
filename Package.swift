// swift-tools-version: 5.10

@preconcurrency import PackageDescription

let package = Package(
  name: "App",
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      from: "1.15.0"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-snapshot-testing",
      from: "1.17.0"
    ),
    .package(
      url: "https://github.com/SimplyDanny/SwiftLintPlugins",
      from: "0.63.2"
    ),
  ],
  targets: [
    .plugin(
      name: "GenerateSecrets",
      capability: .command(
        intent: .custom(
          verb: "generate-secrets",
          description: "Generates Secrets.swift from .env (or .env.example when .env is absent)."
        ),
        permissions: [
          .writeToPackageDirectory(
            reason: "Writes App/Sources/Generated/Secrets.swift."
          ),
        ]
      ),
      path: "plugins/generate-secrets"
    ),
    .plugin(
      name: "NewFeature",
      capability: .command(
        intent: .custom(
          verb: "new-feature",
          description: "Scaffolds a new TCA feature under Features/<Name>Feature/."
        ),
        permissions: [
          .writeToPackageDirectory(
            reason: "Creates source files under Features/ and edits Project.swift."
          ),
        ]
      ),
      path: "plugins/new-feature"
    ),
    .plugin(
      name: "NewClient",
      capability: .command(
        intent: .custom(
          verb: "new-client",
          description: "Scaffolds a dependency client under Features/<Name>Client/."
        ),
        permissions: [
          .writeToPackageDirectory(
            reason: "Creates Interface.swift, LiveKey.swift, and TestKey.swift under Features/."
          ),
        ]
      ),
      path: "plugins/new-client"
    ),
  ]
)

#if TUIST
  import ProjectDescription

  // Use dynamic frameworks for shared SPM packages so there is a single shared
  // dependency registry across all dynamic feature frameworks at runtime.
  // Static linking would give each framework its own isolated registry copy,
  // causing "no live implementation" errors for DependencyKey conformances.
  let packageSettings = PackageSettings(
    productTypes: [
      "CasePaths": .framework,
      "Clocks": .framework,
      "CombineSchedulers": .framework,
      "ComposableArchitecture": .framework,
      "ConcurrencyExtras": .framework,
      "CustomDump": .framework,
      "Dependencies": .framework,
      "DependenciesMacros": .framework,
      "IdentifiedCollections": .framework,
      "InternalCollectionsUtilities": .framework,
      "OrderedCollections": .framework,
      "Perception": .framework,
      "XCTestDynamicOverlay": .framework,
    ]
  )
#endif
