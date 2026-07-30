import AppKit
import SlskdMenuCore

struct AppKitApplicationLocator: ApplicationLocating {
    func URLForApplication(bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    func URLForApplication(name: String) -> URL? {
        [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
            .map { $0.appendingPathComponent("\(name).app") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
