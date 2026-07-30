import XCTest
@testable import SlskdMenuCore

final class PreferencesTests: XCTestCase {
    func testDefaultsMatchDesign() {
        let defaults = SlskdPreferences.defaults
        let home = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertEqual(defaults.baseURL.absoluteString, "http://localhost:5030")
        XCTAssertEqual(defaults.downloadsPath, home.appendingPathComponent("Downloads/Soulseek").path)
        XCTAssertEqual(defaults.configFolderPath, home.appendingPathComponent(".config/slskd").path)
        XCTAssertEqual(
            defaults.logsPath,
            home.appendingPathComponent("Library/Application Support/slskd/logs").path
        )
        XCTAssertFalse(defaults.showTransferCounts)
        XCTAssertTrue(defaults.connectionNotifications)
    }

    func testInvalidPersistedValueFallsBackToCompleteDefaults() {
        let name = "SlskdMenuTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data("not-json".utf8), forKey: PreferencesStore.key)
        XCTAssertEqual(PreferencesStore(defaults: defaults).load(), .defaults)
    }
}
