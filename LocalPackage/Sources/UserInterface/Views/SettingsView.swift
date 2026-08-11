import DataSource
import Model
import SwiftUI

struct SettingsView: View {
    @Environment(\.appDependencies) private var appDependencies
    @State var store: Settings
    @State private var isPresentedPaywall = false

    var body: some View {
        NavigationStack(path: $store.path) {
            List {
                Section {
                    Picker(selection: $store.appearance) {
                        ForEach(Appearance.allCases, id: \.self) { appearance in
                            Text(appearance.label)
                                .tag(appearance)
                        }
                    } label: {
                        Label {
                            Text("Appearance")
                        } icon: {
                            Image(systemName: "circle.lefthalf.filled")
                        }
                    }

                    /*Button {
                        Task {
                            await store.send(.defaultBrowserAppButtonTapped)
                        }
                    } label: {
                        LabeledContent {
                            Image(systemName: "chevron.right")
                        } label: {
                            Label {
                                Text("defaultBrowserApp", bundle: .module)
                                    .foregroundStyle(Color.primary)
                            } icon: {
                                Image(systemName: "app.badge.checkmark")
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    Button {
                        Task {
                            await store.send(.searchEngineSettingButtonTapped(appDependencies))
                        }
                    } label: {
                        LabeledContent {
                            HStack {
                                Text(store.searchEngine.label)
                                Image(systemName: "chevron.right")
                            }
                        } label: {
                            Label {
                                Text("searchEngine", bundle: .module)
                                    .foregroundStyle(Color.primary)
                            } icon: {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
                    .buttonStyle(.borderless)*/
                    LabeledContent {
                        Button(role: .destructive) {
                            Task {
                                await store.send(.crearCacheButtonTapped)
                            }
                        } label: {
                            Text("clear", bundle: .module)
                        }
                        .buttonStyle(.borderless)
                    } label: {
                        Label {
                            Text("cache", bundle: .module)
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                } header: {
                    Text("settings", bundle: .module)
                }

                Section {
                    intervalRow(
                        title: "Verifica Live Online",
                        value: $store.monitorLiveOnlineInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeMonitorLiveOnlineInterval(newValue)) }
                        }
                    )
                    intervalRow(
                        title: "Monitora Mensagens",
                        value: $store.monitorInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeMonitorInterval(newValue)) }
                        }
                    )
                    intervalRow(
                        title: "Processa Codigos Validados",
                        value: $store.idsWaitInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeIdsWaitInterval(newValue)) }
                        }
                    )
                    intervalRow(
                        title: "Verifica Tela",
                        value: $store.likeWaitInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeLikeWaitInterval(newValue)) }
                        }
                    )
                    intervalRow(
                        title: "Espera Cookie",
                        value: $store.cookieWaitInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeCookieWaitInterval(newValue)) }
                        }
                    )
                } header: {
                    Text("Intervalos de Automação (s)")
                }

                Section {
                    Button {
                        isPresentedPaywall = true
                    } label: {
                        LabeledContent {
                            HStack {
                                Text(NaviQueueTracker.shared.isSubscribed ? "Ativa" : "Ver planos")
                                    .foregroundStyle(NaviQueueTracker.shared.isSubscribed ? Color.green : Color.secondary)
                                Image(systemName: "chevron.right")
                            }
                        } label: {
                            Label {
                                Text("Assinatura Navi Premium")
                                    .foregroundStyle(Color.primary)
                            } icon: {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.purple)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("Assinatura & IAP")
                }
                Section {
                    LabeledContent {
                        Text(store.version)
                    } label: {
                        Label {
                            Text("Navi version", bundle: .module)
                        } icon: {
                            Image(systemName: "number")
                        }
                    }
                    LabeledContent {
                        Text("2.5.0")
                    } label: {
                        Label {
                            Text("Telescopure version", bundle: .module)
                        } icon: {
                            Image(systemName: "number")
                        }
                    }
                    /*LabeledContent {
                        Text(store.developer)
                    } label: {
                        Label {
                            Text("developer", bundle: .module)
                        } icon: {
                            Image(systemName: "hammer")
                        }
                    }
                    Button {
                        Task {
                            await store.send(.openRepositoryButtonTapped)
                        }
                    } label: {
                        LabeledContent {
                            Image(systemName: "link")
                                .foregroundStyle(Color.accentColor)
                        } label: {
                            Label {
                                Text("repository", bundle: .module)
                                    .foregroundStyle(Color.primary)
                            } icon: {
                                Image(systemName: "shippingbox")
                            }
                        }
                    }
                    .buttonStyle(.borderless)*/
                    Button {
                        Task {
                            await store.send(.licensesButtonTapped(appDependencies))
                        }
                    } label: {
                        LabeledContent {
                            Image(systemName: "chevron.right")
                        } label: {
                            Label {
                                Text("licenses", bundle: .module)
                                    .foregroundStyle(Color.primary)
                            } icon: {
                                Image(systemName: "building.columns")
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("information", bundle: .module)
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Settings.Path.self) { path in
                switch path {
                case let .searchEngineSetting(store):
                    SearchEngineSettingView(store: store)

                case let .licenses(store):
                    LicensesView(store: store)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await store.send(.doneButtonTapped)
                        }
                    } label: {
                        Text("done", bundle: .module)
                    }
                    .accessibilityIdentifier("doneSettingsButton")
                }
            }
        }
        .sheet(isPresented: $isPresentedPaywall) {
            PaywallView()
                .preferredColorScheme(store.appearance.colorScheme)
        }
        .preferredColorScheme(store.appearance.colorScheme)
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
        .onChange(of: store.appearance) { _, newValue in
            Task {
                await store.send(.onChangeAppearance(newValue))
            }
        }
    }

    @ViewBuilder
    private func intervalRow(
        title: String,
        value: Binding<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        LabeledContent(title) {
            TextField("", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 80)
                .onChange(of: value.wrappedValue) { _, newValue in
                    onChange(newValue)
                }
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

#Preview {
    SettingsView(store: .init(.testDependencies(), id: UUID(), action: { _ in }))
}
