import AppKit
import SlskdMenuCore

@MainActor
protocol StatusMenuActions: AnyObject {
    func requestConnect()
    func requestDisconnect()
    func loadTransferSummary() async throws -> TransferSummary
    func clearCompletedDownloads() async throws
    func clearCompletedUploads() async throws
    func refreshNow()
    func showSettings()
    func refreshApplications() -> DiscoveredApplications
    func preferencesSnapshot() -> SlskdPreferences
}

@MainActor
final class StatusIconProvider {
    private let resourceRoot: URL

    init() {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Icons"),
           FileManager.default.fileExists(atPath: bundled.path) {
            resourceRoot = bundled
        } else {
            resourceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/Icons")
        }
    }

    func image(for state: MenuConnectionState, customPath: String?) -> NSImage? {
        let stem: String
        switch state {
        case .connected: stem = "slskd-color-icon"
        case .disconnected: stem = "slskd-white-icon"
        case .connecting: stem = "slskd-green-icon"
        case .unavailable: stem = "slskd-red-icon"
        }

        let candidates = [
            customPath.map { URL(fileURLWithPath: $0) },
            resourceRoot.appendingPathComponent("\(stem).svg"),
            resourceRoot.appendingPathComponent("\(stem).png"),
        ].compactMap { $0 }

        guard let image = candidates.lazy.compactMap({ NSImage(contentsOf: $0) }).first else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = state == .disconnected
        return image
    }
}

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    weak var actions: StatusMenuActions?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let iconProvider = StatusIconProvider()
    private let stateItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let downloadsItem = NSMenuItem(title: "Downloads: Not loaded", action: nil, keyEquivalent: "")
    private let uploadsItem = NSMenuItem(title: "Uploads: Not loaded", action: nil, keyEquivalent: "")
    private let connectionItem = NSMenuItem(title: "Connect", action: #selector(toggleConnection), keyEquivalent: "d")
    private let nicotineLaunchItem = NSMenuItem(title: "Launch Nicotine+", action: #selector(launchNicotine), keyEquivalent: "")
    private let soulseekLaunchItem = NSMenuItem(title: "Launch SoulseekQt", action: #selector(launchSoulseekQt), keyEquivalent: "")
    private var state: MenuConnectionState = .connecting
    private var transferTask: Task<Void, Never>?
    private var applications = DiscoveredApplications(nicotine: nil, soulseekQt: nil)
    private var activeCounts = (downloads: 0, uploads: 0)

    override init() {
        super.init()
        statusItem.menu = menu
        menu.delegate = self
        buildMenu()
        update(state: .connecting, detail: "Connecting to slskd…")
    }

    func update(state: MenuConnectionState, detail: String) {
        self.state = state
        stateItem.title = detail
        connectionItem.title = state == .connected || state == .connecting ? "Disconnect" : "Connect"
        connectionItem.isEnabled = state != .unavailable
        let preferences = actions?.preferencesSnapshot() ?? .defaults
        statusItem.button?.image = iconProvider.image(
            for: state,
            customPath: preferences.customIconPaths[state]
        )
        statusItem.button?.imagePosition = .imageLeading
        updateTransferCountTitle(enabled: preferences.showTransferCounts)
    }

    func updateTransferCounts(downloads: Int, uploads: Int, enabled: Bool) {
        activeCounts = (downloads, uploads)
        updateTransferCountTitle(enabled: enabled)
    }

    func updateApplications(_ applications: DiscoveredApplications) {
        self.applications = applications
        nicotineLaunchItem.isEnabled = applications.nicotine != nil
        soulseekLaunchItem.isEnabled = applications.soulseekQt != nil
    }

    func refreshAppearance() {
        update(state: state, detail: stateItem.title)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateApplications(actions?.refreshApplications() ?? applications)
        transferTask?.cancel()
        downloadsItem.title = "Downloads: Loading…"
        uploadsItem.title = "Uploads: Loading…"
        transferTask = Task { [weak self] in
            do {
                guard let summary = try await self?.actions?.loadTransferSummary() else { return }
                guard !Task.isCancelled else { return }
                self?.downloadsItem.title = "Downloads: \(summary.activeDownloads) active · \(Self.speed(summary.downloadSpeed))"
                self?.uploadsItem.title = "Uploads: \(summary.activeUploads) active · \(Self.speed(summary.uploadSpeed))"
            } catch {
                guard !Task.isCancelled else { return }
                self?.downloadsItem.title = "Downloads: Unavailable"
                self?.uploadsItem.title = "Uploads: Unavailable"
            }
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        transferTask?.cancel()
        transferTask = nil
    }

    private func buildMenu() {
        stateItem.isEnabled = false
        downloadsItem.isEnabled = false
        uploadsItem.isEnabled = false
        menu.addItem(stateItem)
        addSection("Transfers")
        menu.addItem(downloadsItem)
        menu.addItem(uploadsItem)

        addSection("Actions")
        connectionItem.target = self
        menu.addItem(connectionItem)
        let clearItem = NSMenuItem(title: "Clear Completed", action: nil, keyEquivalent: "")
        let clearMenu = NSMenu()
        clearMenu.addItem(item("Downloads", #selector(clearDownloads)))
        clearMenu.addItem(item("Uploads", #selector(clearUploads)))
        clearMenu.addItem(item("All Transfers", #selector(clearAll)))
        clearItem.submenu = clearMenu
        menu.addItem(clearItem)

        addSection("Open")
        menu.addItem(item("Dashboard", #selector(openDashboard), "o"))
        menu.addItem(item("Downloads", #selector(openDownloads)))
        let moreItem = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
        moreItem.submenu = buildMoreMenu()
        menu.addItem(moreItem)

        menu.addItem(.separator())
        menu.addItem(item("Refresh Now", #selector(refreshNow), "r"))
        menu.addItem(item("Settings…", #selector(showSettings), ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit slskdbar", #selector(quit), "q"))
    }

    private func buildMoreMenu() -> NSMenu {
        let more = NSMenu()
        more.addItem(.sectionHeader(title: "FOLDERS"))
        more.addItem(item("Config", #selector(openConfig)))
        more.addItem(item("Logs", #selector(openLogs)))
        more.addItem(item("Data", #selector(openData)))
        more.addItem(.separator())
        more.addItem(.sectionHeader(title: "APPS"))

        let nicotine = NSMenuItem(title: "Nicotine+", action: nil, keyEquivalent: "")
        let nicotineMenu = NSMenu()
        nicotineLaunchItem.target = self
        nicotineMenu.addItem(nicotineLaunchItem)
        nicotineMenu.addItem(item("Open Download Page", #selector(downloadNicotine)))
        nicotine.submenu = nicotineMenu
        more.addItem(nicotine)

        let soulseek = NSMenuItem(title: "SoulseekQt", action: nil, keyEquivalent: "")
        let soulseekMenu = NSMenu()
        soulseekLaunchItem.target = self
        soulseekMenu.addItem(soulseekLaunchItem)
        soulseekMenu.addItem(item("Open Download Page", #selector(downloadSoulseekQt)))
        soulseek.submenu = soulseekMenu
        more.addItem(soulseek)
        return more
    }

    private func addSection(_ title: String) {
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: title.uppercased()))
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let result = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        result.isEnabled = false
        return result
    }

    private func item(_ title: String, _ action: Selector, _ key: String = "") -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key)
        result.target = self
        return result
    }

    private func updateTransferCountTitle(enabled: Bool) {
        guard enabled, activeCounts.downloads > 0 || activeCounts.uploads > 0 else {
            statusItem.button?.title = ""
            return
        }
        statusItem.button?.title = "↓\(activeCounts.downloads) ↑\(activeCounts.uploads)"
    }

    private static func speed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    private func open(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func toggleConnection() {
        if state == .connected || state == .connecting {
            actions?.requestDisconnect()
        } else {
            actions?.requestConnect()
        }
    }

    @objc private func clearDownloads() { Task { try? await actions?.clearCompletedDownloads() } }
    @objc private func clearUploads() { Task { try? await actions?.clearCompletedUploads() } }
    @objc private func clearAll() {
        Task {
            try? await actions?.clearCompletedDownloads()
            try? await actions?.clearCompletedUploads()
        }
    }
    @objc private func openDashboard() {
        let base = actions?.preferencesSnapshot().baseURL ?? SlskdPreferences.defaults.baseURL
        NSWorkspace.shared.open(base)
    }
    @objc private func openDownloads() { open(path: actions?.preferencesSnapshot().downloadsPath ?? "") }
    @objc private func openConfig() { open(path: actions?.preferencesSnapshot().configFolderPath ?? "") }
    @objc private func openLogs() { open(path: actions?.preferencesSnapshot().logsPath ?? "") }
    @objc private func openData() { open(path: actions?.preferencesSnapshot().dataPath ?? "") }
    @objc private func launchNicotine() {
        if let url = applications.nicotine { NSWorkspace.shared.open(url) }
    }
    @objc private func launchSoulseekQt() {
        if let url = applications.soulseekQt { NSWorkspace.shared.open(url) }
    }
    @objc private func downloadNicotine() {
        NSWorkspace.shared.open(URL(string: "https://nicotine-plus.org/doc/DOWNLOADS.html")!)
    }
    @objc private func downloadSoulseekQt() {
        NSWorkspace.shared.open(URL(string: "https://www.slsknet.org/news/node/1")!)
    }
    @objc private func refreshNow() { actions?.refreshNow() }
    @objc private func showSettings() { actions?.showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
