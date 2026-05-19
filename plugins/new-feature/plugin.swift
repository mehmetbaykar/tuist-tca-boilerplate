import Foundation

// MARK: - Utilities

func printGreen(_ s: String) { print("\u{1B}[32m✓ \(s)\u{1B}[0m") }
func die(_ msg: String) -> Never { fputs("✗ \(msg)\n", stderr); exit(1) }

func lowerFirst(_ s: String) -> String {
  guard let first = s.first else { return s }
  return first.lowercased() + s.dropFirst()
}

func insertAboveMarker(line: String, marker: String, inFile path: String) {
  guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
    die("could not read \(path)")
  }
  var lines = content.components(separatedBy: "\n")
  guard let idx = lines.firstIndex(where: { $0.contains(marker) }) else {
    die("marker not found in \(path)\n  Expected: \(marker)")
  }
  lines.insert(line, at: idx)
  guard (try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)) != nil else {
    die("could not write \(path)")
  }
}

func writeFile(_ content: String, to path: String) {
  let url = URL(fileURLWithPath: path)
  try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  guard (try? content.write(to: url, atomically: true, encoding: .utf8)) != nil else {
    die("could not write \(path)")
  }
}

// MARK: - Feature templates

func featureReducerTemplate(_ name: String) -> String {
  #"""
  import ComposableArchitecture

  @Reducer
  public struct \#(name) {

    @ObservableState
    public struct State: Equatable {
      public init() {}
    }

    public enum Action: ViewAction {
      case view(View)
      case delegate(Delegate)

      @CasePathable
      public enum View {
        case onAppear
      }

      @CasePathable
      public enum Delegate: Equatable {}
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { _, action in
        switch action {
        case .view(.onAppear):
          return .none
        case .delegate:
          return .none
        }
      }
    }
  }
  """#
}

func featureViewTemplate(_ featureName: String, viewName: String) -> String {
  #"""
  import ComposableArchitecture
  import DesignSystem
  import SwiftUI

  @ViewAction(for: \#(featureName).self)
  public struct \#(viewName): View {
    public let store: StoreOf<\#(featureName)>

    public init(store: StoreOf<\#(featureName)>) {
      self.store = store
    }

    @Environment(\.designSpacing) var spacing

    public var body: some View {
      Text("\#(featureName)")
        .onAppear { send(.onAppear) }
    }
  }

  #if DEBUG
  #Preview {
    \#(viewName)(
      store: Store(initialState: \#(featureName).State()) {
        \#(featureName)()
      }
    )
  }
  #endif
  """#
}

func featureReducerTestsTemplate(_ name: String) -> String {
  #"""
  import ComposableArchitecture
  import Testing

  @testable import \#(name)

  @Suite("\#(name)")
  @MainActor
  struct \#(name)Tests {
    private func makeStore(
      initialState: \#(name).State = .init(),
      dependencies: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<\#(name)> {
      TestStore(initialState: initialState) {
        \#(name)()
      } withDependencies: {
        dependencies(&$0)
      }
    }

    @Test("onAppear produces no state change")
    func onAppear() async {
      let store = makeStore()
      await store.send(.view(.onAppear))
    }
  }
  """#
}

func featureViewTestsTemplate(_ featureName: String, viewName: String) -> String {
  #"""
  import ComposableArchitecture
  import SnapshotTesting
  import SwiftUI
  import Testing
  import UIKit

  @testable import \#(featureName)

  @Suite("\#(viewName)", .serialized)
  @MainActor
  struct \#(viewName)Tests {
    private func makeViewController(
      userInterfaceStyle: UIUserInterfaceStyle = .light
    ) -> UIViewController {
      let controller = UIHostingController(
        rootView: \#(viewName)(
          store: Store(initialState: \#(featureName).State()) {
            \#(featureName)()
          }
        )
      )
      controller.overrideUserInterfaceStyle = userInterfaceStyle
      return controller
    }

    @Test("light mode")
    func lightMode() {
      assertSnapshot(of: makeViewController(), as: .image(on: .iPhone13Pro))
    }

    @Test("dark mode")
    func darkMode() {
      assertSnapshot(of: makeViewController(userInterfaceStyle: .dark), as: .image(on: .iPhone13Pro))
    }
  }
  """#
}

// MARK: - Client templates (used when --with-client is passed)

private func interfaceTemplate(_ clientName: String) -> String {
  #"""
  import ComposableArchitecture

  @DependencyClient
  public struct \#(clientName): Sendable {
    // Define your endpoints here:
    // public var fetchSomething: @Sendable () async throws -> String
  }
  """#
}

private func liveKeyTemplate(_ clientName: String) -> String {
  #"""
  import Dependencies

  extension \#(clientName): DependencyKey {
    public static var liveValue: Self {
      // Use @Dependency(\.otherClient) here if this client depends on another
      Self(
        // Implement live endpoints here
      )
    }
  }
  """#
}

private func testKeyTemplate(_ clientName: String, depKey: String) -> String {
  #"""
  import Dependencies

  extension DependencyValues {
    public var \#(depKey): \#(clientName) {
      get { self[\#(clientName).self] }
      set { self[\#(clientName).self] = newValue }
    }
  }

  extension \#(clientName): TestDependencyKey {
    public static let testValue = Self()
    public static let previewValue = Self.noop
  }

  extension \#(clientName) {
    public static let noop = Self(
      // No-op implementations here
    )
  }
  """#
}

private func clientTestsTemplate(_ clientName: String) -> String {
  #"""
  import ComposableArchitecture
  import Testing

  @testable import \#(clientName)

  @Suite("\#(clientName)")
  struct \#(clientName)Tests {
    @Test("preview value does not throw")
    func previewValue() async {
      // Verify previewValue endpoints are callable
    }
  }
  """#
}

// MARK: - Scaffolding

func scaffoldNewFeature(base: String, withClient: String?, projectRoot: String) {
  let fm = FileManager.default
  let featureName = "\(base)Feature"
  let viewName = "\(base)View"
  let featureDir = "\(projectRoot)/Features/\(featureName)"
  let projectFile = "\(projectRoot)/Project.swift"
  let depsFile = "\(projectRoot)/Tuist/ProjectDescriptionHelpers/TargetDependency+Named.swift"
  let featureMarker = "// tuist-marker: insert new features above this line"
  let depsMarker = "// tuist-marker: insert new client deps above this line"

  guard !fm.fileExists(atPath: featureDir) else {
    die("'\(featureName)' already exists at Features/\(featureName)")
  }

  // Pre-validate all markers before creating any files
  guard let projectSrc = try? String(contentsOfFile: projectFile, encoding: .utf8),
        projectSrc.contains(featureMarker) else {
    die("marker not found in Project.swift\n  Expected: \(featureMarker)")
  }
  if withClient != nil {
    guard let depsSrc = try? String(contentsOfFile: depsFile, encoding: .utf8),
          depsSrc.contains(depsMarker) else {
      die("marker not found in TargetDependency+Named.swift\n  Expected: \(depsMarker)")
    }
  }

  // Scaffold client first if requested
  var clientDepToken = ""
  if let clientBase = withClient {
    print("→ Scaffolding paired client: \(clientBase)Client")
    fflush(stdout)
    scaffoldClient(base: clientBase, projectRoot: projectRoot)
    clientDepToken = ", .\(lowerFirst(clientBase))Client"
  }

  // Scaffold feature
  writeFile(featureReducerTemplate(featureName), to: "\(featureDir)/Sources/\(featureName).swift")
  writeFile(featureViewTemplate(featureName, viewName: viewName), to: "\(featureDir)/Sources/\(viewName).swift")
  writeFile(featureReducerTestsTemplate(featureName), to: "\(featureDir)/Tests/\(featureName)Tests.swift")
  writeFile(featureViewTestsTemplate(featureName, viewName: viewName), to: "\(featureDir)/Tests/\(viewName)Tests.swift")

  insertAboveMarker(
    line: "  FeatureTargetBuilder(\"\(featureName)\", dependencies: [.composableArchitecture, .designSystem\(clientDepToken)]),",
    marker: featureMarker,
    inFile: projectFile
  )

  printGreen("Created \(featureName)")
  printGreen("Wired into Project.swift")
  if let clientBase = withClient {
    printGreen("Linked \(clientBase)Client as dependency")
  }
  print("")
  print("  Run: make")
}

private func scaffoldClient(base: String, projectRoot: String) {
  let fm = FileManager.default
  let clientName = "\(base)Client"
  let depKey = lowerFirst(base) + "Client"
  let clientDir = "\(projectRoot)/Features/\(clientName)"
  let projectFile = "\(projectRoot)/Project.swift"
  let depsFile = "\(projectRoot)/Tuist/ProjectDescriptionHelpers/TargetDependency+Named.swift"
  let featureMarker = "// tuist-marker: insert new features above this line"
  let depsMarker = "// tuist-marker: insert new client deps above this line"

  guard !fm.fileExists(atPath: clientDir) else {
    die("'\(clientName)' already exists at Features/\(clientName)")
  }

  writeFile(interfaceTemplate(clientName), to: "\(clientDir)/Sources/Interface.swift")
  writeFile(liveKeyTemplate(clientName), to: "\(clientDir)/Sources/LiveKey.swift")
  writeFile(testKeyTemplate(clientName, depKey: depKey), to: "\(clientDir)/Sources/TestKey.swift")
  writeFile(clientTestsTemplate(clientName), to: "\(clientDir)/Tests/\(clientName)Tests.swift")

  insertAboveMarker(
    line: "  static let \(depKey): Self = .target(name: \"\(clientName)\")",
    marker: depsMarker,
    inFile: depsFile
  )
  insertAboveMarker(
    line: "  FeatureTargetBuilder(\"\(clientName)\", dependencies: [.composableArchitecture]),",
    marker: featureMarker,
    inFile: projectFile
  )

  printGreen("Created \(clientName)")
  printGreen("Wired into Project.swift + TargetDependency+Named.swift (.\(depKey))")
}

// MARK: - Entry point

import PackagePlugin

@main struct NewFeaturePlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) throws {
    let args = arguments.filter { $0 != "--" }
    guard let base = args.first, !base.isEmpty else {
      Diagnostics.error("Usage: swift package new-feature -- <Name> [--with-client <Name>]")
      return
    }
    var withClient: String? = nil
    if let flagIdx = args.firstIndex(of: "--with-client"), flagIdx + 1 < args.count {
      withClient = args[flagIdx + 1]
    }
    scaffoldNewFeature(base: base, withClient: withClient, projectRoot: context.package.directory.string)
  }
}
