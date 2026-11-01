import SwiftData
import Foundation
import UserNotifications

/// Обработка тапа по уведомлению: вечернее напоминание → быстрое добавление, задача → «Планы».
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Нажатие на уведомление. iOS требует вызвать `completionHandler` в основном потоке —
    /// асинхронная версия завершалась в фоне, и на iOS 27 приложение падало при открытии из уведомления.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        let action = response.actionIdentifier
        let transactionID = response.notification.request.content.userInfo[InboxNotifications.transactionKey] as? String
        nonisolated(unsafe) let finish = completionHandler
        Self.onMain {
            // Кнопка категории — разбираем операцию без открытия экрана.
            if !InboxNotifications.handle(action: action, transactionID: transactionID, in: DataStore.shared.mainContext) {
                Self.route(id)
            }
            finish()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        nonisolated(unsafe) let finish = completionHandler
        Self.onMain { finish([.banner, .sound, .list]) }
    }

    /// Выполняет сразу, если уже в основном потоке (так iOS вызывает делегата), иначе — переходит в него.
    nonisolated private static func onMain(_ work: @escaping @MainActor @Sendable () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { work() }
        } else {
            Task { @MainActor in work() }
        }
    }

    static func route(_ identifier: String) {
        let router = AppRouter.shared
        if identifier == NotificationService.dailyReminderID {
            router.selectedTab = .transactions
            router.openQuickAdd()
        } else if identifier.hasPrefix("inbox-") {
            router.selectedTab = .transactions
            router.isInboxPresented = true
        } else if let index = AyahNotifications.index(fromNotification: identifier) {
            router.presentedAyah = AppRouter.AyahLink(index: index)
        } else if identifier.hasPrefix("envelopes-") {
            router.presentedTool = .envelopes
        } else if identifier.hasPrefix("month-close-") {
            router.presentedTool = .monthClose
        } else if identifier.hasPrefix("weekly-review") {
            router.presentedTool = .weeklyReview
        } else if identifier.hasPrefix("planner-") {
            router.selectedTab = .planner
        } else if identifier.hasPrefix(SharedDefaults.Key.budgetAlertPrefix) {
            router.selectedTab = .reports
        }
    }
}
