import Foundation

// MARK: - Utilities

func printGreen(_ s: String) { print("\u{1B}[32m✓ \(s)\u{1B}[0m") }
func printYellow(_ s: String) { print("\u{1B}[33m⚠ \(s)\u{1B}[0m") }
func die(_ msg: String) -> Never { fputs("✗ \(msg)\n", stderr); exit(1) }

// MARK: - Helpers

func toCamelCase(_ key: String) -> String {
  let parts = key.lowercased().components(separatedBy: "_").filter { !$0.isEmpty }
  guard let first = parts.first else { return "" }
  return first + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
}

func swiftEscape(_ value: String) -> String {
  value
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
}

func parseEnvValues(_ content: String) -> [String: String] {
  var result: [String: String] = [:]
  for line in content.components(separatedBy: "\n") {
    let l = line.hasSuffix("\r") ? String(line.dropLast()) : line
    guard !l.trimmingCharacters(in: .whitespaces).hasPrefix("#"),
          !l.trimmingCharacters(in: .whitespaces).isEmpty,
          let eqIdx = l.firstIndex(of: "=") else { continue }
    let key = String(l[..<eqIdx]).trimmingCharacters(in: .whitespaces)
    let value = String(l[l.index(after: eqIdx)...])
    guard !key.isEmpty else { continue }
    result[key] = value
  }
  return result
}

// MARK: - Core logic

func runGenerateSecrets(projectRoot: String) {
  let fm = FileManager.default
  let envPath = "\(projectRoot)/.env"
  let envExamplePath = "\(projectRoot)/.env.example"

  let sourcePath: String
  if fm.fileExists(atPath: envPath) {
    sourcePath = envPath
  } else if fm.fileExists(atPath: envExamplePath) {
    printYellow(".env not found — generating Secrets with empty values from .env.example")
    printYellow("  Copy .env.example to .env and fill it in: cp .env.example .env")
    sourcePath = envExamplePath
  } else {
    die("neither .env nor .env.example found — cannot generate Secrets")
  }

  let rawEnv = (try? String(contentsOfFile: sourcePath, encoding: .utf8)) ?? ""
  let envValues = parseEnvValues(rawEnv)

  // Warn about keys in .env not declared in schema
  let schemaKeys = Set(Schema.secrets.map { $0.envKey })
  for key in envValues.keys.sorted() where !schemaKeys.contains(key) {
    printYellow("'\(key)' in .env is not declared in schema — skipping")
  }

  // Group schema entries by destination (preserving declaration order within each group)
  var groups: [(destination: String, entries: [Schema.SecretEntry])] = []
  var seen: [String: Int] = [:]
  for entry in Schema.secrets {
    if let idx = seen[entry.destination] {
      groups[idx].entries.append(entry)
    } else {
      seen[entry.destination] = groups.count
      groups.append((destination: entry.destination, entries: [entry]))
    }
  }

  // Generate one file per destination
  for group in groups {
    let enumName = URL(fileURLWithPath: group.destination).deletingPathExtension().lastPathComponent
    let outputURL = URL(fileURLWithPath: projectRoot).appendingPathComponent(group.destination)

    var content = """
    // AUTO-GENERATED — DO NOT EDIT BY HAND.
    // Managed via plugins/generate-secrets/schema.swift
    // Run `make secrets` (or `make`) to regenerate.

    import Foundation

    enum \(enumName) {

    """
    for entry in group.entries {
      let camel = toCamelCase(entry.envKey)
      let value = swiftEscape(envValues[entry.envKey] ?? "")
      content += "  static let \(camel): String = \"\(value)\"\n"
    }
    content += "}\n"

    try? fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    if let existing = try? String(contentsOf: outputURL, encoding: .utf8), existing == content {
      printGreen("\(outputURL.lastPathComponent) already up to date")
      continue
    }
    guard (try? content.write(to: outputURL, atomically: true, encoding: .utf8)) != nil else {
      die("could not write \(outputURL.path)")
    }
    printGreen("Generated \(group.destination) (\(group.entries.count) key(s))")
  }
}

// MARK: - Entry point

import PackagePlugin

@main struct GenerateSecretsPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) throws {
    runGenerateSecrets(projectRoot: context.package.directory.string)
  }
}
