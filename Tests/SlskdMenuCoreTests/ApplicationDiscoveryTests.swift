import XCTest
@testable import SlskdMenuCore

final class ApplicationDiscoveryTests: XCTestCase {
    private final class Locator: ApplicationLocating {
        var bundleURLs: [String: URL] = [:]
        var nameURLs: [String: URL] = [:]

        func URLForApplication(bundleIdentifier: String) -> URL? {
            bundleURLs[bundleIdentifier]
        }

        func URLForApplication(name: String) -> URL? {
            nameURLs[name]
        }
    }

    func testNicotinePrefersBundleIdentifier() {
        let locator = Locator()
        locator.bundleURLs["org.nicotine_plus.Nicotine"] = URL(fileURLWithPath: "/Applications/Nicotine+.app")
        locator.nameURLs["Nicotine+"] = URL(fileURLWithPath: "/Elsewhere/Nicotine+.app")
        let result = ApplicationDiscovery().refresh(locator: locator, soulseekQtOverride: nil)
        XCTAssertEqual(result.nicotine?.path, "/Applications/Nicotine+.app")
    }

    func testSoulseekQtUsesApplicationName() {
        let locator = Locator()
        locator.nameURLs["SoulseekQt"] = URL(fileURLWithPath: "/Applications/SoulseekQt.app")
        let result = ApplicationDiscovery().refresh(locator: locator, soulseekQtOverride: nil)
        XCTAssertEqual(result.soulseekQt?.path, "/Applications/SoulseekQt.app")
    }
}
