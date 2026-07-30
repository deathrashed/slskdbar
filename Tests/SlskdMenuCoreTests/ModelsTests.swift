import XCTest
@testable import SlskdMenuCore

final class ModelsTests: XCTestCase {
    func testServerStateMapsToMenuState() {
        XCTAssertEqual(
            ServerState(state: "Connected, LoggedIn", isConnected: true, isConnecting: false, isLoggedIn: true)
                .menuState,
            .connected
        )
        XCTAssertEqual(
            ServerState(state: "Connecting", isConnected: false, isConnecting: true, isLoggedIn: false)
                .menuState,
            .connecting
        )
        XCTAssertEqual(
            ServerState(state: "Disconnected", isConnected: false, isConnecting: false, isLoggedIn: false)
                .menuState,
            .disconnected
        )
    }
}
