import Foundation

public struct SignalRInvocation: Sendable {
    public let target: String
    public let arguments: [Data]

    public init(target: String, arguments: [Data]) {
        self.target = target
        self.arguments = arguments
    }
}

public struct SignalRNegotiateResponse: Decodable, Sendable {
    public struct Transport: Decodable, Sendable {
        public let transport: String
    }

    public let connectionToken: String
    public let availableTransports: [Transport]

    public var supportsWebSockets: Bool {
        availableTransports.contains {
            $0.transport.caseInsensitiveCompare("WebSockets") == .orderedSame
        }
    }
}

public enum SignalRProtocolError: LocalizedError, Sendable {
    case invalidFrame
    case webSocketsUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidFrame: "slskd sent an invalid SignalR frame."
        case .webSocketsUnavailable: "slskd did not offer a WebSocket transport."
        }
    }
}

public enum SignalRProtocol {
    public static let recordSeparator: UInt8 = 0x1e

    public static func handshakeFrame() throws -> Data {
        var data = try JSONSerialization.data(
            withJSONObject: ["protocol": "json", "version": 1]
        )
        data.append(recordSeparator)
        return data
    }

    public static func decodeFrames(_ data: Data) throws -> [SignalRInvocation] {
        try data.split(separator: recordSeparator).compactMap { frame in
            let object = try JSONSerialization.jsonObject(with: Data(frame), options: .fragmentsAllowed)
            guard let dictionary = object as? [String: Any] else {
                throw SignalRProtocolError.invalidFrame
            }
            guard dictionary["type"] as? Int == 1 else { return nil }
            guard
                let target = dictionary["target"] as? String,
                let arguments = dictionary["arguments"] as? [Any]
            else {
                throw SignalRProtocolError.invalidFrame
            }
            return SignalRInvocation(
                target: target,
                arguments: try arguments.map {
                    try JSONSerialization.data(withJSONObject: $0, options: .fragmentsAllowed)
                }
            )
        }
    }
}
