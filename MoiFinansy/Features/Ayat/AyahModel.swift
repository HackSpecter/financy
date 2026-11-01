import Foundation
import Observation
import UserNotifications
import WidgetKit

/// Настройки и избранное «Аята» в приложении; любое изменение обновляет виджеты.
@Observable
final class AyahModel {
    static let shared = AyahModel()

    var settings: AyahSettings {
        didSet {
            AyahSettings.current = settings
            WidgetCenter.shared.reloadTimelines(ofKind: "AyahLockWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "AyahHomeWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "AyahTitleWidget")
            AyahNotifications.reschedule(settings)
        }
    }

    var favorites: [Int] {
        didSet {
            AyahSettings.favorites = favorites
            if settings.mode == .favorites {
                WidgetCenter.shared.reloadTimelines(ofKind: "AyahLockWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "AyahHomeWidget")
            }
        }
    }

    init() {
        settings = AyahSettings.current
        favorites = AyahSettings.favorites
    }

    func isFavorite(_ index: Int) -> Bool { favorites.contains(index) }

    func toggleFavorite(_ index: Int) {
        if let position = favorites.firstIndex(of: index) {
            favorites.remove(at: position)
        } else {
            favorites.append(index)
        }
    }
}

/// Ежедневное уведомление с аятом: 14 дней вперёд, у каждого дня свой аят.
enum AyahNotifications {
    static let prefix = "ayah-daily-"
    static let days = 14

    static func reschedule(_ settings: AyahSettings) {
        Task {
            // Сначала снимаем старые, затем ставим новые — иначе снятие могло бы удалить свежие.
            let center = UNUserNotificationCenter.current()
            let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            guard settings.dailyNotification, QuranStore.isAvailable else { return }
            let calendar = AppCalendar.calendar
            let today = calendar.startOfDay(for: .now)
            for day in 0..<days {
                guard let date = calendar.date(byAdding: .minute, value: day * 24 * 60 + settings.notificationMinutes, to: today), date > .now,
                      let pick = AyahPicker.current(settings: settings, surface: .lock(CGSize(width: 320, height: 160)), date: date) else { continue }
                await NotificationService.schedule(id: "\(prefix)\(day)-\(pick.index)", title: pick.inlineTitle, body: AyahTypography.russian(pick.text), at: date)
            }
        }
    }

    /// Номер аята из идентификатора уведомления «ayah-daily-<день>-<аят>».
    static func index(fromNotification identifier: String) -> Int? {
        guard identifier.hasPrefix(prefix) else { return nil }
        return identifier.split(separator: "-").last.flatMap { Int($0) }
    }
}
