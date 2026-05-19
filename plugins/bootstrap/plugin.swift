import Foundation

// MARK: - Utilities

func printGreen(_ s: String) { print("\u{1B}[32m✓ \(s)\u{1B}[0m") }
func die(_ msg: String) -> Never { fputs("✗ \(msg)\n", stderr); exit(1) }

// MARK: - Helpers

func findInPath(_ cmd: String) -> String? {
  let paths = ProcessInfo.processInfo.environment["PATH"]?
    .components(separatedBy: ":") ?? []
  return paths.map { "\($0)/\(cmd)" }
    .first { FileManager.default.isExecutableFile(atPath: $0) }
}

@discardableResult
func run(_ execPath: String, _ args: [String]) -> Bool {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: execPath)
  p.arguments = args
  p.standardOutput = FileHandle.nullDevice
  p.standardError = FileHandle.nullDevice
  guard (try? p.run()) != nil else { return false }
  p.waitUntilExit()
  return p.terminationStatus == 0
}

func capture(_ execPath: String, _ args: [String]) -> String? {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: execPath)
  p.arguments = args
  let pipe = Pipe()
  p.standardOutput = pipe
  p.standardError = FileHandle.nullDevice
  guard (try? p.run()) != nil else { return nil }
  p.waitUntilExit()
  guard p.terminationStatus == 0 else { return nil }
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Main

@main struct Plugin {
  static func main() {
    let fm = FileManager.default
    let projectRoot = fm.currentDirectoryPath

    guard let rawVersion = try? String(contentsOfFile: "\(projectRoot)/.tuist-version", encoding: .utf8) else {
      die("could not read .tuist-version")
    }
    let tuistVersion = rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    let binDir = "\(projectRoot)/.tuist-bin"
    let tuistBin = "\(binDir)/tuist"

    try? fm.createDirectory(atPath: binDir, withIntermediateDirectories: true)

    if fm.fileExists(atPath: tuistBin), capture(tuistBin, ["version"]) == tuistVersion {
      printGreen("Tuist \(tuistVersion) already in .tuist-bin/")
      exit(0)
    }

    let downloadURL = "https://github.com/tuist/tuist/releases/download/\(tuistVersion)/tuist.zip"
    let tmpZip = "/tmp/tuist-\(tuistVersion).zip"
    print("→ Attempting download of Tuist \(tuistVersion)...")

    if let curl = findInPath("curl"),
       run(curl, ["-fsSL", "--max-time", "30", downloadURL, "-o", tmpZip]),
       let unzip = findInPath("unzip"),
       run(unzip, ["-q", "-o", tmpZip, "-d", binDir]) {
      try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tuistBin)
      try? fm.removeItem(atPath: tmpZip)
      printGreen("Tuist \(tuistVersion) installed to .tuist-bin/")
      exit(0)
    }

    print("→ Direct download unavailable (Tuist 4.x uses mise for distribution).")

    if let globalPath = findInPath("tuist"),
       let globalVersion = capture(globalPath, ["version"]) {
      if globalVersion == tuistVersion {
        try? fm.removeItem(atPath: tuistBin)
        try? fm.copyItem(atPath: globalPath, toPath: tuistBin)
        printGreen("Copied global Tuist \(tuistVersion) to .tuist-bin/")
        exit(0)
      }
      print("  Global Tuist is \(globalVersion), need \(tuistVersion).")
    }

    print("")
    fputs("✗ Could not install Tuist \(tuistVersion) locally.\n", stderr)
    print("  Options:")
    print("  1. Install via mise:    brew install mise && mise install tuist@\(tuistVersion)")
    print("  2. Use global tuist:    update .tuist-version to match your installed version")
    print("  3. Install via brew:    brew install tuist")
    exit(1)
  }
}
