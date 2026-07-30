import Foundation

public enum SignalRTransportState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case unavailable(String)
}

public actor SignalRConnection {
    private let baseURL: URL
    private let hubPath: String
    private let apiKeyProvider: @Sendable () throws -> String
    private let invocationHandler: @Sendable (SignalRInvocation) async -> Void
    private let stateHandler: @Sendable (SignalRTransportState) async -> Void
    private let session: URLSession
    private let ownsSession: Bool
    private let delays: [UInt64] = [1, 2, 5, 15, 30, 60, 120, 300]
    private var shouldRun = false
    private var runTask: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var generation = 0

    public init(
        baseURL: URL,
        hubPath: String,
        apiKeyProvider: @escaping @Sendable () throws -> String,
        invocationHandler: @escaping @Sendable (SignalRInvocation) async -> Void,
        stateHandler: @escaping @Sendable (SignalRTransportState) async -> Void,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        self.hubPath = hubPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKeyProvider = apiKeyProvider
        self.invocationHandler = invocationHandler
        self.stateHandler = stateHandler
        if let session {
            self.session = session
            ownsSession = false
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 10
            self.session = URLSession(configuration: configuration)
            ownsSession = true
        }
    }

    public func connect(immediate: Bool = false) {
        shouldRun = true
        if immediate {
            generation += 1
            runTask?.cancel()
            socket?.cancel(with: .goingAway, reason: nil)
            runTask = nil
        }
        guard runTask == nil else { return }
        if !immediate { generation += 1 }
        let activeGeneration = generation
        runTask = Task { await runLoop(generation: activeGeneration) }
    }

    public func disconnect() async {
        shouldRun = false
        generation += 1
        runTask?.cancel()
        runTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        if ownsSession {
            session.invalidateAndCancel()
        }
        await stateHandler(.disconnected)
    }

    private func runLoop(generation activeGeneration: Int) async {
        var attempt = 0
        while shouldRun && generation == activeGeneration && !Task.isCancelled {
            do {
                await stateHandler(.connecting)
                try await openAndReceive()
                attempt = 0
            } catch is CancellationError {
                break
            } catch {
                guard shouldRun && generation == activeGeneration && !Task.isCancelled else { break }
                await stateHandler(.unavailable(error.localizedDescription))
                let delay = delays[min(attempt, delays.count - 1)]
                attempt += 1
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    break
                }
            }
        }
        if generation == activeGeneration {
            socket = nil
            runTask = nil
        }
    }

    private func openAndReceive() async throws {
        let apiKey = try apiKeyProvider()
        let token = try await negotiate(apiKey: apiKey)
        let request = try webSocketRequest(connectionToken: token, apiKey: apiKey)
        let activeSocket = session.webSocketTask(with: request)
        socket = activeSocket
        activeSocket.resume()
        try await activeSocket.send(.data(SignalRProtocol.handshakeFrame()))
        await stateHandler(.connected)

        while shouldRun && !Task.isCancelled {
            let message = try await activeSocket.receive()
            let data: Data
            switch message {
            case .data(let value): data = value
            case .string(let value): data = Data(value.utf8)
            @unknown default: continue
            }
            for invocation in try SignalRProtocol.decodeFrames(data) {
                await invocationHandler(invocation)
            }
        }
    }

    private func negotiate(apiKey: String) async throws -> String {
        let url = baseURL
            .appendingPathComponent(hubPath)
            .appendingPathComponent("negotiate")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SignalRProtocolError.invalidFrame
        }
        components.queryItems = [URLQueryItem(name: "negotiateVersion", value: "1")]
        guard let negotiateURL = components.url else {
            throw SignalRProtocolError.invalidFrame
        }
        var request = URLRequest(url: negotiateURL, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw SlskdClientError.unavailable
        }
        let result = try JSONDecoder().decode(SignalRNegotiateResponse.self, from: data)
        guard result.supportsWebSockets else {
            throw SignalRProtocolError.webSocketsUnavailable
        }
        return result.connectionToken
    }

    private func webSocketRequest(connectionToken: String, apiKey: String) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(hubPath),
            resolvingAgainstBaseURL: false
        ) else {
            throw SignalRProtocolError.invalidFrame
        }
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components.queryItems = [URLQueryItem(name: "id", value: connectionToken)]
        guard let url = components.url else {
            throw SignalRProtocolError.invalidFrame
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        return request
    }
}
