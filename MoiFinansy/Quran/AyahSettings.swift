import Foundation

/// Как меняются аяты в виджете.
nonisolated enum AyahMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case byTime, sequential, random, sura, favorites
    var id: String { rawValue }

    var title: String {
        switch self {
        case .byTime: "Аят по времени"
        case .sequential: "По порядку"
        case .random: "Случайно"
        case .sura: "Выбранная сура"
        case .favorites: "Моё избранное"
        }
    }
}

/// Что делать, если аят не помещается в виджет экрана блокировки.
nonisolated enum AyahOverflow: String, CaseIterable, Codable, Sendable, Identifiable {
    case showBeginning, shortAyahSameSura
    var id: String { rawValue }
    var title: String {
        switch self {
        case .showBeginning: "Показать начало"
        case .shortAyahSameSura: "Короткий аят из той же суры"
        }
    }
}

/// Заголовок суры в основном виджете экрана блокировки.
nonisolated enum AyahLockTitle: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Скрыт, если над часами стоит виджет «Сура».
    case auto, show, hide
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Авто"
        case .show: "Показывать"
        case .hide: "Скрыть"
        }
    }
}

/// Настройки «Аята» — общие для приложения и виджетов (App Group).
nonisolated struct AyahSettings: Codable, Sendable, Hashable {
    var translation: QuranTranslation = .kuliev
    var style: AyahStyle = .classic
    var mode: AyahMode = .byTime
    var sura = 1
    var showArabicOnHome = false
    var overflow: AyahOverflow = .showBeginning
    var lockTitle: AyahLockTitle = .auto
    var arabicFont: ArabicFont = .amiriQuran
    var dailyNotification = false
    /// Минуты от полуночи; по умолчанию 8:00.
    var notificationMinutes = 8 * 60

    /// Стоит ли над часами виджет «Сура» (обновляет приложение и сам виджет).
    static var inlineWidgetInstalled: Bool {
        get { SharedDefaults.store.bool(forKey: "ayah.inlineInstalled") }
        set { SharedDefaults.store.set(newValue, forKey: "ayah.inlineInstalled") }
    }

    /// Настройки для экрана блокировки: заголовок скрыт, если так решено (вручную или «Авто» + виджет «Сура»).
    func resolvedForLock(inlineInstalled: Bool = AyahSettings.inlineWidgetInstalled) -> AyahSettings {
        var copy = self
        let hide = lockTitle == .hide || (lockTitle == .auto && inlineInstalled)
        if hide { copy.style.titlePosition = .hidden }
        return copy
    }

    init() {}

    /// Старые сохранённые настройки читаются без потери: отсутствующие поля — по умолчанию.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AyahSettings()
        translation = (try? c.decodeIfPresent(QuranTranslation.self, forKey: .translation)) ?? d.translation
        style = (try? c.decodeIfPresent(AyahStyle.self, forKey: .style)) ?? d.style
        mode = (try? c.decodeIfPresent(AyahMode.self, forKey: .mode)) ?? d.mode
        sura = (try? c.decodeIfPresent(Int.self, forKey: .sura)) ?? d.sura
        showArabicOnHome = (try? c.decodeIfPresent(Bool.self, forKey: .showArabicOnHome)) ?? d.showArabicOnHome
        overflow = (try? c.decodeIfPresent(AyahOverflow.self, forKey: .overflow)) ?? d.overflow
        lockTitle = (try? c.decodeIfPresent(AyahLockTitle.self, forKey: .lockTitle)) ?? d.lockTitle
        arabicFont = (try? c.decodeIfPresent(ArabicFont.self, forKey: .arabicFont)) ?? d.arabicFont
        dailyNotification = (try? c.decodeIfPresent(Bool.self, forKey: .dailyNotification)) ?? d.dailyNotification
        notificationMinutes = (try? c.decodeIfPresent(Int.self, forKey: .notificationMinutes)) ?? d.notificationMinutes
    }

    private static let key = "ayah.settings"
    private static let favoritesKey = "ayah.favorites"

    static var current: AyahSettings {
        get {
            guard let data = SharedDefaults.store.data(forKey: key),
                  var value = try? JSONDecoder().decode(AyahSettings.self, from: data) else { return AyahSettings() }
            // Один раз: новый режим по умолчанию и выравнивание по левому краю.
            if !SharedDefaults.store.bool(forKey: "ayah.migrated.v2") {
                SharedDefaults.store.set(true, forKey: "ayah.migrated.v2")
                value.mode = .byTime
                value.style.alignment = .leading
                SharedDefaults.store.set(try? JSONEncoder().encode(value), forKey: key)
            }
            return value
        }
        set {
            SharedDefaults.store.set(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }

    /// Избранные аяты — сквозные номера.
    static var favorites: [Int] {
        get { SharedDefaults.store.array(forKey: favoritesKey) as? [Int] ?? [] }
        set { SharedDefaults.store.set(newValue, forKey: favoritesKey) }
    }
}
