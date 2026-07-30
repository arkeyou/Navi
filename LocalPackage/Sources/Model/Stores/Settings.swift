import Foundation
import DataSource
import Observation
import UIKit

@MainActor @Observable public final class Settings: Identifiable, Composable {
    private let uiApplicationClient: UIApplicationClient
    private let wkWebsiteDataStoreClient: WKWebsiteDataStoreClient
    private let userDefaultsRepository: UserDefaultsRepository
    private let logService: LogService

    public let id: UUID
    public var path: [Path]
    public var searchEngine: SearchEngine
    public var appearance: Appearance
    public var version: String
    
    public var monitorInterval: Double
    public var monitorLiveOnlineInterval: Double
    public var idsWaitInterval: Double
    public var likeWaitInterval: Double
    public var cookieWaitInterval: Double
    
    public let developer = "Takuto Nakamura"
    public let action: (Action) async -> Void

    public init(
        _ appDependencies: AppDependencies,
        id: UUID,
        path: [Path] = [],
        searchEngine: SearchEngine? = nil,
        appearance: Appearance? = nil,
        version: String? = nil,
        monitorInterval: Double? = nil,
        monitorLiveOnlineInterval: Double? = nil,
        idsWaitInterval: Double? = nil,
        likeWaitInterval: Double? = nil,
        cookieWaitInterval: Double? = nil,
        action: @escaping (Action) async -> Void
    ) {
        self.uiApplicationClient = appDependencies.uiApplicationClient
        self.wkWebsiteDataStoreClient = appDependencies.wkWebsiteDataStoreClient
        let repository = UserDefaultsRepository(appDependencies.userDefaultsClient)
        self.userDefaultsRepository = repository
        self.logService = .init(appDependencies)
        self.id = id
        self.path = path
        self.searchEngine = if let searchEngine {
            searchEngine
        } else if let searchEngine = repository.searchEngine {
            searchEngine
        } else {
            .google
        }
        self.appearance = if let appearance {
            appearance
        } else if let appearance = repository.appearance {
            appearance
        } else {
            .dark
        }
        self.version = version ?? Bundle.main.bundleVersion
        self.monitorInterval = monitorInterval ?? repository.monitorInterval
        self.monitorLiveOnlineInterval = monitorLiveOnlineInterval ?? repository.monitorLiveOnlineInterval
        self.idsWaitInterval = idsWaitInterval ?? repository.idsWaitInterval
        self.likeWaitInterval = likeWaitInterval ?? repository.likeWaitInterval
        self.cookieWaitInterval = cookieWaitInterval ?? repository.cookieWaitInterval
        self.action = action
    }

    public func reduce(_ action: Action) async {
        switch action {
        case let .task(screenName):
            logService.notice(.screenView(name: screenName))

        case .defaultBrowserAppButtonTapped:
            guard let settingsURL = uiApplicationClient.settingsURL() else { return }
            _ = await uiApplicationClient.open(settingsURL)

        case let .searchEngineSettingButtonTapped(appDependencies):
            path.append(.searchEngineSetting(.init(
                appDependencies,
                selection: searchEngine,
                action: { [weak self] in
                    await self?.send(.searchEngineSetting($0))
                }
            )))

        case .crearCacheButtonTapped:
            let dataTypes = wkWebsiteDataStoreClient.allWebsiteDataTypes()
            let records = await wkWebsiteDataStoreClient.dataRecords(dataTypes)
            await wkWebsiteDataStoreClient.removeData(dataTypes, records)

        case .openRepositoryButtonTapped:
            guard let url = URL(string: "https://github.com/Kyome22/Telescopure") else { return }
            _ = await uiApplicationClient.open(url)

        case let .licensesButtonTapped(appDependencies):
            path.append(.licenses(.init(appDependencies)))

        case .doneButtonTapped:
            break

        case let .searchEngineSetting(.onChangeSearchEngine(searchEngine)):
            self.searchEngine = searchEngine
            userDefaultsRepository.searchEngine = searchEngine

        case let .onChangeAppearance(appearance):
            self.appearance = appearance
            userDefaultsRepository.appearance = appearance

        case let .onChangeMonitorInterval(interval):
            self.monitorInterval = interval
            userDefaultsRepository.monitorInterval = interval

        case let .onChangeMonitorLiveOnlineInterval(interval):
            self.monitorLiveOnlineInterval = interval
            userDefaultsRepository.monitorLiveOnlineInterval = interval

        case let .onChangeIdsWaitInterval(interval):
            self.idsWaitInterval = interval
            userDefaultsRepository.idsWaitInterval = interval

        case let .onChangeLikeWaitInterval(interval):
            self.likeWaitInterval = interval
            userDefaultsRepository.likeWaitInterval = interval

        case let .onChangeCookieWaitInterval(interval):
            self.cookieWaitInterval = interval
            userDefaultsRepository.cookieWaitInterval = interval

        case .searchEngineSetting:
            break
        }
    }

    public enum Action: Sendable {
        case task(String)
        case defaultBrowserAppButtonTapped
        case searchEngineSettingButtonTapped(AppDependencies)
        case crearCacheButtonTapped
        case openRepositoryButtonTapped
        case licensesButtonTapped(AppDependencies)
        case doneButtonTapped
        case onChangeAppearance(Appearance)
        case onChangeMonitorInterval(Double)
        case onChangeMonitorLiveOnlineInterval(Double)
        case onChangeIdsWaitInterval(Double)
        case onChangeLikeWaitInterval(Double)
        case onChangeCookieWaitInterval(Double)
        case searchEngineSetting(SearchEngineSetting.Action)
    }

    public enum Path: Hashable {
        case searchEngineSetting(SearchEngineSetting)
        case licenses(Licenses)

        public static func ==(lhs: Path, rhs: Path) -> Bool {
            lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        var id: Int {
            switch self {
            case let .searchEngineSetting(value):
                Int(bitPattern: ObjectIdentifier(value))
            case let .licenses(value):
                Int(bitPattern: ObjectIdentifier(value))
            }
        }
    }
}
