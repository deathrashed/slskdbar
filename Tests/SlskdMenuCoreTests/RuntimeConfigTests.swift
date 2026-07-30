import XCTest
@testable import SlskdMenuCore

final class RuntimeConfigTests: XCTestCase {
    func testExtractsFirstNamedAPIKey() throws {
        let yaml = """
        web:
          authentication:
            api_keys:
              menu:
                key: test-secret
                role: administrator
        """
        XCTAssertEqual(try RuntimeConfig.apiKey(fromYAML: yaml), "test-secret")
    }

    func testIgnoresJWTKey() throws {
        let yaml = """
        web:
          authentication:
            jwt:
              key: wrong-key
            api_keys:
              menu:
                key: correct-key
        """
        XCTAssertEqual(try RuntimeConfig.apiKey(fromYAML: yaml), "correct-key")
    }
}
