import DataSource
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
    @State private var UNLIKE_SCRIPT = ""
    @State private var VERIFY_SCRIPT = ""
    @State private var VERIFY_SCRIPT2 = ""
    @State private var runTask: Task<Void, Never>? = nil
    @State private var processingTask: Task<Void, Never>? = nil
    @State private var enqueuingTask: Task<Void, Never>? = nil
    private let URL_NPOINT_API = "https://api.npoint.io/"
    @State private var isLoadingNaviProcess = false
    @State private var count = 0
    
    private let uuid = UUID()
    
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
        .sheet(isPresented: $store.isPresentedPaywall) {
            PaywallView(store: store)
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
        /*.task {
            enqueuingTask = Task {
                defer {
                    print("-------> finalizou a task")
                }
                await naviEnfileiramentoParaProcessamento()
            }
        }*/
        .onDisappear {
            //stopAutomation()
            if (store.ultimoNaviPanelView == nil && store.naviIsRunning) {
                store.ultimoNaviPanelView = self
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

                    if store.naviIsRunning {
                        Button {
                            store.updateLog(with: "Interrompido pelo usuario!")
                            stopAutomation()
                        } label: {
                            Label("Parar", systemImage: "square.fill")
                        }
                    } else {
                        Button {
                            startAutomation()
                            
                            enqueuingTask = Task {
                                defer {
                                    print("-------> finalizou a enqueuingTask")
                                }
                                await naviEnfileiramentoParaProcessamento()
                            }
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
        //Reseta a lista de ids adicionados hj
        //NaviQueueTracker.shared.resetEnqueueToday()
        
        //Desabiita o bloqueio de tela por inatividade
        UIApplication.shared.isIdleTimerDisabled = true
        print("Bloqueio de tela desativado")
        
        if NaviQueueTracker.shared.isLimitReached {
            store.updateLog(with: "Limite de \(NaviQueueConfig.dailyLimit) envios atingido para hoje. A automação não permite nova execução até o próximo dia!")

            Task {
                await store.send(.showPaywallButtonTapped)
            }
            return
        }
        
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
                store.updateLog(with: "Waiting for cookies...")
                cookies = await getBrowserCookies()
                try? await Task.sleep(for: Duration.seconds(store.userDefaultsRepository.cookieWaitInterval))
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
                if (!store.scriptText.starts(with: "{")) {
                    await store.send(.scriptRunButtonTapped(store.scriptText))
                    stopAutomation()
                    return
                }
                print(error)
                store.updateLog(with: "buscaConfiguracoes: \(error.localizedDescription)")
                stopAutomation()
                return
            }
            
            /*if (configStruct.sessionId?.isEmpty == true && configStruct.urlInicial?.isEmpty == false) {
                store.inputText = configStruct.urlInicial!
                await store.send(.onSubmit(configStruct.urlInicial!))
                store.updateLog(with: "Sem sessionID.. Abrindo pagina inicial. ")
                stopAutomation()
                return
            }*/
            
            store.updateLog(with: "\nIniciou automacao! ")
            store.naviIsRunning = true
            await am.start(naviConfig: config, sessionId: configStruct.sessionId ?? "", cookieList: cookies, monitorInterval: store.userDefaultsRepository.monitorInterval, monitorLiveOnlineInterval: store.userDefaultsRepository.monitorLiveOnlineInterval)
        }
        
        /*let taskID = UUID()

        enqueuingTask = Task {
            await naviEnfileiramentoParaProcessamento(mytaskID: taskID)
        }*/
        
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
    
    public func stopAutomation() {
        //Habilita novamente o bloqueio de tela
        UIApplication.shared.isIdleTimerDisabled = false
        print("Bloqueio de tela reativado")
        
        //o dismiss do sheet esta mantendo uma instancia da view em memoria executando as tasks e quando o sheet e exibido novamente, e criada uma nova view, q nao consegue parar as tasks da view inicial. Esta logica guarda as ultimas views e para as tasks rodando nelas
        if (store.ultimoNaviPanelView != nil) {
            if ((self as NaviPanelView).uuid != (store.ultimoNaviPanelView as? NaviPanelView)?.uuid) {
                (store.ultimoNaviPanelView as? NaviPanelView)?.stopAutomation()
                store.ultimoNaviPanelView = nil
            }
        }
        
        runTask?.cancel()
        runTask = nil
        
        processingTask?.cancel()
        processingTask = nil
        
        //Nao e necessario finalizar essa tarefa.
        //Quando isso e feito, ao o AsyncStream e cancelado e nao recebe mais emits
        //enqueuingTask?.cancel()
        //enqueuingTask = nil
        
        am.stop()
        
        queue = NaviQueue<String>()
        LIKE_SCRIPT = ""
        VERIFY_SCRIPT = ""
        
        store.naviIsRunning = false
        isLoadingNaviProcess = false
        store.isPaginaFoiCarregada = false
        store.updateLog(with: "Parou automacao. Verifique o log!")

        print("Automation stopped and cleaned up.")
        
        HapticManager.shared.trigger(.error)
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
    
    func verificaCookies(cookiesStr: String) async {
        var cookies = cookiesStr
        if cookies.isEmpty {
            cookies = await getBrowserCookies()
            if cookies.isEmpty {
                store.inputText = "shopee.com.br"
                await store.send(.onSubmit("shopee.com.br"))
            }
        }
        do {
            while cookies.isEmpty {
                if Task.isCancelled { return }
                store.updateLog(with: "Esperando os cookies...")
                cookies = await getBrowserCookies()
                try await Task.sleep(for: Duration.seconds(store.userDefaultsRepository.cookieWaitInterval))
            }
        } catch {
            print("Parou espera por cookies")
        }
    }
    
    func naviEnfileiramentoParaProcessamento() async {
        print("naviEnfileiramentoParaProcessamento: vai")
        for await event in am.actionEvents {
            if Task.isCancelled {
                break
            }

            switch event {
            case .enqueuePage(let codigo, let url, let username, let script, let scriptVerify, let script2, let scriptVerify2):
                print("Enqueue page: \(codigo) - \(username) - \(url)")
                
                _ = await queue.enqueue(url, info: username, isSubscribed: store.isSubscribed)
                /*if !enqueued {
                 store.updateLog(with: "\nLimite de \(NaviQueueConfig.dailyLimit) envios atingido para hoje. A NaviQueue não recebe mais itens. Automação parada até o próximo dia.\n")
                 stopAutomation()
                 await store.send(.showPaywallButtonTapped)
                 return
                 }*/
                
                store.updateProcessed(with: "\n\(codigo) - \(username)")
                
                if LIKE_SCRIPT.isEmpty {
                    LIKE_SCRIPT.append(script)
                }
                if VERIFY_SCRIPT.isEmpty {
                    VERIFY_SCRIPT.append(scriptVerify)
                }
                
                if UNLIKE_SCRIPT.isEmpty {
                    UNLIKE_SCRIPT.append(script2)
                }
                if VERIFY_SCRIPT2.isEmpty {
                    VERIFY_SCRIPT2.append(scriptVerify2)
                }
            case .sendMsg(let msg, let stop):
                print(msg)
                store.updateLog(with: msg)
                if stop {
                    stopAutomation()
                    return
                }
            case .openPage(let url):
                store.inputText = url
                await store.send(.onSubmit(url))
            }
        }
    }
    
    func naviProcessamentoTela() async {
        print("naviProcessamentoTela: vai")
        
        do {
            while !Task.isCancelled {
                count+=1
                print("NAVI: esperando \(count)")
                let timestamp = ISO8601DateFormatter().string(from: Date())
                //store.updateLog(with: "[\(timestamp)] Esperando ids...\n")
                
                try await Task.sleep(for: Duration.seconds(store.userDefaultsRepository.idsWaitInterval))
                if Task.isCancelled { break }
                if await !queue.isEmpty && !isLoadingNaviProcess {
                    isLoadingNaviProcess = true
                    let (url, info) = await queue.dequeue()
                    
                    print("NAVI: abrindo pagina: \(url ?? "0")")
                    store.updateLog(with: "Abrindo pagina (\(info ?? "sem username"))! ")//: \(url ?? "0")!")
                    
                    store.inputText = url ?? "0"
                    await store.send(.onSubmit(url ?? "0"))
                    continue
                }
                
                if isLoadingNaviProcess && store.isPaginaFoiCarregada {
                    //print("NAVI: esperando botao aparecer...")
                    await store.send(.scriptRunVerify(VERIFY_SCRIPT))
                    store.updateLog(with: "Buscando like na tela")
                    
                    HapticManager.shared.trigger(.warning)
                    
                    if (store.isButtonPresentOnPage) {
                        store.isButtonPresentOnPage = false
                        
                        print("NAVI: achou o botao, rodando script")
                        store.updateLog(with: "Encontrou! Executou like! ")
                        
                        await store.send(.scriptRunButtonTapped(LIKE_SCRIPT))
                        
                        try await Task.sleep(for: Duration.seconds(store.userDefaultsRepository.likeWaitInterval))
                        store.isPaginaFoiCarregada = false
                        isLoadingNaviProcess = false
                        
                        if await queue.isEmpty && NaviQueueTracker.shared.isLimitReached {
                            store.updateLog(with: "Limite de \(NaviQueueConfig.dailyLimit) envios atingido para hoje. A NaviQueue não recebe mais itens. Automação parada até o próximo dia.")
                            stopAutomation()
                            await store.send(.showPaywallButtonTapped)
                        }
                    } else {
                        await store.send(.scriptRunVerify(VERIFY_SCRIPT2))
                        store.updateLog(with: "Buscando unlike na tela")
                        
                        HapticManager.shared.trigger(.warning)
                        
                        if (store.isButtonPresentOnPage) {
                            store.isButtonPresentOnPage = false
                            
                            store.updateLog(with: "Encontrou! Executou unlike! ")
                            
                            await store.send(.scriptRunButtonTapped(UNLIKE_SCRIPT))
                            
                            try await Task.sleep(for: Duration.seconds(store.userDefaultsRepository.likeWaitInterval))
                            
                        }
                    }
                    continue
                }
                store.updateLog(with: "·", lineBreak: false)//era "."
            }
        } catch {
            print("Parou processamento na tela")
        }
    }
    
    private func loadedPage() async -> Bool {
        return false
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
                .lineLimit(1)
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
    var sessionId: String? = ""
    var npoint: String? = ""
    var secret: String? = ""
    var urlInicial: String?
}

private extension UTType {
    static var naviScript: UTType {
        UTType(filenameExtension: "navi") ?? .data
    }
}

#Preview {
    NaviPanelView(store: .init(.testDependencies()))
}
