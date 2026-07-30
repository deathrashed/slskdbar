import AppKit
import SlskdMenuCore

@MainActor
protocol SettingsWindowActions: AnyObject {
    func settingsSnapshot() -> SlskdPreferences
    func saveSettings(_ settings: SlskdPreferences)
    func testConnection() async -> Result<ServerState, Error>
    func refreshApplicationsForSettings() -> DiscoveredApplications
}

@MainActor
final class SettingsWindowController: NSWindowController {
    weak var actions: SettingsWindowActions?

    private let loginItems = LoginItemController()
    private let tabController = NSTabViewController()
    private let baseURLField = NSTextField()
    private let runtimeConfigField = NSTextField()
    private let downloadsField = NSTextField()
    private let configField = NSTextField()
    private let logsField = NSTextField()
    private let dataField = NSTextField()
    private let soulseekQtField = NSTextField()
    private let notificationsButton = NSButton(checkboxWithTitle: "Notify on unexpected connection changes", target: nil, action: nil)
    private let countsButton = NSButton(checkboxWithTitle: "Show active transfer counts beside the icon", target: nil, action: nil)
    private let loginButton = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)
    private let connectionLabel = NSTextField(labelWithString: "Event-driven · Not tested")
    private let appsLabel = NSTextField(labelWithString: "")
    private let iconProvider = StatusIconProvider()
    private var iconViews: [MenuConnectionState: NSImageView] = [:]
    private var iconPaths: [MenuConnectionState: String] = [:]

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "slskdbar Settings"
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        tabController.selectedTabViewItemIndex = 0
        reload()
        super.showWindow(sender)
        window?.orderFrontRegardless()
    }

    private func buildUI() {
        tabController.addTabViewItem(tab(title: "General", view: generalView()))
        tabController.addTabViewItem(tab(title: "Locations & Apps", view: locationsView()))
        tabController.addTabViewItem(tab(title: "Appearance", view: appearanceView()))
        tabController.selectedTabViewItemIndex = 0

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        let footer = NSStackView(views: [NSView(), saveButton])
        footer.orientation = .horizontal

        let root = NSStackView(views: [tabController.view, footer])
        root.orientation = .vertical
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 14, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false
        window?.contentView = root
        NSLayoutConstraint.activate([
            tabController.view.heightAnchor.constraint(equalToConstant: 390),
            root.widthAnchor.constraint(greaterThanOrEqualToConstant: 620),
        ])
    }

    private func generalView() -> NSView {
        loginButton.target = self
        loginButton.action = #selector(toggleLoginItem)
        notificationsButton.target = self
        notificationsButton.action = #selector(requestNotifications)
        let testButton = NSButton(title: "Test", target: self, action: #selector(testConnection))
        return form(rows: [
            ("Startup", loginButton),
            ("slskd URL", fieldRow(baseURLField, button: testButton)),
            ("Status monitoring", connectionLabel),
            ("Notifications", notificationsButton),
            ("Menu-bar activity", countsButton),
        ])
    }

    private func locationsView() -> NSView {
        return form(rows: [
            ("Runtime config", fieldRow(runtimeConfigField, button: chooseButton("runtime"))),
            ("Downloads", fieldRow(downloadsField, button: chooseButton("downloads"))),
            ("Config", fieldRow(configField, button: chooseButton("config"))),
            ("Logs", fieldRow(logsField, button: chooseButton("logs"))),
            ("Data", fieldRow(dataField, button: chooseButton("data"))),
            ("SoulseekQt", fieldRow(soulseekQtField, button: chooseButton("soulseek"))),
            ("Detected apps", appsLabel),
        ])
    }

    private func appearanceView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        for state in MenuConnectionState.allCases {
            let preview = NSImageView()
            preview.imageScaling = .scaleProportionallyUpOrDown
            preview.widthAnchor.constraint(equalToConstant: 24).isActive = true
            preview.heightAnchor.constraint(equalToConstant: 24).isActive = true
            iconViews[state] = preview
            let choose = NSButton(title: "Choose…", target: self, action: #selector(chooseIcon(_:)))
            choose.identifier = NSUserInterfaceItemIdentifier(state.rawValue)
            let reset = NSButton(title: "Reset", target: self, action: #selector(resetIcon(_:)))
            reset.identifier = NSUserInterfaceItemIdentifier(state.rawValue)
            let row = NSStackView(views: [
                preview,
                NSTextField(labelWithString: state.rawValue.capitalized),
                NSView(),
                choose,
                reset,
            ])
            row.orientation = .horizontal
            stack.addArrangedSubview(row)
        }
        let resetAll = NSButton(title: "Reset All Icons", target: self, action: #selector(resetAllIcons))
        stack.addArrangedSubview(resetAll)
        return padded(stack)
    }

    private func tab(title: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(viewController: NSViewController())
        item.label = title
        item.viewController?.view = view
        return item
    }

    private func form(rows: [(String, NSView)]) -> NSView {
        let grid = NSGridView(views: rows.map {
            [NSTextField(labelWithString: $0.0), $0.1]
        })
        grid.column(at: 0).width = 135
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        return padded(grid)
    }

    private func padded(_ view: NSView) -> NSView {
        let container = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
        ])
        return container
    }

    private func fieldRow(_ field: NSTextField, button: NSButton) -> NSView {
        field.placeholderString = "Path"
        let row = NSStackView(views: [field, button])
        row.orientation = .horizontal
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true
        return row
    }

    private func chooseButton(_ identifier: String) -> NSButton {
        let button = NSButton(title: "Choose…", target: self, action: #selector(choosePath(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        return button
    }

    private func reload() {
        guard let settings = actions?.settingsSnapshot() else { return }
        baseURLField.stringValue = settings.baseURL.absoluteString
        runtimeConfigField.stringValue = settings.runtimeConfigPath
        downloadsField.stringValue = settings.downloadsPath
        configField.stringValue = settings.configFolderPath
        logsField.stringValue = settings.logsPath
        dataField.stringValue = settings.dataPath
        soulseekQtField.stringValue = settings.soulseekQtPath ?? ""
        notificationsButton.state = settings.connectionNotifications ? .on : .off
        countsButton.state = settings.showTransferCounts ? .on : .off
        loginButton.state = loginItems.isEnabled ? .on : .off
        iconPaths = settings.customIconPaths
        refreshIconPreviews()
        let apps = actions?.refreshApplicationsForSettings()
        appsLabel.stringValue = [
            apps?.nicotine == nil ? "Nicotine+: not found" : "Nicotine+: installed",
            apps?.soulseekQt == nil ? "SoulseekQt: not found" : "SoulseekQt: installed",
        ].joined(separator: " · ")
    }

    @objc private func save() {
        guard
            let actions,
            let url = URL(string: baseURLField.stringValue),
            ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else {
            connectionLabel.stringValue = "Invalid slskd URL"
            return
        }
        var settings = actions.settingsSnapshot()
        settings.baseURL = url
        settings.runtimeConfigPath = runtimeConfigField.stringValue
        settings.downloadsPath = downloadsField.stringValue
        settings.configFolderPath = configField.stringValue
        settings.logsPath = logsField.stringValue
        settings.dataPath = dataField.stringValue
        let soulseek = soulseekQtField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.soulseekQtPath = soulseek.isEmpty ? nil : soulseek
        settings.connectionNotifications = notificationsButton.state == .on
        settings.showTransferCounts = countsButton.state == .on
        settings.customIconPaths = iconPaths
        actions.saveSettings(settings)
        connectionLabel.stringValue = "Saved · Event-driven"
    }

    @objc private func toggleLoginItem() {
        do {
            try loginItems.setEnabled(loginButton.state == .on)
        } catch {
            loginButton.state = loginItems.isEnabled ? .on : .off
            connectionLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func requestNotifications() {
        guard notificationsButton.state == .on else { return }
        Task { await NotificationController().requestPermission() }
    }

    @objc private func testConnection() {
        connectionLabel.stringValue = "Testing…"
        Task {
            switch await actions?.testConnection() {
            case .success(let state):
                connectionLabel.stringValue = state.isLoggedIn ? "Event-driven · Connected" : "Event-driven · Reachable"
            case .failure(let error):
                connectionLabel.stringValue = error.localizedDescription
            case nil:
                connectionLabel.stringValue = "Unavailable"
            }
        }
    }

    @objc private func choosePath(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = sender.identifier?.rawValue != "runtime" && sender.identifier?.rawValue != "soulseek"
        panel.canChooseFiles = !panel.canChooseDirectories
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let path = panel.url?.path else { return }
        switch sender.identifier?.rawValue {
        case "runtime": runtimeConfigField.stringValue = path
        case "downloads": downloadsField.stringValue = path
        case "config": configField.stringValue = path
        case "logs": logsField.stringValue = path
        case "data": dataField.stringValue = path
        case "soulseek": soulseekQtField.stringValue = path
        default: break
        }
    }

    @objc private func chooseIcon(_ sender: NSButton) {
        guard
            let raw = sender.identifier?.rawValue,
            let state = MenuConnectionState(rawValue: raw)
        else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .svg]
        guard panel.runModal() == .OK, let url = panel.url, NSImage(contentsOf: url) != nil else { return }
        iconPaths[state] = url.path
        refreshIconPreviews()
    }

    @objc private func resetIcon(_ sender: NSButton) {
        guard
            let raw = sender.identifier?.rawValue,
            let state = MenuConnectionState(rawValue: raw)
        else { return }
        iconPaths.removeValue(forKey: state)
        refreshIconPreviews()
    }

    @objc private func resetAllIcons() {
        iconPaths.removeAll()
        refreshIconPreviews()
    }

    private func refreshIconPreviews() {
        for state in MenuConnectionState.allCases {
            iconViews[state]?.image = iconProvider.image(for: state, customPath: iconPaths[state])
        }
    }
}
