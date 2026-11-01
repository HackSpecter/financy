import Foundation
import Observation

/// Наблюдаемые настройки для UI. Хранятся в общем App Group.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    private var storedCurrencyCode: String { didSet { defaults.set(storedCurrencyCode, forKey: SharedDefaults.Key.currency) } }
    /// Меняется при показе/скрытии сумм — экраны, читающие валюту, перерисовываются.
    private(set) var privacyRevision = 0

    var currencyCode: String {
        get {
            _ = privacyRevision
            return storedCurrencyCode
        }
        set { storedCurrencyCode = newValue }
    }

    var privacyEnabled: Bool {
        didSet {
            defaults.set(privacyEnabled, forKey: "privacy.enabled")
            Privacy.revealedUntil = .distantPast
            privacyRevision += 1
            WidgetRefresher.reload()
        }
    }

    var privacyRequiresFaceID: Bool { didSet { defaults.set(privacyRequiresFaceID, forKey: "privacy.faceID") } }

    /// Оформление: system / light / dark.
    var appearanceRaw: String { didSet { defaults.set(appearanceRaw, forKey: "appearance") } }

    var amountsHidden: Bool {
        _ = privacyRevision
        return Privacy.isMasked
    }

    /// Показать суммы на минуту (с Face ID, если включено).
    func revealAmounts() {
        guard privacyEnabled else { return }
        Task {
            if privacyRequiresFaceID, !(await BiometricService.authenticate(reason: "Показать суммы")) { return }
            Privacy.revealedUntil = .now.addingTimeInterval(60)
            privacyRevision += 1
            try? await Task.sleep(for: .seconds(61))
            privacyRevision += 1
        }
    }

    func hideAmounts() {
        Privacy.revealedUntil = .distantPast
        privacyRevision += 1
    }
    var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: SharedDefaults.Key.onboarded) } }
    var faceIDEnabled: Bool { didSet { defaults.set(faceIDEnabled, forKey: SharedDefaults.Key.faceID) } }
    var iCloudSyncEnabled: Bool { didSet { defaults.set(iCloudSyncEnabled, forKey: SharedDefaults.Key.iCloud) } }
    var dailyReminderEnabled: Bool { didSet { defaults.set(dailyReminderEnabled, forKey: SharedDefaults.Key.reminderEnabled) } }
    /// Минуты от полуночи; по умолчанию 21:00.
    var dailyReminderMinutes: Int { didSet { defaults.set(dailyReminderMinutes, forKey: SharedDefaults.Key.reminderMinutes) } }

    init(defaults: UserDefaults = SharedDefaults.store) {
        self.defaults = defaults
        storedCurrencyCode = defaults.string(forKey: SharedDefaults.Key.currency) ?? "TJS"
        privacyEnabled = defaults.bool(forKey: "privacy.enabled")
        privacyRequiresFaceID = defaults.bool(forKey: "privacy.faceID")
        appearanceRaw = defaults.string(forKey: "appearance") ?? "system"
        hasOnboarded = defaults.bool(forKey: SharedDefaults.Key.onboarded)
        faceIDEnabled = defaults.bool(forKey: SharedDefaults.Key.faceID)
        iCloudSyncEnabled = defaults.bool(forKey: SharedDefaults.Key.iCloud)
        dailyReminderEnabled = defaults.bool(forKey: SharedDefaults.Key.reminderEnabled)
        dailyReminderMinutes = defaults.object(forKey: SharedDefaults.Key.reminderMinutes) as? Int ?? 21 * 60
    }

    var reminderTime: Date {
        get {
            let start = AppCalendar.calendar.startOfDay(for: .now)
            return start.addingTimeInterval(TimeInterval(dailyReminderMinutes * 60))
        }
        set {
            let parts = AppCalendar.calendar.dateComponents([.hour, .minute], from: newValue)
            dailyReminderMinutes = (parts.hour ?? 21) * 60 + (parts.minute ?? 0)
        }
    }

    static let currencies = ["TJS", "USD", "EUR", "RUB", "UZS", "KZT"]
}
