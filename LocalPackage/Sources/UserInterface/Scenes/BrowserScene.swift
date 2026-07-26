import DataSource
import Model
import SwiftUI

public struct BrowserScene: Scene {
    @Environment(\.appDependencies) private var appDependencies
    @AppStorage(.appearance) private var appearance = Appearance.dark.rawValue

    public init() {}

    public var body: some Scene {
        WindowGroup {
            BrowserView(store: .init(appDependencies))
                .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
        }
    }
}

private extension Appearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
