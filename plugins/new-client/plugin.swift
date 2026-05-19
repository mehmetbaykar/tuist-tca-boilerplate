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

// MARK: - Templates

func interfaceTemplate(_ clientName: String) -> String {
  #"""
  import ComposableArchitecture

  @DependencyClient
  public struct \#(clientName): Sendable {
    // Define your endpoints here:
    // public var fetchSomething: @Sendable () async throws -> String
  }
  """#
}

func liveKeyTemplate(_ clientName: String) -> String {
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

func testKeyTemplate(_ clientName: String, depKey: String) -> String {
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

func clientTestsTemplate(_ clientName: String) -> String {
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

func scaffoldNewClient(base: String, projectRoot: String) {
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
  guard let projectSrc = try? String(contentsOfFile: projectFile, encoding: .utf8),
        projectSrc.contains(featureMarker) else {
    die("marker not found in Project.swift\n  Expected: \(featureMarker)")
  }
  guard let depsSrc = try? String(contentsOfFile: depsFile, encoding: .utf8),
        depsSrc.contains(depsMarker) else {
    die("marker not found in TargetDependency+Named.swift\n  Expected: \(depsMarker)")
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
  print("")
  print("  Add to dependents:")
  print("    dependencies: [..., .\(depKey)]")
  print("")
  print("  Run: make")
}

// MARK: - Entry point

import PackagePlugin

@main struct NewClientPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) throws {
    let args = arguments.filter { $0 != "--" }
    guard let base = args.first, !base.isEmpty else {
      Diagnostics.error("Usage: swift package new-client -- <Name>")
      return
    }
    scaffoldNewClient(base: base, projectRoot: context.package.directory.string)
  }
}
