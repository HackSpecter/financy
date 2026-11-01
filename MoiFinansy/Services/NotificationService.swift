import Foundation
import UserNotifications

/// Локальные уведомления: ежедневное напоминание, задачи, лимиты бюджетов.
enum NotificationService {
    static let dailyReminderID = "daily-reminder"

    private static var center: UNUserNotificationCenter { .current() }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func scheduleDailyReminder(minutes: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
        let content = UNMutableNotificationContent()
        content.title = "Khalid Finance"
        content.body = "Внеси расходы за сегодня — это займёт 10 секунд"
        content.sound = .default
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        components.timeZone = AppCalendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger))
    }

    static func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }

    static func schedulePlannerReminder(id: UUID, title: String, at date: Date) async {
        cancelPlannerReminder(id: id)
        guard date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Напоминание из «Планов»"
        content.sound = .default
        let components = AppCalendar.calendar.dateComponents(in: AppCalendar.timeZone, from: date)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(timeZone: AppCalendar.timeZone, year: components.year, month: components.month, day: components.day, hour: components.hour, minute: components.minute),
            repeats: false
        )
        try? await center.add(UNNotificationRequest(identifier: plannerID(id), content: content, trigger: trigger))
    }

    static func cancelPlannerReminder(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [plannerID(id)])
    }

    static func notifyNow(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    /// Разовое напоминание на дату (долги, подписки, итоги месяца).
    static func schedule(id: String, title: String, body: String, at date: Date) async {
        cancel(id: id)
        guard date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = AppCalendar.calendar.dateComponents(in: AppCalendar.timeZone, from: date)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(timeZone: AppCalendar.timeZone, year: components.year, month: components.month, day: components.day, hour: components.hour, minute: components.minute),
            repeats: false
        )
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func scheduleWeekly(id: String, weekday: Int, hour: Int, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.timeZone = AppCalendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    private static func plannerID(_ id: UUID) -> String { "planner-\(id.uuidString)" }
}
