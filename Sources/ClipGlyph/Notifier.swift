import Foundation
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

    static func setUp() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if let error { log.error("Notification permission error: \(error.localizedDescription, privacy: .public)") }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func post(_ title: String, body: String) {
        guard Settings.notify else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body.count > 200 ? String(body.prefix(200)) + "…" : body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { log.error("Notification failed: \(error.localizedDescription, privacy: .public)") }
        }
    }
}
