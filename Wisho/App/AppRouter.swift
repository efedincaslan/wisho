import Foundation
import UIKit
import UserNotifications
import Observation

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    struct SendRequest: Identifiable {
        let id = UUID()
        let personId: UUID
        let isBelated: Bool
    }

    /// Non-nil presents the Send Sheet for that person.
    var pendingSend: SendRequest?
    /// Set after the user's first successful send to trigger the soft PRO prompt.
    var showPostSendPaywall = false

    private init() {}

    func openSendSheet(personId: UUID, isBelated: Bool) {
        pendingSend = SendRequest(personId: personId, isBelated: isBelated)
    }
}

/// Routes notification taps (day-of, heads-up, rescue) into the Send Sheet.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let idString = info[NotificationEngine.UserInfoKey.personId] as? String,
           let personId = UUID(uuidString: idString) {
            let isBelated = (info[NotificationEngine.UserInfoKey.kind] as? String) == NotificationEngine.Kind.rescue.rawValue
            Task { @MainActor in
                AppRouter.shared.openSendSheet(personId: personId, isBelated: isBelated)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationDelegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Delegate must be set before the first notification tap is delivered.
        UNUserNotificationCenter.current().delegate = notificationDelegate
        Task { @MainActor in
            NotificationEngine.shared.registerCategories()
        }
        return true
    }
}
