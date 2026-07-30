import Foundation

public enum MenuConnectionState: String, Codable, CaseIterable, Equatable, Sendable {
    case connected
    case disconnected
    case connecting
    case unavailable
}

public struct ServerState: Codable, Equatable, Sendable {
    public let state: String
    public let isConnected: Bool
    public let isConnecting: Bool
    public let isLoggedIn: Bool

    public init(state: String, isConnected: Bool, isConnecting: Bool, isLoggedIn: Bool) {
        self.state = state
        self.isConnected = isConnected
        self.isConnecting = isConnecting
        self.isLoggedIn = isLoggedIn
    }

    public var menuState: MenuConnectionState {
        if isConnected && isLoggedIn { return .connected }
        if isConnecting { return .connecting }
        return .disconnected
    }
}

public struct ApplicationStateEnvelope: Decodable, Sendable {
    public let server: ServerState
}

public struct TransferSummary: Equatable, Sendable {
    public let activeDownloads: Int
    public let activeUploads: Int
    public let downloadSpeed: Double
    public let uploadSpeed: Double

    public init(activeDownloads: Int, activeUploads: Int, downloadSpeed: Double, uploadSpeed: Double) {
        self.activeDownloads = activeDownloads
        self.activeUploads = activeUploads
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
    }

    public static let zero = TransferSummary(
        activeDownloads: 0,
        activeUploads: 0,
        downloadSpeed: 0,
        uploadSpeed: 0
    )
}

public struct TransferRecord: Decodable, Equatable, Sendable {
    public let state: String
    public let averageSpeed: Double

    public init(state: String, averageSpeed: Double) {
        self.state = state
        self.averageSpeed = averageSpeed
    }

    public static func aggregate(_ records: [TransferRecord]) -> (count: Int, speed: Double) {
        let active = records.filter { $0.state.localizedCaseInsensitiveContains("InProgress") }
        return (active.count, active.reduce(0) { $0 + $1.averageSpeed })
    }
}

public struct TransferDirectory: Decodable, Sendable {
    public let files: [TransferRecord]
}

public struct TransferUserGroup: Decodable, Sendable {
    public let directories: [TransferDirectory]
}

public struct TransferMetricState: Decodable, Sendable {
    public let files: Int?
}

public struct TransferMetricDirection: Decodable, Sendable {
    public let inProgress: TransferMetricState?
}

public struct MetricsEnvelope: Decodable, Sendable {
    public let downloads: TransferMetricDirection?
    public let uploads: TransferMetricDirection?

    public var activeCounts: (downloads: Int, uploads: Int) {
        (downloads?.inProgress?.files ?? 0, uploads?.inProgress?.files ?? 0)
    }
}
