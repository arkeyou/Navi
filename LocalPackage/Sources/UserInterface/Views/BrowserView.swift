import DataSource
import Model
import SwiftUI
import WebUI

struct BrowserView: View {
    @StateObject var store: Browser
    @State private var naviPanelDetent = PresentationDetent.height(240)
    @AppStorage(.appearance) private var appearance = Appearance.dark.rawValue
    
    @Environment(\.horizontalSizeClass) var tamanhoTela
    
    var body: some View {
        //Adaptar o estilo de exibicao ao tamanho da tela
        if tamanhoTela == .regular {
            HStack(spacing: 0) {
                mainContent
                
                naviPanelSheet
                    .frame(maxWidth: 320)
                    .labelStyle(.iconOnly)
            }
        } else {
            mainContent
                .sheet(isPresented: $store.isPresentedNaviPanel) {
                    naviPanelSheet
             }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        Appearance(rawValue: appearance)?.colorScheme
    }

    private var paywallPresentation: Binding<Bool> {
        Binding {
            store.isPresentedPaywall && !store.isPresentedNaviPanel
        } set: { isPresented in
            store.isPresentedPaywall = isPresented
        }
    }

    private var mainContent: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .bottomTrailing) {
                    WebViewReader { proxy in
                        VStack(spacing: 0) {
                            ProgressView(value: proxy.estimatedProgress)
                                .opacity(proxy.isLoading ? 1.0 : 0.0)
                            WebView(configuration: .forNavi)
                                .navigationDelegate(store.navigationDelegate)
                                .uiDelegate(store.uiDelegate)
                                .refreshable()
                                .allowsBackForwardNavigationGestures(true)
                                .allowsOpaqueDrawing(proxy.url != nil)
                                .allowsInspectable(true)
                                .pageScaleFactor(store.pageScale.value)
                                .overlay {
                                    if proxy.url == nil {
                                        LogoView()
                                    }
                                }
                        }
                        .background(Color(.secondarySystemBackground))
                        .toolbar {
                            Header(
                                store: store,
                                availableWidth: geometry.size.width,
                                safeAreaLeading: geometry.safeAreaInsets.leading,
                                safeAreaTrailing: geometry.safeAreaInsets.trailing
                            )
                        }
                        .toolbarBackground(Color(.header), for: .navigationBar)
                        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
                        .toolbarVisibility(store.isPresentedToolbar ? .visible : .hidden, for: .navigationBar)
                        .navigationBarTitleDisplayMode(.automatic)
                        .environment(\.canGoBack, proxy.canGoBack)
                        .environment(\.canGoForward, proxy.canGoForward)
                        .task {
                            await store.send(.task(
                                String(describing: Self.self),
                                .init(getResourceURL: { Bundle.module.url(forResource: $0, withExtension: $1) }),
                                proxy
                            ))
                        }
                        .onChange(of: proxy.url) { _, newValue in
                            Task {
                                await store.send(.onChangeURL(newValue))
                            }
                        }
                        .onChange(of: proxy.title) { _, newValue in
                            Task {
                                await store.send(.onChangeTitle(newValue))
                            }
                        }
                        .onChange(of: proxy.isLoading) { _, newValue in
                            Task {
                                await store.send(.onChangeIsLoading(newValue))
                            }
                        }
                        if !store.isPresentedToolbar {
                            ShowToolbarButton(store: store)
                                .padding(20)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .ignoresSafeArea(.container, edges: store.isPresentedToolbar ? [] : .all)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .sheet(item: $store.settings, onDismiss: {
            store.isPresentedNaviPanel = true
        }) { store in
            SettingsView(store: store)
                .preferredColorScheme(store.appearance.colorScheme)
        }
        .sheet(item: $store.bookmarkManagement, onDismiss: {
            store.isPresentedNaviPanel = true
        }) { store in
            BookmarkManagementView(store: store)
                .preferredColorScheme(preferredColorScheme)
        }
        .sheet(isPresented: paywallPresentation) {
            PaywallView(store: store)
                .preferredColorScheme(preferredColorScheme)
        }
        .webDialog(
            isPresented: $store.isPresentedWebDialog,
            presenting: store.webDialog,
            promptInput: $store.promptInput,
            okButtonTapped: { await store.send(.dialogOKButtonTapped) },
            cancelButtonTapped: { await store.send(.dialogCancelButtonTapped) },
            onChangeIsPresented: { await store.send(.onChangeIsPresentedWebDialog($0)) }
        )
        .externalAppConfirmationDialog(
            isPresented: $store.isPresentedConfirmationDialog,
            presenting: store.customSchemeURL,
            okButtonTapped: { await store.send(.confirmButtonTapped($0)) }
        )
        .alert(
            Text("failedToOpenExternalApp", bundle: .module),
            isPresented: $store.isPresentedAlert,
            actions: {}
        )
        .onOpenURL { url in
            Task {
                await store.send(.onOpenURL(url))
            }
        }
        .animation(.easeIn(duration: 0.2), value: store.isPresentedToolbar)
        .frame(maxWidth: .infinity)
    }

    private var naviPanelSheet: some View {
        NaviPanelView(store: store)
        .presentationDetents([.height(240), .medium, .large], selection: $naviPanelDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled()
        .preferredColorScheme(preferredColorScheme)
    }
}

extension Browser: ObservableObject {}
extension BrowserNavigation: ObservableObject {}
extension BrowserUI: ObservableObject {}

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

#Preview(traits: .landscapeRight) {
    BrowserView(store: .init(.testDependencies()))
}
