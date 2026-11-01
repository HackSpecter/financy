import Foundation

/// Режим приватности: суммы скрыты, пока пользователь их не откроет.
nonisolated enum Privacy {
    static var isEnabled: Bool { SharedDefaults.store.bool(forKey: "privacy.enabled") }
    static var requiresAuthentication: Bool { SharedDefaults.store.bool(forKey: "privacy.faceID") }

    static var revealedUntil: Date {
        get { SharedDefaults.store.object(forKey: "privacy.revealedUntil") as? Date ?? .distantPast }
        set { SharedDefaults.store.set(newValue, forKey: "privacy.revealedUntil") }
    }

    static var isMasked: Bool { isEnabled && revealedUntil < .now }
}
