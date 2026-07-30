import XCTest
@testable import SlskdMenuCore

final class TransferAggregationTests: XCTestCase {
    func testAggregatesOnlyInProgressTransfers() {
        let transfers = [
            TransferRecord(state: "InProgress", averageSpeed: 1_000),
            TransferRecord(state: "Completed, Succeeded", averageSpeed: 9_000),
            TransferRecord(state: "InProgress", averageSpeed: 2_000),
        ]
        let summary = TransferRecord.aggregate(transfers)
        XCTAssertEqual(summary.count, 2)
        XCTAssertEqual(summary.speed, 3_000)
    }
}
