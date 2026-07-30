import XCTest
@testable import SlskdMenuCore

final class SignalRProtocolTests: XCTestCase {
    func testFramesHandshakeWithRecordSeparator() throws {
        let data = try SignalRProtocol.handshakeFrame()
        XCTAssertEqual(data.last, 0x1e)
    }

    func testDecodesStateInvocation() throws {
        let json = """
        {"type":1,"target":"STATE","arguments":[{"server":{"state":"Connected, LoggedIn","isConnected":true,"isConnecting":false,"isLoggedIn":true}}]}\u{001e}
        """
        let invocations = try SignalRProtocol.decodeFrames(Data(json.utf8))
        XCTAssertEqual(invocations.first?.target, "STATE")
    }

    func testIgnoresPingFrame() throws {
        let frames = try SignalRProtocol.decodeFrames(Data("{\"type\":6}\u{001e}".utf8))
        XCTAssertTrue(frames.isEmpty)
    }

    func testDecodesPushedTransferCounts() throws {
        let json = """
        {"downloads":{"inProgress":{"files":3}},"uploads":{"inProgress":{"files":1}}}
        """
        let metrics = try JSONDecoder().decode(MetricsEnvelope.self, from: Data(json.utf8))
        XCTAssertEqual(metrics.activeCounts.downloads, 3)
        XCTAssertEqual(metrics.activeCounts.uploads, 1)
    }
}
