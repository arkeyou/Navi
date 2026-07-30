import Foundation

public struct UserDefaultsRepository: Sendable {
    private var userDefaultsClient: UserDefaultsClient

    public var searchEngine: SearchEngine? {
        get {
            guard let value = userDefaultsClient.string(.searchEngine) else { return nil }
            return SearchEngine(rawValue: value)
        }
        nonmutating set {
            userDefaultsClient.setString(newValue?.rawValue, .searchEngine)
        }
    }

    public var appearance: Appearance? {
        get {
            guard let value = userDefaultsClient.string(.appearance) else { return nil }
            return Appearance(rawValue: value)
        }
        nonmutating set {
            userDefaultsClient.setString(newValue?.rawValue, .appearance)
        }
    }

    public var bookmarks: [Bookmark] {
        get {
            guard let data = userDefaultsClient.data(.bookmarks) else { return [] }
            return (try? JSONDecoder().decode([Bookmark].self, from: data)) ?? []
        }
        nonmutating set {
            let data = try? JSONEncoder().encode(newValue)
            userDefaultsClient.setData(data, .bookmarks)
        }
    }

    public var monitorInterval: Double {
        get { userDefaultsClient.double(.monitorInterval) ?? 4.0 }
        nonmutating set { userDefaultsClient.setDouble(newValue, .monitorInterval) }
    }

    public var monitorLiveOnlineInterval: Double {
        get { userDefaultsClient.double(.monitorLiveOnlineInterval) ?? 20.0 }
        nonmutating set { userDefaultsClient.setDouble(newValue, .monitorLiveOnlineInterval) }
    }

    public var idsWaitInterval: Double {
        get { userDefaultsClient.double(.idsWaitInterval) ?? 2.0 }
        nonmutating set { userDefaultsClient.setDouble(newValue, .idsWaitInterval) }
    }

    public var likeWaitInterval: Double {
        get { userDefaultsClient.double(.likeWaitInterval) ?? 0.5 }
        nonmutating set { userDefaultsClient.setDouble(newValue, .likeWaitInterval) }
    }

    public var cookieWaitInterval: Double {
        get { userDefaultsClient.double(.cookieWaitInterval) ?? 5.0 }
        nonmutating set { userDefaultsClient.setDouble(newValue, .cookieWaitInterval) }
    }

    public init(_ userDefaultsClient: UserDefaultsClient) {
        self.userDefaultsClient = userDefaultsClient

#if DEBUG
        if ProcessInfo.needsResetUserDefaults {
            userDefaultsClient.removePersistentDomain(Bundle.main.bundleIdentifier!)
        }
        showAllData()
#endif
    }

    private func showAllData() {
        guard let dict = userDefaultsClient.persistentDomain(Bundle.main.bundleIdentifier!) else {
            return
        }
        for (key, value) in dict.sorted(by: { $0.0 < $1.0 }) {
            Swift.print("\(key) => \(value)")
        }
    }
}
