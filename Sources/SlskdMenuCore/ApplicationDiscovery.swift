import Foundation

public protocol ApplicationLocating {
    func URLForApplication(bundleIdentifier: String) -> URL?
    func URLForApplication(name: String) -> URL?
}

public struct DiscoveredApplications: Equatable, Sendable {
    public let nicotine: URL?
    public let soulseekQt: URL?

    public init(nicotine: URL?, soulseekQt: URL?) {
        self.nicotine = nicotine
        self.soulseekQt = soulseekQt
    }
}

public final class ApplicationDiscovery {
    public private(set) var current = DiscoveredApplications(nicotine: nil, soulseekQt: nil)

    public init() {}

    @discardableResult
    public func refresh(
        locator: ApplicationLocating,
        soulseekQtOverride: String?
    ) -> DiscoveredApplications {
        let nicotine = locator.URLForApplication(bundleIdentifier: "org.nicotine_plus.Nicotine")
            ?? locator.URLForApplication(name: "Nicotine+")
        let explicitSoulseekQt = soulseekQtOverride
            .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
            .flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        let soulseekQt = explicitSoulseekQt
            ?? locator.URLForApplication(name: "SoulseekQt")
            ?? locator.URLForApplication(name: "SoulseekQT")
        current = DiscoveredApplications(nicotine: nicotine, soulseekQt: soulseekQt)
        return current
    }
}
