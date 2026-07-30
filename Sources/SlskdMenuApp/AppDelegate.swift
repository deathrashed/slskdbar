import AppKit
import SlskdMenuCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PreferencesStore()
    private let discovery = ApplicationDiscovery()
    private let locator = AppKitApplicationLocator()
    private let statusMenu = StatusMenuController()
    private let settingsWindow = SettingsWindowController()
    private let notifications = NotificationController()
    private var preferences = SlskdPreferences.defaults
    private var applications = DiscoveredApplications(nicotine: nil, soulseekQt: nil)
    private var restClient: SlskdRESTClient!
    private var applicationConnection: SignalRConnection?
    private var metricsConnection: SignalRConnection?
    private var currentState = MenuConnectionState.connecting

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences = store.load()
        statusMenu.actions = self
        settingsWindow.actions = self
        applications = discoverApplications()
        statusMenu.updateApplications(applications)
        rebuildServices()
        if preferences.connectionNotifications {
            Task { await notifications.requestPermission() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        let applicationConnection = self.applicationConnection
        let metricsConnection = self.metricsConnection
        Task {
            await applicationConnection?.disconnect()
            await metricsConnection?.disconnect()
        }
    }

    private func rebuildServices() {
        let oldApplicationConnection = applicationConnection
        let oldMetricsConnection = metricsConnection
        Task {
            await oldApplicationConnection?.disconnect()
            await oldMetricsConnection?.disconnect()
        }

        let baseURL = preferences.baseURL
        let configURL = URL(fileURLWithPath: preferences.runtimeConfigPath)
        restClient = SlskdRESTClient(
            baseURLProvider: { baseURL },
            configURLProvider: { configURL }
        )

        applicationConnection = SignalRConnection(
            baseURL: baseURL,
            hubPath: "/hub/application",
            apiKeyProvider: { try RuntimeConfig.apiKey(at: configURL) },
            invocationHandler: { [weak self] invocation in
                await self?.handleApplicationInvocation(invocation)
            },
            stateHandler: { [weak self] transportState in
                await self?.handleApplicationTransport(transportState)
            }
        )
        Task { await applicationConnection?.connect(immediate: true) }
        configureMetricsConnection()
    }

    private func configureMetricsConnection() {
        let oldMetricsConnection = metricsConnection
        metricsConnection = nil
        Task { await oldMetricsConnection?.disconnect() }
        statusMenu.updateTransferCounts(downloads: 0, uploads: 0, enabled: preferences.showTransferCounts)
        guard preferences.showTransferCounts else { return }

        let baseURL = preferences.baseURL
        let configURL = URL(fileURLWithPath: preferences.runtimeConfigPath)
        let connection = SignalRConnection(
            baseURL: baseURL,
            hubPath: "/hub/metrics",
            apiKeyProvider: { try RuntimeConfig.apiKey(at: configURL) },
            invocationHandler: { [weak self] invocation in
                await self?.handleMetricsInvocation(invocation)
            },
            stateHandler: { _ in }
        )
        metricsConnection = connection
        Task { await connection.connect(immediate: true) }
    }

    private func handleApplicationInvocation(_ invocation: SignalRInvocation) {
        guard
            invocation.target.uppercased() == "STATE",
            let data = invocation.arguments.first,
            let state = try? JSONDecoder().decode(ApplicationStateEnvelope.self, from: data)
        else {
            return
        }
        apply(state.server.menuState, detail: detail(for: state.server))
    }

    private func handleMetricsInvocation(_ invocation: SignalRInvocation) {
        guard
            invocation.target.caseInsensitiveCompare("Update") == .orderedSame,
            let data = invocation.arguments.first,
            let metrics = try? JSONDecoder().decode(MetricsEnvelope.self, from: data)
        else {
            return
        }
        let counts = metrics.activeCounts
        statusMenu.updateTransferCounts(
            downloads: counts.downloads,
            uploads: counts.uploads,
            enabled: preferences.showTransferCounts
        )
    }

    private func handleApplicationTransport(_ state: SignalRTransportState) {
        switch state {
        case .connecting:
            if currentState != .connected {
                apply(.connecting, detail: "Connecting to slskd…")
            }
        case .connected:
            break
        case .disconnected:
            break
        case .unavailable(let message):
            apply(.unavailable, detail: message.isEmpty ? "slskd unavailable" : "slskd unavailable")
        }
    }

    private func apply(_ state: MenuConnectionState, detail: String) {
        currentState = state
        notifications.observe(state, enabled: preferences.connectionNotifications)
        statusMenu.update(state: state, detail: detail)
    }

    private func detail(for state: ServerState) -> String {
        switch state.menuState {
        case .connected: "Connected to Soulseek · Logged in"
        case .connecting: "Connecting to Soulseek…"
        case .disconnected: "Disconnected from Soulseek"
        case .unavailable: "slskd unavailable"
        }
    }

    private func discoverApplications() -> DiscoveredApplications {
        applications = discovery.refresh(
            locator: locator,
            soulseekQtOverride: preferences.soulseekQtPath
        )
        statusMenu.updateApplications(applications)
        return applications
    }

    @objc private func didWake() {
        Task {
            await applicationConnection?.connect(immediate: true)
            if preferences.showTransferCounts {
                await metricsConnection?.connect(immediate: true)
            }
        }
    }
}

extension AppDelegate: StatusMenuActions {
    func requestConnect() {
        notifications.markManualTransition()
        apply(.connecting, detail: "Connecting to Soulseek…")
        Task {
            do {
                try await restClient.connect()
                await applicationConnection?.connect(immediate: true)
            } catch {
                apply(.unavailable, detail: error.localizedDescription)
            }
        }
    }

    func requestDisconnect() {
        notifications.markManualTransition()
        Task {
            do {
                try await restClient.disconnect(message: "Disconnected from slskdbar")
                apply(.disconnected, detail: "Disconnected from Soulseek")
            } catch {
                apply(.unavailable, detail: error.localizedDescription)
            }
        }
    }

    func loadTransferSummary() async throws -> TransferSummary {
        try await restClient.transferSummary()
    }

    func clearCompletedDownloads() async throws {
        try await restClient.clearCompletedDownloads()
    }

    func clearCompletedUploads() async throws {
        try await restClient.clearCompletedUploads()
    }

    func refreshNow() {
        _ = discoverApplications()
        Task {
            await applicationConnection?.connect(immediate: true)
            if preferences.showTransferCounts {
                await metricsConnection?.connect(immediate: true)
            }
            do {
                let state = try await restClient.serverState()
                apply(state.menuState, detail: detail(for: state))
            } catch {
                apply(.unavailable, detail: error.localizedDescription)
            }
        }
    }

    func showSettings() {
        settingsWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshApplications() -> DiscoveredApplications {
        discoverApplications()
    }

    func preferencesSnapshot() -> SlskdPreferences {
        preferences
    }
}

extension AppDelegate: SettingsWindowActions {
    func settingsSnapshot() -> SlskdPreferences {
        preferences
    }

    func saveSettings(_ settings: SlskdPreferences) {
        let connectionChanged = settings.baseURL != preferences.baseURL
            || settings.runtimeConfigPath != preferences.runtimeConfigPath
        let metricsChanged = settings.showTransferCounts != preferences.showTransferCounts
        preferences = settings
        try? store.save(settings)
        statusMenu.refreshAppearance()
        _ = discoverApplications()
        if connectionChanged {
            rebuildServices()
        } else if metricsChanged {
            configureMetricsConnection()
        }
        if settings.connectionNotifications {
            Task { await notifications.requestPermission() }
        }
    }

    func testConnection() async -> Result<ServerState, Error> {
        do {
            return .success(try await restClient.serverState())
        } catch {
            return .failure(error)
        }
    }

    func refreshApplicationsForSettings() -> DiscoveredApplications {
        discoverApplications()
    }
}
