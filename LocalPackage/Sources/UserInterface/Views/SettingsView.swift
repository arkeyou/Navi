import DataSource
import Model
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.appDependencies) private var appDependencies
    @State var store: Settings
    @State private var isPresentedPaywall = false

    var body: some View {
        NavigationStack(path: $store.path) {
            List {
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
                    intervalRow(
                        title: "Verifica Live Online",
                        subtitle: "Tempo entre verificações para confirmar se a live está online.",
                        value: $store.monitorLiveOnlineInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeMonitorLiveOnlineInterval(newValue)) }
                        }
                    )
                    intervalRow(
                        title: "Monitora Mensagens (MONITOR)",
                        subtitle: "Tempo entre leituras de novas mensagens durante a automação.",
                        value: $store.monitorInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeMonitorInterval(newValue)) }
                        }
                    )
                    intervalRow(
                        title: "Processa Codigos Validados (FLOW)",
                        subtitle: "Espera antes de processar códigos que já foram validados.",
                        value: $store.idsWaitInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeIdsWaitInterval(newValue)) }
                        }
                    )
                    intervalRow(
                        title: "Verifica Tela (ACTION)",
                        subtitle: "Intervalo usado para aguardar e conferir mudanças na tela.",
                        value: $store.likeWaitInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeLikeWaitInterval(newValue)) }
                        }
                    )
                    intervalRow(
                        title: "Espera Cookie",
                        subtitle: "Tempo máximo de espera para carregar ou detectar cookies necessários.",
                        value: $store.cookieWaitInterval,
                        onChange: { newValue in
                            Task { await store.send(.onChangeCookieWaitInterval(newValue)) }
                        }
                    )
                } header: {
                    Text("Intervalos de Automação (segundos)")
                }
                
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
                                await store.send(.clearCacheButtonTapped)
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
        subtitle: String,
        value: Binding<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SelectAllNumberTextField(value: value, onChange: onChange)
                .frame(width: 80)
        }
    }

}

private struct SelectAllNumberTextField: UIViewRepresentable {
    @Binding var value: Double
    let onChange: (Double) -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self

        guard !textField.isFirstResponder else { return }
        textField.text = formattedValue
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private var formattedValue: String {
        Self.formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 6
        return formatter
    }()

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectAllNumberTextField

        init(parent: SelectAllNumberTextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        @objc func textDidChange(_ textField: UITextField) {
            guard let text = textField.text,
                  let newValue = parseValue(text),
                  newValue != parent.value
            else { return }

            parent.value = newValue
            parent.onChange(newValue)
        }

        private func parseValue(_ text: String) -> Double? {
            if let number = SelectAllNumberTextField.formatter.number(from: text) {
                return number.doubleValue
            }

            return Double(text.replacingOccurrences(of: ",", with: "."))
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
