import Model
import WebKit
import Automation
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

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
                .badge(store.hasUnreadLogs ? "" : nil)
            Color.clear
                .tabItem {
                    Label("Processados", systemImage: "checklist")
                }
                .tag(Browser.NaviPanelSelection.processed)
                .badge(store.hasUnreadProcessed ? store.qtProcessed : 0)
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
    @State private var runTask: Task<Void, Never>? = nil
    @State private var processingTask: Task<Void, Never>? = nil
    private let IDS_WAIT_INTERVAL = Duration.seconds(5)
    private let LIKE_WAIT_INTERVAL = Duration.seconds(0.5)
    private let COOKIE_WAIT_INTERVAL = Duration.seconds(5)
    private let URL_NPOINT_API = "https://api.npoint.io/"
    
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
                        text: $store.processedText,
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
        .onDisappear {
            stopAutomation()
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

                    if am.isRunning {
                        Button {
                            stopAutomation()
                        } label: {
                            Label("Parar", systemImage: "square.fill")
                        }
                    } else {
                        Button {
                            startAutomation()
                        } label: {
                            Label("Rodar", systemImage: "play.fill")
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            TextEditor(text: $store.scriptText)
                //.font(.system(.body, design: .monospaced))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(8)

            messageView
        }
    }
    
    private func startAutomation() {
        stopAutomation()
        
        var cookies = ""
        
        runTask = Task {
                        
            if cookies.isEmpty {
                cookies = await getBrowserCookies()
                if cookies.isEmpty {
                    store.inputText = "shopee.com.br"
                    await store.send(.onSubmit("shopee.com.br"))
                }
            }
            
            while cookies.isEmpty {
                if Task.isCancelled { return }
                store.updateLog(with: "Waiting for cookies...\n")
                cookies = await getBrowserCookies()
                try? await Task.sleep(for: COOKIE_WAIT_INTERVAL)
            }
            
            if Task.isCancelled { return }
            print("script \(store.scriptText)")
            var config: String = store.scriptText
                                    
            var configStruct = ConfigStruct()
            
            do {
                configStruct = try JSONDecoder().decode(ConfigStruct.self, from: Data(config.utf8))
                
                if configStruct.newVersion {
                    config = try await buscaConfiguracoes(npoint: configStruct.npoint ?? "", secret: configStruct.secret ?? "")
                }
            } catch {
                print(error)
                store.updateLog(with: "buscaConfiguracoes: \(error.localizedDescription)")
                stopAutomation()
                return
            }
            
            store.updateLog(with: "Iniciou automacao...\n")
            am.start(naviConfig: config, sessionId: configStruct.sessionId, cookieList: cookies)
                                        
            for await event in am.actionEvents {
                if Task.isCancelled { break }
                switch event {
                case .openPage(let codigo, let url, let script):
                    print("Open page: \(codigo) - \(url)")

                    store.updateProcessed(with: "\n\(codigo)")
                    
                    if LIKE_SCRIPT.isEmpty {
                        LIKE_SCRIPT.append(script)
                    }
                    
                    await queue.enqueue(url)
                }
            }
        }
        
        processingTask = Task {
            await naviProcessamentoTela()
        }
    }
    
    func buscaConfiguracoes(npoint: String, secret: String) async throws -> String {
        guard let url = URL(string: "\(URL_NPOINT_API)\(npoint)/hash") else { throw URLError(.badURL) }
        
        URLCache.shared.removeAllCachedResponses()
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
         
        do {
            let configHash = try JSONDecoder().decode(String.self, from: data)
            
            //let key = SymmetricKey(size: .bits256)
            let key = SymmetricKey(data: Data(secret.utf8))
            
            //let encrypted = try encrypt(text: configHash, using: key)
            //print(encrypted.base64EncodedString())
            
            let decrypted = try decrypt(data: Data(base64Encoded: configHash)!, using: key)
            //print(decrypted)
                
            return decrypted
        } catch {
            print(error.localizedDescription)
            throw error
        }
    }
    
    private func encrypt(text: String, using key: SymmetricKey) throws -> Data {
        let data = Data(text.utf8)

        let sealedBox = try AES.GCM.seal(data, using: key)

        guard let encryptedData = sealedBox.combined else {
            throw NSError(domain: "EncryptionError", code: -1)
        }

        return encryptedData
    }

    private func decrypt(data: Data, using key: SymmetricKey) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return String(decoding: decryptedData, as: UTF8.self)
    }
    
    private func stopAutomation() {
        runTask?.cancel()
        runTask = nil
        
        processingTask?.cancel()
        processingTask = nil
        
        am.stop()
        
        queue = NaviQueue<String>()
        LIKE_SCRIPT = ""
        
        store.updateLog(with: "Parou automacao!\n")

        print("Automation stopped and cleaned up.")
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
        //print(todosOsCookies)

        return todosOsCookies
    }
    
    func naviProcessamentoTela() async {
        print("NAVI: vai")
        
        var isLoadingPage = false
        while !Task.isCancelled {
            print("NAVI: esperando")
            let timestamp = ISO8601DateFormatter().string(from: Date())
            store.updateLog(with: "[\(timestamp)] Esperando ids...\n")

            try? await Task.sleep(for: IDS_WAIT_INTERVAL)
            if await !queue.isEmpty && !isLoadingPage {
                isLoadingPage = true
                let url = await queue.dequeue()
                
                print("NAVI: abrindo pagina: \(url ?? "0")")
                store.updateLog(with: "Abrindo pagina: \(url ?? "0")!\n")

                store.inputText = url ?? "0"
                await store.send(.onSubmit(url ?? "0"))
            }
            
            if isLoadingPage && store.isPaginaFoiCarregada {
                try? await Task.sleep(for: LIKE_WAIT_INTERVAL)
                
                print("NAVI: rodando script")
                store.updateLog(with: "Rodando script!\n")

                //store.scriptText = LIKE_SCRIPT
                await store.send(.scriptRunButtonTapped(LIKE_SCRIPT))
                
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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(text.wrappedValue)
                            //.font(.system(.body, design: .monospaced))
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                        
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .onChange(of: text.wrappedValue) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

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

struct ConfigStruct: Decodable {
    var newVersion: Bool = true
    var sessionId: String = ""
    var npoint: String? = ""
    var secret: String? = ""
}

private extension UTType {
    static var naviScript: UTType {
        UTType(filenameExtension: "navi") ?? .data
    }
}

#Preview {
    NaviPanelView(store: .init(.testDependencies()))
}
