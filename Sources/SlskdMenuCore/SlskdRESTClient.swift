import Foundation

public protocol SlskdRESTServing: Sendable {
    func serverState() async throws -> ServerState
    func connect() async throws
    func disconnect(message: String) async throws
    func transferSummary() async throws -> TransferSummary
    func clearCompletedDownloads() async throws
    func clearCompletedUploads() async throws
}

public enum SlskdClientError: LocalizedError, Sendable {
    case authenticationFailed
    case invalidResponse
    case unavailable
    case requestFailed(Int)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed: "slskd rejected the configured API key."
        case .invalidResponse: "slskd returned an unreadable response."
        case .unavailable: "slskd is unavailable."
        case .requestFailed(let status): "slskd returned HTTP \(status)."
        }
    }
}

public actor SlskdRESTClient: SlskdRESTServing {
    private let baseURLProvider: @Sendable () -> URL
    private let configURLProvider: @Sendable () -> URL
    private let session: URLSession

    public init(
        baseURLProvider: @escaping @Sendable () -> URL,
        configURLProvider: @escaping @Sendable () -> URL,
        session: URLSession = .shared
    ) {
        self.baseURLProvider = baseURLProvider
        self.configURLProvider = configURLProvider
        self.session = session
    }

    public func serverState() async throws -> ServerState {
        let data = try await perform(path: "api/v0/server", method: "GET")
        return try decode(ServerState.self, from: data)
    }

    public func connect() async throws {
        _ = try await perform(path: "api/v0/server", method: "PUT")
    }

    public func disconnect(message: String) async throws {
        let body = try JSONEncoder().encode(message)
        _ = try await perform(path: "api/v0/server", method: "DELETE", body: body)
    }

    public func transferSummary() async throws -> TransferSummary {
        async let downloadsData = perform(
            path: "api/v0/transfers/downloads",
            method: "GET",
            queryItems: [URLQueryItem(name: "includeRemoved", value: "false")]
        )
        async let uploadsData = perform(
            path: "api/v0/transfers/uploads",
            method: "GET",
            queryItems: [URLQueryItem(name: "includeRemoved", value: "false")]
        )
        let (downloadGroups, uploadGroups) = try await (
            decode([TransferUserGroup].self, from: downloadsData),
            decode([TransferUserGroup].self, from: uploadsData)
        )
        let downloads = TransferRecord.aggregate(downloadGroups.flatMap(\.directories).flatMap(\.files))
        let uploads = TransferRecord.aggregate(uploadGroups.flatMap(\.directories).flatMap(\.files))
        return TransferSummary(
            activeDownloads: downloads.count,
            activeUploads: uploads.count,
            downloadSpeed: downloads.speed,
            uploadSpeed: uploads.speed
        )
    }

    public func clearCompletedDownloads() async throws {
        _ = try await perform(path: "api/v0/transfers/downloads/all/completed", method: "DELETE")
    }

    public func clearCompletedUploads() async throws {
        _ = try await perform(path: "api/v0/transfers/uploads/all/completed", method: "DELETE")
    }

    private func perform(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Data {
        let baseURL = baseURLProvider()
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw SlskdClientError.invalidResponse
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw SlskdClientError.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = method
        request.setValue(try RuntimeConfig.apiKey(at: configURLProvider()), forHTTPHeaderField: "X-API-Key")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw SlskdClientError.invalidResponse
            }
            switch response.statusCode {
            case 200..<300: return data
            case 401: throw SlskdClientError.authenticationFailed
            default: throw SlskdClientError.requestFailed(response.statusCode)
            }
        } catch let error as SlskdClientError {
            throw error
        } catch {
            throw SlskdClientError.unavailable
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw SlskdClientError.invalidResponse
        }
    }
}
