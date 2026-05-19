import SwiftUI

public struct DesignFonts: Equatable, Sendable {
  public let hero: Font // big number/temperature display
  public let title: Font // screen titles
  public let subtitle: Font // section headers
  public let body: Font // default reading text
  public let note: Font // smaller, muted
  public let caption: Font // metadata, smallest

  // Defaults are text-style-based so they scale automatically with the user's
  // Dynamic Type setting (HIG-mandated accessibility). For pixel-precise display
  // fonts (e.g. a giant temperature readout), override at init with
  // `Font.custom("MyFont", size: 64, relativeTo: .largeTitle)`.
  public init(
    hero: Font = .system(.largeTitle, design: .serif).weight(.semibold),
    title: Font = .system(.title).weight(.semibold),
    subtitle: Font = .system(.title3).weight(.medium),
    body: Font = .system(.body),
    note: Font = .system(.subheadline),
    caption: Font = .system(.caption)
  ) {
    self.hero = hero
    self.title = title
    self.subtitle = subtitle
    self.body = body
    self.note = note
    self.caption = caption
  }

  public static let `default` = DesignFonts()
}
