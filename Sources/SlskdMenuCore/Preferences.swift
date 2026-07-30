import Foundation

public struct SlskdPreferences: Codable, Equatable, Sendable {
    public var baseURL: URL
    public var runtimeConfigPath: String
    public var downloadsPath: String
    public var configFolderPath: String
    public var logsPath: String
    public var dataPath: String
    public var soulseekQtPath: String?
    public var connectionNotifications: Bool
    public var showTransferCounts: Bool
    public var customIconPaths: [MenuConnectionState: String]

    public static var defaults: SlskdPreferences {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let data = home.appendingPathComponent("Library/Application Support/slskd")
        let downloads = home.appendingPathComponent("Downloads/Soulseek")
        return SlskdPreferences(
            baseURL: URL(string: "http://localhost:5030")!,
            runtimeConfigPath: data.appendingPathComponent("slskd.yml").path,
            downloadsPath: downloads.path,
            configFolderPath: home.appendingPathComponent(".config/slskd").path,
            logsPath: data.appendingPathComponent("logs").path,
            dataPath: data.path,
            soulseekQtPath: nil,
            connectionNotifications: true,
            showTransferCounts: false,
            customIconPaths: [:]
        )
    }
}

public final class PreferencesStore: @unchecked Sendable {
    public static let key = "local.rd.slskd-menu.preferences.v2"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SlskdPreferences {
        guard
            let data = defaults.data(forKey: Self.key),
            let preferences = try? decoder.decode(SlskdPreferences.self, from: data)
        else {
            return .defaults
        }
        return preferences
    }

    public func save(_ preferences: SlskdPreferences) throws {
        defaults.set(try encoder.encode(preferences), forKey: Self.key)
    }
}
