import Foundation

public enum Appearance: String, Hashable, Sendable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var label: String { rawValue }
}
