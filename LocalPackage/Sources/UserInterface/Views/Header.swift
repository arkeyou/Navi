import DataSource
import Model
import SwiftUI

struct Header: ToolbarContent {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.canGoBack) private var canGoBack
    @Environment(\.canGoForward) private var canGoForward
    var store: Browser
    var availableWidth: CGFloat = 0
    var safeAreaLeading: CGFloat = 0
    var safeAreaTrailing: CGFloat = 0

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                Task {
                    store.isPresentedNaviPanel = false
                    await store.send(.bookmarkButtonTapped(appDependencies))
                }
            } label: {
                Label {
                    Text("openBookmarks", bundle: .module)
                } icon: {
                    Image(systemName: "book")
                }
            }
            .accessibilityIdentifier("openBookmarksButton")

            Button {
                Task {
                    await store.send(.goBackButtonTapped)
                }
            } label: {
                Label {
                    Text("goBack", bundle: .module)
                } icon: {
                    Image(systemName: "chevron.backward")
                }
            }
            .disabled(!canGoBack)
            .accessibilityIdentifier("goBackButton")

            /*Button {
                Task {
                    await store.send(.goForwardButtonTapped)
                }
            } label: {
                Label {
                    Text("goForward", bundle: .module)
                } icon: {
                    Image(systemName: "chevron.forward")
                }
            }
            .disabled(!canGoForward)
            .accessibilityIdentifier("goForwardButton")*/
        }

        ToolbarItem(placement: .principal) {
            SearchBar(store: store)
                //.frame(width: searchBarWidth)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            NaviPanelButton(store: store)

            Button {
                Task {
                    store.isPresentedNaviPanel = false
                    await store.send(.settingsButtonTapped(appDependencies))
                }
            } label: {
                Label {
                    Text("openSettings", bundle: .module)
                } icon: {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                }
                .labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("openSettingsButton")
        }
    }

    private var searchBarWidth: CGFloat? {
        guard availableWidth > 0 else { return nil }
        let leadingOccupied = safeAreaLeading + 108
        let trailingOccupied = max(safeAreaTrailing, 16) + 88
        let sideOccupied = max(leadingOccupied, trailingOccupied) + 10
        let calculatedWidth = availableWidth - 2 * sideOccupied
        let maxPossibleWidth = availableWidth - (leadingOccupied + trailingOccupied + 16)
        guard maxPossibleWidth > 60 else { return nil }
        return max(60, min(calculatedWidth, maxPossibleWidth))
    }
}

private struct NaviPanelButton: View {
    var store: Browser
    @State private var didReceiveNaviRunningUpdate = false

    var body: some View {
        Button {
            Task {
                store.isPresentedNaviPanel.toggle()
            }
        } label: {
            Label {
                Text("openNaviPanel", bundle: .module)
            } icon: {
                Image(systemName: "list.bullet.clipboard")
                    //Image(systemName: "square.stack.3d.up")
                    //Image(systemName: "square.3.layers.3d.top.filled")
                    .imageScale(.large)
                    .foregroundStyle(.blue, naviPanelIconStatusColor)
                    .symbolEffect(.variableColor, options: .repeating, isActive: store.naviIsRunning)
            }
            .labelStyle(.iconOnly)
        }
        .tint(Color(.systemGray))
        .accessibilityIdentifier("openNaviPanelButton")
        .onChange(of: store.naviIsRunning) { _, _ in
            didReceiveNaviRunningUpdate = true
        }
    }

    private var naviPanelIconStatusColor: Color {
        guard didReceiveNaviRunningUpdate else { return .white }
        return store.naviIsRunning ? .green : .red
    }
}

#Preview {
    NavigationStack {
        Text("Preview")
            .toolbar {
                Header(store: .init(.testDependencies()))
            }
    }
}
