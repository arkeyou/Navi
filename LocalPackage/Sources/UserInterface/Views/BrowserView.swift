import Model
import SwiftUI
import WebUI

struct BrowserView: View {
    @StateObject var store: Browser
    @State private var naviPanelDetent = PresentationDetent.medium
    
    var body: some View {
        mainContent
            .sheet(isPresented: $store.isPresentedNaviPanel) {
                naviPanelSheet
            }
            .sheet(item: $store.settings) { store in
                SettingsView(store: store)
            }
            .sheet(item: $store.bookmarkManagement) { store in
                BookmarkManagementView(store: store)
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
    }

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            WebViewReader { proxy in
                VStack(spacing: 0) {
                    if store.isPresentedToolbar {
                        Header(store: store)
                            .transition(.move(edge: .top))
                            .environment(\.isLoading, proxy.isLoading)
                            .environment(\.estimatedProgress, proxy.estimatedProgress)
                            .environment(\.canGoBack, proxy.canGoBack)
                            .environment(\.canGoForward, proxy.canGoForward)
                    }
                    WebView(configuration: .forTelescopure)
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
        }
        .ignoresSafeArea(.container, edges: store.isPresentedToolbar ? [] : .all)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var naviPanelSheet: some View {
        VStack(spacing: 0) {
            NaviPanelView(store: store)
            NaviBottomTabView(store: store)
        }
        .presentationDetents([.height(240), .medium, .large], selection: $naviPanelDetent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled()
    }
}

extension Browser: ObservableObject {}
extension BrowserNavigation: ObservableObject {}
extension BrowserUI: ObservableObject {}

#Preview(traits: .landscapeRight) {
    BrowserView(store: .init(.testDependencies()))
}
