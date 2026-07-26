import DataSource
import Model
import SwiftUI

struct Header: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.isLoading) private var isLoading
    @Environment(\.estimatedProgress) private var estimatedProgress
    @Environment(\.canGoBack) private var canGoBack
    @Environment(\.canGoForward) private var canGoForward
    @State private var didReceiveNaviRunningUpdate = false
    var store: Browser

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
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
                .buttonStyle(.toolbar)
                .disabled(!canGoBack)
                .accessibilityIdentifier("goBackButton")
                Button {
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
                .buttonStyle(.toolbar)
                .disabled(!canGoForward)
                .accessibilityIdentifier("goForwardButton")
                SearchBar(store: store)
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
                .buttonStyle(.borderless)
                .tint(Color(.systemGray))
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
                .buttonStyle(.borderless)
                .tint(Color(.systemGray))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color(.header))
            ProgressView(value: estimatedProgress)
                .opacity(isLoading ? 1.0 : 0.0)
        }
        .onChange(of: store.naviIsRunning) { _, _ in
            didReceiveNaviRunningUpdate = true
        }
    }

    private var naviPanelIconStatusColor: Color {
        guard didReceiveNaviRunningUpdate else { return .primary }
        return store.naviIsRunning ? .green : .red
    }
}

#Preview {
    Header(store: .init(.testDependencies()))
}
