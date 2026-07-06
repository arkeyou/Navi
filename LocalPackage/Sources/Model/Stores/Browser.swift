import DataSource
import Observation
import SwiftUI
import WebUI

@MainActor @Observable public final class Browser: Composable {
    private let appStateClient: AppStateClient
    private let uiApplicationClient: UIApplicationClient
    private let uuidClient: UUIDClient
    private let webViewProxyClient: WebViewProxyClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService

    @ObservationIgnored private var eventBridge: Action.EventBridge?
    @ObservationIgnored private var operateWebViewProxy: ((WebViewProxy) -> Void)?
    @ObservationIgnored private var lastDialogClosedDate = Date.distantPast

    public var inputText: String
    public var isPresentedToolbar: Bool
    public var isPresentedZoomPopover: Bool
    public var pageScale: PageScale
    public var isInputingSearchBar: Bool
    public var textSelection: TextSelection?
    public var currentURL: URL?
    public var currentTitle: String?
    public var isPresentedWebDialog: Bool
    public var webDialog: WebDialog?
    public var promptInput: String
    public var customSchemeURL: URL?
    public var isPresentedConfirmationDialog: Bool
    public var isPresentedAlert: Bool
    public var naviPanelSelection: NaviPanelSelection
    public var scriptText: String
    public var scriptFileName: String
    public var pendingScriptFileName: String
    public var isPresentedScriptSaveDialog: Bool
    public var isPresentedScriptImporter: Bool
    public var isPresentedScriptSelection: Bool
    public var savedScriptURLs: [URL]
    public var logText: String
    public var processedText: String
    public var naviPanelMessage: String?
    public var isPageLoading: Bool
    public var isPaginaFoiCarregada: Bool
    public let navigationDelegate: BrowserNavigationDelegate
    public let uiDelegate: BrowserUIDelegate
    public var settings: Settings?
    public var bookmarkManagement: BookmarkManagement?

    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        eventBridge: Action.EventBridge? = nil,
        inputText: String = "",
        isPresentedToolbar: Bool = true,
        isPresentedZoomPopover: Bool = false,
        pageScale: PageScale = .scale100,
        isInputingSearchBar: Bool = false,
        textSelection: TextSelection? = nil,
        currentURL: URL? = nil,
        currentTitle: String? = nil,
        isPresentedWebDialog: Bool = false,
        webDialog: WebDialog? = nil,
        promptInput: String = "",
        customSchemeURL: URL? = nil,
        isPresentedConfirmationDialog: Bool = false,
        isPresentedAlert: Bool = false,
        naviPanelSelection: NaviPanelSelection = .script,
        scriptText: String = "",
        scriptFileName: String = "Sem titulo",
        pendingScriptFileName: String = "",
        isPresentedScriptSaveDialog: Bool = false,
        isPresentedScriptImporter: Bool = false,
        isPresentedScriptSelection: Bool = false,
        savedScriptURLs: [URL] = [],
        logText: String = "",
        processedText: String = "",
        naviPanelMessage: String? = nil,
        isPageLoading: Bool = false,
        isPaginaFoiCarregada: Bool = false,
        browserNavigation: BrowserNavigation? = nil,
        browserUI: BrowserUI? = nil,
        settings: Settings? = nil,
        bookmarkManagement: BookmarkManagement? = nil,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.uiApplicationClient = appDependencies.uiApplicationClient
        self.uuidClient = appDependencies.uuidClient
        self.webViewProxyClient = appDependencies.webViewProxyClient
        self.userDefaultsRepository = .init(appDependencies.userDefaultsClient)
        self.logService = .init(appDependencies)
        self.eventBridge = eventBridge
        self.inputText = inputText
        self.isPresentedToolbar = isPresentedToolbar
        self.isPresentedZoomPopover = isPresentedZoomPopover
        self.pageScale = pageScale
        self.isInputingSearchBar = isInputingSearchBar
        self.textSelection = textSelection
        self.currentURL = currentURL
        self.currentTitle = currentTitle
        self.isPresentedWebDialog = isPresentedWebDialog
        self.webDialog = webDialog
        self.promptInput = promptInput
        self.customSchemeURL = customSchemeURL
        self.isPresentedConfirmationDialog = isPresentedConfirmationDialog
        self.isPresentedAlert = isPresentedAlert
        self.naviPanelSelection = naviPanelSelection
        self.scriptText = scriptText
        self.scriptFileName = scriptFileName
        self.pendingScriptFileName = pendingScriptFileName
        self.isPresentedScriptSaveDialog = isPresentedScriptSaveDialog
        self.isPresentedScriptImporter = isPresentedScriptImporter
        self.isPresentedScriptSelection = isPresentedScriptSelection
        self.savedScriptURLs = savedScriptURLs
        self.logText = logText
        self.processedText = processedText
        self.naviPanelMessage = naviPanelMessage
        self.isPageLoading = isPageLoading
        self.isPaginaFoiCarregada = isPaginaFoiCarregada
        weak var weakSelf: Browser? = nil
        let browserNavigation = browserNavigation ?? .init(appDependencies, action: {
            await weakSelf?.send(.browserNavigation($0))
        })
        self.navigationDelegate = .init(store: browserNavigation)
        let browserUI = browserUI ?? .init(appDependencies, action: {
            await weakSelf?.send(.browserUI($0))
        })
        self.uiDelegate = .init(store: browserUI)
        self.settings = settings
        self.bookmarkManagement = bookmarkManagement
        self.action = action
        weakSelf = self
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName, eventBridge, webViewProxy):
            logService.notice(.screenView(name: screenName))
            self.eventBridge = eventBridge
            self.webViewProxyClient.setProxy(webViewProxy)
            prepareNaviFiles()
            loadNaviPanelContent(for: naviPanelSelection)

        case let .onChangeURL(url):
            currentURL = url
            if let urlString = url?.absoluteString.removingPercentEncoding {
                inputText = urlString
            }

        case let .onChangeTitle(title):
            currentTitle = title

        case let .onChangeIsLoading(isLoading):
            let wasLoading = isPageLoading
            isPageLoading = isLoading
            
            if wasLoading && !isLoading {
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let urlString = currentURL?.absoluteString ?? "URL desconhecida"
                let loadEntry = "[\(timestamp)] Página carregada: \(urlString)\n"
                updateLog(with: loadEntry)
                isPaginaFoiCarregada = true
            }

        case let .onOpenURL(url):
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            switch components.scheme {
            case "http", "https":
                await webViewProxyClient.load(URLRequest(url: url))
            case "telescopure":
                guard let queryItem = components.queryItems?.first else { return }
                if queryItem.name == "link", var link = queryItem.value {
                    if let fragment = url.fragment {
                        link += "#\(fragment)"
                    }
                    await search(with: link)
                }
                if queryItem.name == "plaintext", let plainText = queryItem.value {
                    // plainText is already removed percent-encoding.
                    await search(with: plainText)
                }
            case .some, .none:
                return
            }

        case let .onSubmit(keyword):
            await search(with: keyword)

        case let .settingsButtonTapped(appDependencies):
            settings = .init(
                appDependencies,
                id: uuidClient.create(),
                action: { [weak self] in
                    await self?.send(.settings($0))
                }
            )

        case .clearSearchButtonTapped:
            inputText = ""
            textSelection = nil

        case .cancelSearchButtonTapped:
            inputText = await webViewProxyClient.url()?.absoluteString ?? ""

        case let .onChangeFocusedField(focusedField):
            isInputingSearchBar = focusedField == .search
            if isInputingSearchBar, let range = inputText.range(of: inputText) {
                textSelection = .init(range: range)
            }
        case .showZoomPopoverButtonTapped:
            isPresentedZoomPopover = true

        case let .zoomButtonTapped(command):
            pageScale = switch command {
            case .zoomReset: .scale100
            case .zoomIn: pageScale.scaleUpped()
            case .zoomOut: pageScale.scaleDowned()
            }

        case .goBackButtonTapped:
            if await webViewProxyClient.canGoBack() {
                await webViewProxyClient.goBack()
            }

        case .goForwardButtonTapped:
            if await webViewProxyClient.canGoForward() {
                await webViewProxyClient.goForward()
            }

        case let .bookmarkButtonTapped(appDependencies):
            bookmarkManagement = .init(
                appDependencies,
                id: uuidClient.create(),
                currentURL: currentURL,
                currentTitle: currentTitle,
                action: { [weak self] in
                    await self?.send(.bookmarkManagement($0))
                }
            )

        case .hideToolbarButtonTapped:
            withAnimation(.easeIn(duration: 0.2)) {
                isPresentedToolbar = false
            }

        case .showToolbarButtonTapped:
            withAnimation(.easeIn(duration: 0.2)) {
                isPresentedToolbar = true
            }

        case let .naviPanelSelectionChanged(selection):
            naviPanelSelection = selection
            loadNaviPanelContent(for: selection)

        case .scriptNewButtonTapped:
            scriptText = ""
            scriptFileName = "Sem titulo"
            naviPanelMessage = nil

        case .scriptSaveButtonTapped:
            pendingScriptFileName = scriptFileName == "Sem titulo" ? "" : scriptFileName.removingNaviExtension
            isPresentedScriptSaveDialog = true

        case .scriptSaveConfirmed:
            saveCurrentScript()

        case .scriptLoadButtonTapped:
            loadSavedScripts()
            isPresentedScriptSelection = true

        case let .scriptFileImported(url):
            importScript(from: url)
            isPresentedScriptSelection = false

        case let .scriptSelected(url):
            importScript(from: url)
            isPresentedScriptSelection = false

        case let .deleteScript(url):
            do {
                try FileManager.default.removeItem(at: url)
                loadSavedScripts()
                naviPanelMessage = "Script excluído."
            } catch {
                naviPanelMessage = error.localizedDescription
            }

        case .scriptRunButtonTapped:
            do {
                try await webViewProxyClient.evaluateJavaScript(scriptText)
                    naviPanelMessage = "Script executado."
            } catch {
                naviPanelMessage = error.localizedDescription
        }

        case .clearLogButtonTapped:
            writeNaviDataFile(.log, content: "")
            logText = ""

        case .clearProcessedButtonTapped:
            writeNaviDataFile(.processed, content: "")
            processedText = ""

        case .dialogOKButtonTapped:
            guard let webDialog else { return }
            switch webDialog {
            case .alert:
                appStateClient.send(\.alertResponseSubject, input: ())
            case .confirm:
                appStateClient.send(\.confirmResponseSubject, input: true)
            case .prompt:
                appStateClient.send(\.promptResponseSubject, input: promptInput)
            }

        case .dialogCancelButtonTapped:
            guard let webDialog else { return }
            switch webDialog {
            case .alert:
                appStateClient.send(\.alertResponseSubject, input: ())
            case .confirm:
                appStateClient.send(\.confirmResponseSubject, input: false)
            case .prompt:
                appStateClient.send(\.promptResponseSubject, input: nil)
            }

        case let .onChangeIsPresentedWebDialog(isPresented):
            if !isPresented {
                lastDialogClosedDate = .now
            }

        case let .confirmButtonTapped(url):
            let openURLResult = await uiApplicationClient.open(url)
            guard !openURLResult else { return }
            isPresentedAlert = true

        case let .browserNavigation(.decidePolicyFor(request)):
            guard let requestURL = request.url else {
                appStateClient.send(\.actionPolicySubject, input: .cancel)
                return
            }
            guard ["http", "https", "blob", "file", "about"].contains(requestURL.scheme) else {
                appStateClient.send(\.actionPolicySubject, input: .cancel)
                customSchemeURL = requestURL
                isPresentedConfirmationDialog = true
                return
            }
            appStateClient.send(\.actionPolicySubject, input: .allow)

        case let .browserNavigation(.didFailProvisionalNavigation(error)),
            let .browserNavigation(.didFail(error)):
            guard (error as NSError).code != NSURLErrorCancelled else {
                return
            }
            await loadErrorPage(with: error)

        case let .browserUI(.runJavaScriptAlertPanel(message)):
            await presentWebDialog(.alert(message))

        case let .browserUI(.runJavaScriptConfirmPanel(message)):
            await presentWebDialog(.confirm(message))

        case let .browserUI(.runJavaScriptTextInputPanel(prompt, defaultText)):
            await presentWebDialog(.prompt(prompt, defaultText ?? ""))

        case .settings(.doneButtonTapped):
            settings = nil

        case .settings:
            break

        case let .bookmarkManagement(.bookmarkItem(.openBookmarkButtonTapped(url))):
            bookmarkManagement = nil
            await webViewProxyClient.load(URLRequest(url: url))

        case .bookmarkManagement(.doneButtonTapped):
            bookmarkManagement = nil

        case .bookmarkManagement:
            break
        }
    }

    private func prepareNaviFiles() {
        do {
            try FileManager.default.createDirectory(at: naviScriptsDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: naviDadosDirectory, withIntermediateDirectories: true)
            for file in NaviDataFile.allCases where !FileManager.default.fileExists(atPath: file.url(in: naviDadosDirectory).path) {
                try "".write(to: file.url(in: naviDadosDirectory), atomically: true, encoding: .utf8)
            }
        } catch {
            naviPanelMessage = error.localizedDescription
        }
    }

    private func loadNaviPanelContent(for selection: NaviPanelSelection) {
        switch selection {
        case .script:
            break
        case .log:
            logText = readNaviDataFile(.log)
        case .processed:
            processedText = readNaviDataFile(.processed)
        }
    }
    
    public func updateLog(with message: String) {
        var updatedLog = readNaviDataFile(.log)
        updatedLog.append(message)
        writeNaviDataFile(.log, content: updatedLog)
        logText = updatedLog
    }

    private func readNaviDataFile(_ file: NaviDataFile) -> String {
        (try? String(contentsOf: file.url(in: naviDadosDirectory), encoding: .utf8)) ?? ""
    }

    private func writeNaviDataFile(_ file: NaviDataFile, content: String) {
        do {
            try FileManager.default.createDirectory(at: naviDadosDirectory, withIntermediateDirectories: true)
            try content.write(to: file.url(in: naviDadosDirectory), atomically: true, encoding: .utf8)
            naviPanelMessage = nil
        } catch {
            naviPanelMessage = error.localizedDescription
        }
    }

    private func saveCurrentScript() {
        let trimmedName = pendingScriptFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            naviPanelMessage = "Informe um nome para o script."
            return
        }
        let safeName = trimmedName.replacingOccurrences(of: "/", with: "-")
        let fileName = safeName.hasSuffix(".navi") ? safeName : "\(safeName).navi"
        do {
            try FileManager.default.createDirectory(at: naviScriptsDirectory, withIntermediateDirectories: true)
            let url = naviScriptsDirectory.appendingPathComponent(fileName)
            try scriptText.write(to: url, atomically: true, encoding: .utf8)
            scriptFileName = fileName
            naviPanelMessage = "Script salvo."
        } catch {
            naviPanelMessage = error.localizedDescription
        }
    }

    private func importScript(from url: URL) {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard url.pathExtension.lowercased() == "navi" else {
            naviPanelMessage = "Escolha um arquivo .navi."
            return
        }
        do {
            try FileManager.default.createDirectory(at: naviScriptsDirectory, withIntermediateDirectories: true)
            
            let isAlreadyInScriptsDir = url.deletingLastPathComponent().standardizedFileURL == naviScriptsDirectory.standardizedFileURL
            let finalURL: URL
            if isAlreadyInScriptsDir {
                finalURL = url
            } else {
                let destinationURL = uniqueScriptDestinationURL(for: url.lastPathComponent)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: url, to: destinationURL)
                finalURL = destinationURL
            }
            
            scriptText = try String(contentsOf: finalURL, encoding: .utf8)
            scriptFileName = finalURL.lastPathComponent
            naviPanelMessage = "Script carregado."
        } catch {
            naviPanelMessage = error.localizedDescription
        }
    }

    private func loadSavedScripts() {
        do {
            try FileManager.default.createDirectory(at: naviScriptsDirectory, withIntermediateDirectories: true)
            let urls = try FileManager.default.contentsOfDirectory(at: naviScriptsDirectory, includingPropertiesForKeys: nil)
            savedScriptURLs = urls.filter { $0.pathExtension.lowercased() == "navi" }
                .sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
        } catch {
            naviPanelMessage = error.localizedDescription
            savedScriptURLs = []
        }
    }

    private func uniqueScriptDestinationURL(for fileName: String) -> URL {
        let baseName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var candidate = naviScriptsDirectory.appendingPathComponent(fileName)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = naviScriptsDirectory.appendingPathComponent("\(baseName)-\(index).\(ext)")
            index += 1
        }
        return candidate
    }

    private func search(with text: String) async {
        let searchEngine = userDefaultsRepository.searchEngine ?? .google
        let url: URL? = if text.isEmpty {
            URL(string: searchEngine.url)
        } else if let url = URLComponents(string: text)?.url, let scheme = url.scheme {
            switch scheme.lowercased() {
            case "http", "https":
                URL(string: text)
            default:
                url
            }
        } else {
            URLComponents(string: searchEngine.urlWithQuery(keywords: text))?.url
        }
        if let url {
            await webViewProxyClient.load(URLRequest(url: url))
        }
    }

    private func loadErrorPage(with error: any Error) async {
        guard let fileURL = eventBridge?.getResourceURL?("error", "html"),
              var htmlString = try? String(contentsOf: fileURL, encoding: .utf8) else {
            fatalError("Could not load error.html")
        }
        if let urlError = error as? URLError {
            htmlString = htmlString.replacingOccurrences(of: String.errorMessage, with: urlError.localizedDescription)
            await webViewProxyClient.loadHTMLString(htmlString, urlError.failingURL)
        } else {
            htmlString = htmlString.replacingOccurrences(of: String.errorMessage, with: error.localizedDescription)
            await webViewProxyClient.loadHTMLString(htmlString, URL(string: inputText))
        }
    }

    private func presentWebDialog(_ webDialog: WebDialog) async {
        while lastDialogClosedDate.distance(to: .now) < 0.1 {
            try? await Task.sleep(for: .seconds(0.1))
        }
        self.webDialog = webDialog
        isPresentedWebDialog = true
    }

    private var naviRootDirectory: URL {
        let fileManager = FileManager.default
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents", isDirectory: true) {
            return iCloudURL
        }
        return try! fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private var naviScriptsDirectory: URL {
        naviRootDirectory.appendingPathComponent("naviScripts", isDirectory: true)
    }

    private var naviDadosDirectory: URL {
        naviRootDirectory.appendingPathComponent("naviDados", isDirectory: true)
    }

    public enum NaviPanelSelection: Hashable, Sendable {
        case script
        case log
        case processed
    }

    private enum NaviDataFile: CaseIterable {
        case log
        case processed

        func url(in directory: URL) -> URL {
            switch self {
            case .log:
                directory.appendingPathComponent("_logProcessamento")
            case .processed:
                directory.appendingPathComponent("_itensProcessados")
            }
        }
    }

    public enum Action: Sendable {
        case task(String, EventBridge, WebViewProxy)
        case onChangeURL(URL?)
        case onChangeTitle(String?)
        case onChangeIsLoading(Bool)
        case onOpenURL(URL)
        case onSubmit(String)
        case settingsButtonTapped(AppDependencies)
        case clearSearchButtonTapped
        case cancelSearchButtonTapped
        case onChangeFocusedField(FocusedField?)
        case showZoomPopoverButtonTapped
        case zoomButtonTapped(PageZoomCommand)
        case goBackButtonTapped
        case goForwardButtonTapped
        case bookmarkButtonTapped(AppDependencies)
        case hideToolbarButtonTapped
        case showToolbarButtonTapped
        case naviPanelSelectionChanged(NaviPanelSelection)
        case scriptNewButtonTapped
        case scriptSaveButtonTapped
        case scriptSaveConfirmed
        case scriptLoadButtonTapped
        case scriptFileImported(URL)
        case scriptSelected(URL)
        case deleteScript(URL)
        case scriptRunButtonTapped
        case clearLogButtonTapped
        case clearProcessedButtonTapped
        case dialogOKButtonTapped
        case dialogCancelButtonTapped
        case onChangeIsPresentedWebDialog(Bool)
        case confirmButtonTapped(URL)
        case browserNavigation(BrowserNavigation.Action)
        case browserUI(BrowserUI.Action)
        case settings(Settings.Action)
        case bookmarkManagement(BookmarkManagement.Action)

        public struct EventBridge: Sendable {
            public var getResourceURL: (@MainActor @Sendable (String, String) -> URL?)?

            public init(getResourceURL: @escaping @MainActor @Sendable (String, String) -> URL?) {
                self.getResourceURL = getResourceURL
            }
        }
    }
}

private extension String {
    var removingNaviExtension: String {
        hasSuffix(".navi") ? String(dropLast(".navi".count)) : self
    }
}
