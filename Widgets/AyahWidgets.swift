import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Настройки в редактировании виджета

nonisolated extension QuranTranslation: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Перевод"
    static let caseDisplayRepresentations: [QuranTranslation: DisplayRepresentation] = [
        .kuliev: "Кулиев", .osmanov: "Османов", .krachkovsky: "Крачковский",
    ]
}

nonisolated extension AyahFont: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Шрифт"
    static let caseDisplayRepresentations: [AyahFont: DisplayRepresentation] = [
        .newYork: "New York", .sfRounded: "SF Pro Rounded", .cormorant: "Cormorant Garamond",
        .lora: "Lora", .ptSerif: "PT Serif", .playfair: "Playfair Display",
    ]
}

nonisolated extension AyahStyle.Size: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Размер"
    static let caseDisplayRepresentations: [AyahStyle.Size: DisplayRepresentation] = [
        .small: "Мелкий", .medium: "Средний", .large: "Крупный", .extraLarge: "Очень крупный",
    ]
}

nonisolated extension AyahStyle.Alignment: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Выравнивание"
    static let caseDisplayRepresentations: [AyahStyle.Alignment: DisplayRepresentation] = [
        .leading: "Слева", .center: "По центру",
    ]
}

nonisolated extension AyahStyle.TitlePosition: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Заголовок"
    static let caseDisplayRepresentations: [AyahStyle.TitlePosition: DisplayRepresentation] = [
        .top: "Сверху", .bottom: "Снизу", .hidden: "Скрыт",
    ]
}

nonisolated extension AyahMode: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Режим"
    static let caseDisplayRepresentations: [AyahMode: DisplayRepresentation] = [
        .byTime: "Аят по времени", .sequential: "По порядку", .random: "Случайно", .sura: "Выбранная сура", .favorites: "Моё избранное",
    ]
}

nonisolated extension AyahOverflow: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Если не помещается"
    static let caseDisplayRepresentations: [AyahOverflow: DisplayRepresentation] = [
        .showBeginning: "Показать начало", .shortAyahSameSura: "Короткий аят из той же суры",
    ]
}

nonisolated extension AyahLockTitle: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Заголовок суры"
    static let caseDisplayRepresentations: [AyahLockTitle: DisplayRepresentation] = [
        .auto: "Авто (скрыт при виджете «Сура»)", .show: "Показывать", .hide: "Скрыть",
    ]
}

/// Настройки виджета. «Как в приложении» — берутся настройки раздела «Аяты».
struct AyahWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Аят"
    static let description = IntentDescription("Аят Корана с переводом, сменяется каждую минуту.")

    @Parameter(title: "Как в приложении", default: true)
    var useAppSettings: Bool

    @Parameter(title: "Перевод", default: .kuliev)
    var translation: QuranTranslation

    @Parameter(title: "Шрифт", default: .newYork)
    var font: AyahFont

    @Parameter(title: "Размер", default: .medium)
    var size: AyahStyle.Size

    @Parameter(title: "Полужирный", default: false)
    var bold: Bool

    @Parameter(title: "Выравнивание", default: .leading)
    var alignment: AyahStyle.Alignment

    @Parameter(title: "Заголовок", default: .top)
    var titlePosition: AyahStyle.TitlePosition

    @Parameter(title: "Режим", default: .byTime)
    var mode: AyahMode

    @Parameter(title: "Номер суры", default: 1, inclusiveRange: (1, 114))
    var sura: Int

    @Parameter(title: "Арабский текст (главный экран)", default: false)
    var showArabic: Bool

    @Parameter(title: "Если аят не помещается", default: .showBeginning)
    var overflow: AyahOverflow

    @Parameter(title: "Заголовок суры", default: .auto)
    var lockTitle: AyahLockTitle

    nonisolated var settings: AyahSettings {
        var settings = AyahSettings.current
        guard !useAppSettings else { return settings }
        settings.translation = translation
        settings.style.font = font
        settings.style.size = size
        settings.style.bold = bold
        settings.style.alignment = alignment
        settings.style.titlePosition = titlePosition
        settings.mode = mode
        settings.sura = sura
        settings.showArabicOnHome = showArabic
        settings.overflow = overflow
        settings.lockTitle = lockTitle
        return settings
    }
}

// MARK: - Лента аятов

nonisolated struct AyahEntry: TimelineEntry, Sendable {
    var date: Date
    var pick: AyahPick?
    var style: AyahStyle
    var arabicFont: ArabicFont

    static let placeholder = AyahEntry(
        date: .now,
        pick: AyahPick(index: 6094, endIndex: 6094, ref: AyahRef(sura: 94, ayah: 5), text: "Воистину, за каждой тягостью наступает облегчение.", arabic: nil, title: "АШ-ШАРХ\u{00A0}94:5", inlineTitle: "Аш-Шарх\u{00A0}94:5"),
        style: .classic,
        arabicFont: .amiriQuran
    )
}

extension AyahEntry {
    /// Превью режима «по времени».
    static func preview(hour: Int, minute: Int) -> AyahEntry {
        let settings = AyahSettings()
        let calendar = AyahPicker.deviceCalendar
        var parts = calendar.dateComponents([.year, .month, .day], from: .now)
        parts.hour = hour
        parts.minute = minute
        guard let date = calendar.date(from: parts) else { return .placeholder }
        let pick = AyahPicker.byTime(date, settings: settings, surface: .lock(AyahLayout.lockBox), calendar: calendar)
        return AyahEntry(date: date, pick: pick, style: settings.style, arabicFont: settings.arabicFont)
    }

    /// Самый короткий или самый длинный аят перевода.
    static func extreme(longest: Bool) -> AyahEntry {
        let settings = AyahSettings()
        let lengths = (0..<QuranText.ayahCount).map { ($0, QuranStore.translation(settings.translation, at: $0).count) }
        guard let index = (longest ? lengths.max { $0.1 < $1.1 } : lengths.min { $0.1 < $1.1 })?.0 else { return .placeholder }
        let surface = AyahSurface.lock(AyahLayout.lockBox)
        let pick = AyahPicker.fitted(index...index, settings: settings, surface: surface) ?? AyahPicker.truncated(index, settings: settings, surface: surface)
        return AyahEntry(date: .now, pick: pick, style: settings.style, arabicFont: settings.arabicFont)
    }

    /// Превью с настоящим текстом и подбором размера.
    static func preview(sura: Int, ayah: Int, through last: Int? = nil) -> AyahEntry {
        let settings = AyahSettings()
        guard let first = QuranStore.index(of: AyahRef(sura: sura, ayah: ayah)) else { return .placeholder }
        let end = last.flatMap { QuranStore.index(of: AyahRef(sura: sura, ayah: $0)) } ?? first
        let surface = AyahSurface.lock(AyahLayout.lockBox)
        let pick = AyahPicker.fitted(first...end, settings: settings, surface: surface) ?? AyahPicker.truncated(first, settings: settings, surface: surface)
        return AyahEntry(date: .now, pick: pick, style: settings.style, arabicFont: settings.arabicFont)
    }
}

/// Записи на каждую минуту ~2 часа вперёд, затем — новая пачка.
nonisolated struct AyahProvider: AppIntentTimelineProvider {
    static let minutes = 120

    func placeholder(in context: Context) -> AyahEntry { .placeholder }

    func snapshot(for configuration: AyahWidgetIntent, in context: Context) async -> AyahEntry {
        if context.isPreview { return .placeholder }
        let (settings, surface) = await resolve(configuration, context)
        let pick = AyahPicker.current(settings: settings, favorites: AyahSettings.favorites, surface: surface)
        return AyahEntry(date: .now, pick: pick, style: settings.style, arabicFont: settings.arabicFont)
    }

    func timeline(for configuration: AyahWidgetIntent, in context: Context) async -> Timeline<AyahEntry> {
        let (settings, surface) = await resolve(configuration, context)
        guard QuranStore.isAvailable else {
            return Timeline(entries: [AyahEntry(date: .now, pick: nil, style: settings.style, arabicFont: settings.arabicFont)], policy: .after(.now.addingTimeInterval(15 * 60)))
        }
        let picks = AyahPicker.timeline(settings: settings, favorites: AyahSettings.favorites, surface: surface, start: .now, count: Self.minutes)
        let entries = picks.map { AyahEntry(date: $0.0, pick: $0.1, style: settings.style, arabicFont: settings.arabicFont) }
        return Timeline(entries: entries.isEmpty ? [.placeholder] : entries, policy: .atEnd)
    }

    /// «Аят» и «Сура» считают одинаково: тот же размер прямоугольника и те же настройки,
    /// поэтому заголовок над часами всегда совпадает с аятом под ними.
    private func resolve(_ configuration: AyahWidgetIntent, _ context: Context) async -> (AyahSettings, AyahSurface) {
        let inline = await Self.inlineInstalled()
        let settings = configuration.settings
        switch context.family {
        case .accessoryRectangular:
            if context.displaySize != .zero { AyahLayout.storedLockBox = context.displaySize }
            return (settings.resolvedForLock(inlineInstalled: inline), .lock(AyahLayout.storedLockBox))
        case .accessoryInline:
            return (settings.resolvedForLock(inlineInstalled: inline), .lock(AyahLayout.storedLockBox))
        case .systemSmall:
            return (settings, .home(context.displaySize, arabic: false))
        default:
            return (settings, .home(context.displaySize, arabic: settings.showArabicOnHome))
        }
    }

    /// Стоит ли над часами виджет «Сура».
    static func inlineInstalled() async -> Bool {
        if let configurations = try? await WidgetCenter.shared.currentConfigurations() {
            let installed = configurations.contains { $0.kind == AyahTitleWidget.kind }
            AyahSettings.inlineWidgetInstalled = installed
            return installed
        }
        return AyahSettings.inlineWidgetInstalled
    }
}

// MARK: - Отображение

struct AyahWidgetView: View {
    var entry: AyahEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(entry.pick.flatMap { URL(string: "hisob://ayah?i=\($0.index)") })
    }

    @ViewBuilder
    private var content: some View {
        if let pick = entry.pick {
            switch family {
            case .accessoryInline:
                Text(pick.inlineTitle)
            case .accessoryRectangular:
                AyahLockView(text: pick.text, title: pick.title, style: entry.style, fontScale: pick.fontScale)
                    .widgetAccentable()
            default:
                AyahHomeCard(text: pick.text, title: pick.title, arabic: pick.arabic, style: entry.style, arabicFont: entry.arabicFont, fontScale: pick.fontScale)
                    .padding(8)
            }
        } else {
            Text("Откройте \(AppInfo.name) один раз, чтобы загрузить аяты")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
    }
}

/// Экран блокировки: только перевод и заголовок суры.
struct AyahLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AyahLockWidget", intent: AyahWidgetIntent.self, provider: AyahProvider()) { entry in
            AyahWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Аят")
        .description("Аят с переводом на экране блокировки. Сменяется каждую минуту.")
        .supportedFamilies([.accessoryRectangular])
    }
}

/// Над часами: «Ар-Раад 13:39» — синхронно с «Аятом» (тот же расчёт, те же минуты).
struct AyahTitleWidget: Widget {
    nonisolated static let kind = "AyahTitleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: AyahWidgetIntent.self, provider: AyahProvider()) { entry in
            AyahWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Сура")
        .description("Название суры и номер аята над часами — вместе с виджетом «Аят».")
        .supportedFamilies([.accessoryInline])
    }
}

/// Главный экран: стеклянная карточка на бордово-белом градиенте.
struct AyahHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AyahHomeWidget", intent: AyahWidgetIntent.self, provider: AyahProvider()) { entry in
            AyahWidgetView(entry: entry)
                .containerBackground(for: .widget) { AyahHomeBackground() }
        }
        .configurationDisplayName("Аят")
        .description("Аят с переводом, по желанию — с арабским текстом.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview("Экран блокировки — Классика", as: .accessoryRectangular) {
    AyahLockWidget()
} timeline: {
    AyahEntry.placeholder
}

#Preview("Экран блокировки — Книга", as: .accessoryRectangular) {
    AyahLockWidget()
} timeline: {
    AyahEntry(date: .now, pick: AyahEntry.placeholder.pick, style: .book, arabicFont: .amiriQuran)
}

#Preview("Экран блокировки — Современный", as: .accessoryRectangular) {
    AyahLockWidget()
} timeline: {
    AyahEntry(date: .now, pick: AyahEntry.placeholder.pick, style: .modern, arabicFont: .amiriQuran)
}

#Preview("13:39", as: .accessoryRectangular) {
    AyahLockWidget()
} timeline: {
    AyahEntry.preview(hour: 13, minute: 39)
}

#Preview("02:15", as: .accessoryRectangular) {
    AyahLockWidget()
} timeline: {
    AyahEntry.preview(hour: 2, minute: 15)
}

#Preview("00:05", as: .accessoryRectangular) {
    AyahLockWidget()
} timeline: {
    AyahEntry.preview(hour: 0, minute: 5)
}

#Preview("Самый короткий", as: .accessoryRectangular) {
    AyahLockWidget()
} timeline: {
    AyahEntry.extreme(longest: false)
}

#Preview("Самый длинный", as: .accessoryRectangular) {
    AyahLockWidget()
} timeline: {
    AyahEntry.extreme(longest: true)
}

#Preview("Над часами", as: .accessoryInline) {
    AyahLockWidget()
} timeline: {
    AyahEntry.placeholder
}

#Preview("Главный экран", as: .systemMedium) {
    AyahHomeWidget()
} timeline: {
    AyahEntry.placeholder
}
