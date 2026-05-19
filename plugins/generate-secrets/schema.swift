// Configure the secrets generator here.
//
// Each entry maps a .env key to its destination file.
// The generator groups entries by destination and writes one file per unique path.
// The Swift enum name is derived from the filename (e.g. Secrets.swift → enum Secrets).
//
// To move a key into a specific feature:
//   SecretEntry(envKey: "WEATHER_API_KEY",
//               destination: "Features/WeatherFeature/Sources/Generated/WeatherSecrets.swift")
enum Schema {
  struct SecretEntry {
    let envKey: String       // Key in .env file (SCREAMING_SNAKE_CASE)
    let destination: String  // Path relative to app/ root, including filename
  }

  static let secrets: [SecretEntry] = [
    SecretEntry(envKey: "EXAMPLE_API_KEY",  destination: "App/Sources/Generated/Secrets.swift"),
    SecretEntry(envKey: "BACKEND_BASE_URL", destination: "App/Sources/Generated/Secrets.swift"),
  ]
}
