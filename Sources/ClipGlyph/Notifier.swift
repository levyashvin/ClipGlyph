import AppKit
import UserNotifications

/// Optional banners describing what happened. Off by default.
enum Notifier {
    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([.banner])
        }
    }
    private static let delegate = Delegate()

    /// UNUserNotificationCenter throws (crashing the app) when not running from an .app bundle, e.g. `swift run`.
    private static let available = Bundle.main.bundleURL.pathExtension == "app"

    static func setUp() {
        guard available else { return }
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        guard available else { return completion(false) }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if let error { log.error("Notification permission error: \(error.localizedDescription, privacy: .public)") }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Calls back on the main queue with true when the user has blocked notifications in System Settings.
    static func checkDenied(_ completion: @escaping (Bool) -> Void) {
        guard available else { return completion(false) }
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { completion(s.authorizationStatus == .denied) }
        }
    }

    static func openSystemSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }

    static func post(_ title: String, body: String) {
        guard available, Settings.notify else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body.count > 200 ? String(body.prefix(200)) + "…" : body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { log.error("Notification failed: \(error.localizedDescription, privacy: .public)") }
        }
    }
}
