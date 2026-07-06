import Model
import WebKit
import Automation
import SwiftUI
import UniformTypeIdentifiers

struct NaviBottomTabView: View {
    @Bindable var store: Browser

    var body: some View {
        TabView(selection: selection) {
            Color.clear
                .tabItem {
                    Label("Script", systemImage: "doc.text")
                }
                .tag(Browser.NaviPanelSelection.script)
            Color.clear
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
                .tag(Browser.NaviPanelSelection.log)
            Color.clear
                .tabItem {
                    Label("Processados", systemImage: "checklist")
                }
                .tag(Browser.NaviPanelSelection.processed)
        }
        .frame(height: 72)
        .background(Color(.systemBackground))
    }

    private var selection: Binding<Browser.NaviPanelSelection> {
        Binding {
            store.naviPanelSelection
        } set: { newValue in
            Task {
                await store.send(.naviPanelSelectionChanged(newValue))
            }
        }
    }
}

struct NaviPanelView: View {
    @Bindable var store: Browser
    @State var am = AutomationManager()
    @State private var processedText: String = ""
    @State private var queue: NaviQueue<String> = NaviQueue<String>()
    @State private var LIKE_SCRIPT = ""

    
    var body: some View {
        NavigationStack {
            Group {
                switch store.naviPanelSelection {
                case .script:
                    scriptView
                case .log:
                    dataView(
                        text: $store.logText,
                        clearAction: .clearLogButtonTapped
                    )
                case .processed:
                    dataView(
                        text: $processedText,
                        clearAction: .clearProcessedButtonTapped
                    )
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .fileImporter(
            isPresented: $store.isPresentedScriptImporter,
            allowedContentTypes: [.naviScript],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            Task {
                await store.send(.scriptFileImported(url))
            }
        }
        .sheet(isPresented: $store.isPresentedScriptSelection) {
            ScriptSelectionView(store: store)
        }
        .alert("Salvar script", isPresented: $store.isPresentedScriptSaveDialog) {
            TextField("Nome do arquivo", text: $store.pendingScriptFileName)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") {
                Task {
                    await store.send(.scriptSaveConfirmed)
                }
            }
        }
    }

    private var scriptView: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await store.send(.scriptNewButtonTapped)
                        }
                    } label: {
                        Label("Novo", systemImage: "plus")
                    }

                    Button {
                        Task {
                            await store.send(.scriptSaveButtonTapped)
                        }
                    } label: {
                        Label("Salvar", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        Task {
                            await store.send(.scriptLoadButtonTapped)
                        }
                    } label: {
                        Label("Carregar", systemImage: "folder")
                    }

                    Button {
                        Task {
//                            await store.send(.scriptRunButtonTapped)

                            let cookies = await getBrowserCookies()
                            
                            if cookies.isEmpty {
                                store.inputText = "shopee.com.br"
                                await store.send(.onSubmit("shopee.com.br"))
                            }
                            
                            while cookies.isEmpty {
                                store.updateLog(with: "Waiting for cookies...\n")
                                try? await Task.sleep(for: .seconds(5))
                            }
                            
                            print("script \(store.scriptText)")
                            let config: String = store.scriptText
                            
                            am.start(naviConfig: config, cookieList: cookies)
                                                        
                            for await event in am.actionEvents {
                                switch event {
                                case .openPage(let codigo, let url, let script):
                                    print("Open page: \(codigo) - \(url)")
                                    processedText.append(contentsOf:  "\n\(codigo)")
                                    
                                    if LIKE_SCRIPT.isEmpty {
                                        LIKE_SCRIPT.append(script)
                                    }
                                    
                                    await queue.enqueue(url)
                                }
                                
                                
                            }
                        }
                        Task {
                            await naviProcessamento()
                        }
                    } label: {
                        Label("Rodar", systemImage: "play.fill")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            TextEditor(text: $store.scriptText)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(8)

            messageView
        }
    }
    
    func getBrowserCookies() async -> String {
        
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        print("cookie")
        var todosOsCookies: String = ""
        
        let cookies = await cookieStore.allCookies()
        for cookie in cookies {
            //if (cookie.domain.contains(site))
            todosOsCookies.append(contentsOf: "\((cookie.name))=\(cookie.value);")
        }
        print(todosOsCookies)

        return todosOsCookies
    }
    
    func naviProcessamento() async {
        print("NAVI: vai")
        
        var isLoadingPage = false
        while !Task.isCancelled {
            print("NAVI: esperando")
            try? await Task.sleep(for: .seconds(1))
            if await !queue.isEmpty && !isLoadingPage {
                isLoadingPage = true
                let url = await queue.dequeue()
                
                print("NAVI: abrindo pagina: \(url ?? "0")")
                
                store.inputText = url ?? "0"
                await store.send(.onSubmit(url ?? "0"))
            }
            
            if isLoadingPage && store.isPaginaFoiCarregada {
                try? await Task.sleep(for: .seconds(1))
                
                print("NAVI: rodando script")
                store.scriptText = LIKE_SCRIPT
                await store.send(.scriptRunButtonTapped)
                
                store.isPaginaFoiCarregada = false
                isLoadingPage = false
            }
            
            //am.allJobs.forEach { item in
            //    print("itens na lista: \(item)")
            //}
            //let tempArray = am.allJobs
            //store.processedText = "\(tempArray)"
        }
    }

    private func dataView(text: Binding<String>, clearAction: Browser.Action) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(role: .destructive) {
                    Task {
                        await store.send(clearAction)
                    }
                } label: {
                    Label("Limpar", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .disabled(true)

            messageView
        }
    }

    @ViewBuilder
    private var messageView: some View {
        if let message = store.naviPanelMessage, !message.isEmpty {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
        }
    }

    private var title: String {
        switch store.naviPanelSelection {
        case .script:
            store.scriptFileName
        case .log:
            "Log"
        case .processed:
            "Processados"
        }
    }
}

private extension UTType {
    static var naviScript: UTType {
        UTType(filenameExtension: "navi") ?? .data
    }
}

#Preview {
    NaviPanelView(store: .init(.testDependencies()))
}
