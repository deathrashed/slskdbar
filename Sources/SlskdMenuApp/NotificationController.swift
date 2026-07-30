import Foundation
import SlskdMenuCore
import UserNotifications

@MainActor
final class NotificationController {
    private var previousState: MenuConnectionState?
    private var suppressNextTransition = false

    func markManualTransition() {
        suppressNextTransition = true
    }

    func requestPermission() async {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func observe(_ state: MenuConnectionState, enabled: Bool) {
        defer {
            previousState = state
            suppressNextTransition = false
        }
        guard enabled, let previousState, previousState != state, !suppressNextTransition else {
            return
        }
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }

        let body: String?
        switch (previousState, state) {
        case (.connected, .disconnected):
            body = "Soulseek disconnected."
        case (_, .unavailable):
            body = "slskd is unavailable."
        case (.unavailable, .connected), (.disconnected, .connected), (.connecting, .connected):
            body = "Soulseek is connected again."
        default:
            body = nil
        }
        guard let body else { return }
        let content = UNMutableNotificationContent()
        content.title = "slskdbar"
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
