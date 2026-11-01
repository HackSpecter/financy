import Foundation

/// Настройки в общем App Group — доступны приложению, виджетам и интентам.
nonisolated enum SharedDefaults {
    static let appGroup = "group.tj.khalid.hisob"

    static var store: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    enum Key {
        static let currency = "currencyCode"
        static let onboarded = "hasOnboarded"
        static let faceID = "faceIDEnabled"
        static let iCloud = "iCloudSyncEnabled"
        static let reminderEnabled = "dailyReminderEnabled"
        static let reminderMinutes = "dailyReminderMinutes"
        static let lastAccount = "lastAccountID"
        static let pendingQuickAdd = "pendingQuickAdd"
        static let budgetAlertPrefix = "budgetAlert."
    }

    static var currencyCode: String {
        store.string(forKey: Key.currency) ?? "TJS"
    }

    static var lastAccountID: UUID? {
        get { store.string(forKey: Key.lastAccount).flatMap(UUID.init(uuidString:)) }
        set { store.set(newValue?.uuidString, forKey: Key.lastAccount) }
    }

    static var iCloudSyncEnabled: Bool {
        store.bool(forKey: Key.iCloud)
    }

    static var pendingQuickAdd: Bool {
        get { store.bool(forKey: Key.pendingQuickAdd) }
        set { store.set(newValue, forKey: Key.pendingQuickAdd) }
    }
}
