import Foundation

/// Что показать: один аят или законченное предложение из нескольких (`index...endIndex`).
nonisolated struct AyahPick: Sendable, Hashable {
    var index: Int
    var endIndex: Int
    var ref: AyahRef
    var text: String
    var arabic: String?
    var title: String
    var inlineTitle: String
    /// Уменьшение шрифта, чтобы текст поместился.
    var fontScale: CGFloat = 1
    /// Показано начало аята с «…» — полный текст по тапу.
    var isTruncated = false
}

/// Где показывается аят — от этого зависит подбор по размеру.
nonisolated enum AyahSurface: Sendable, Hashable {
    case lock(CGSize)
    case home(CGSize, arabic: Bool)
    case app
}

/// Подбор аятов на каждую минуту: режим, самостоятельность и проверка, что текст помещается целиком.
nonisolated enum AyahPicker {
    static let maxAttempts = 600
    /// Ступени уменьшения шрифта; минимальный читаемый кегль — `minimumPointSize`.
    static let scales: [CGFloat] = [1, 0.93, 0.86, 0.8]
    static let minimumPointSize: CGFloat = 11

    /// Часы устройства: аят меняется ровно вместе с минутой на экране.
    static var deviceCalendar: Calendar { Calendar.autoupdatingCurrent }

    /// Начало минуты (секунды = 0).
    static func minuteStart(_ date: Date, calendar: Calendar = deviceCalendar) -> Date {
        calendar.dateInterval(of: .minute, for: date)?.start ?? date
    }

    /// Аяты на `count` минут: записи строго на начало каждой минуты.
    static func timeline(settings: AyahSettings, favorites: [Int], surface: AyahSurface, start: Date, count: Int, calendar: Calendar = deviceCalendar) -> [(Date, AyahPick)] {
        let firstMinute = minuteStart(start, calendar: calendar)
        var result: [(Date, AyahPick)] = []
        var used = Set<Int>()
        var cursor = peekCursor(settings: settings, favorites: favorites, at: firstMinute)
        var firstPosition: Int?

        for step in 0..<count {
            guard let date = calendar.date(byAdding: .minute, value: step, to: firstMinute) else { continue }
            let pick: AyahPick?
            switch settings.mode {
            case .byTime:
                pick = byTime(date, settings: settings, surface: surface, calendar: calendar)
            case .random:
                pick = random(minute: date, settings: settings, surface: surface, avoiding: used)
            case .sequential, .sura, .favorites:
                let pool = pool(for: settings, favorites: favorites)
                let found = nextFitting(from: cursor, in: pool, settings: settings, surface: surface)
                pick = found?.pick
                if step == 0 { firstPosition = found?.position }
                cursor = (found.map { $0.position + max(1, $0.pick.endIndex - $0.pick.index + 1) } ?? cursor + 1)
            }
            guard let pick else { continue }
            used.formUnion(pick.index...pick.endIndex)
            result.append((date, pick))
        }
        // Курсор — на первую минуту: повторная генерация в ту же минуту даёт те же аяты.
        if settings.mode != .random, settings.mode != .byTime, let firstPosition {
            saveCursor(firstPosition, settings: settings, favorites: favorites, at: firstMinute)
        }
        return result
    }

    /// Текущий аят (для приложения и превью).
    static func current(settings: AyahSettings = .current, favorites: [Int] = AyahSettings.favorites, surface: AyahSurface = .lock(AyahLayout.lockBox), date: Date = .now) -> AyahPick? {
        let minute = minuteStart(date)
        switch settings.mode {
        case .byTime:
            return byTime(minute, settings: settings, surface: surface, calendar: deviceCalendar)
        case .random:
            return random(minute: minute, settings: settings, surface: surface, avoiding: [])
        default:
            let pool = pool(for: settings, favorites: favorites)
            return nextFitting(from: peekCursor(settings: settings, favorites: favorites, at: minute), in: pool, settings: settings, surface: surface)?.pick
        }
    }

    // MARK: Аят по времени

    /// ЧЧ:ММ → сура ЧЧ (00 → 24), аят ММ (00 → 1; больше числа аятов — по кругу).
    static func timeRef(for date: Date, calendar: Calendar = deviceCalendar) -> AyahRef {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let suraNumber = hour == 0 ? 24 : hour
        let count = QuranStore.sura(suraNumber)?.ayas ?? 1
        let ayah = minute == 0 ? 1 : ((minute - 1) % count) + 1
        return AyahRef(sura: suraNumber, ayah: ayah)
    }

    /// Аят этой минуты; несамостоятельный — вместе с началом предложения, если помещается;
    /// не помещается — уменьшаем шрифт, затем показываем начало до конца фразы с «…».
    static func byTime(_ date: Date, settings: AyahSettings, surface: AyahSurface, calendar: Calendar) -> AyahPick? {
        guard let index = QuranStore.index(of: timeRef(for: date, calendar: calendar)) else { return nil }
        if let pick = byTimeFull(index, settings: settings, surface: surface) { return pick }
        switch settings.overflow {
        case .showBeginning:
            return truncated(index, settings: settings, surface: surface)
        case .shortAyahSameSura:
            // Ближайший следующий аят этой суры, который помещается целиком; в заголовке — его номер.
            guard let sura = QuranStore.sura(QuranStore.ref(at: index).sura) else { return nil }
            for offset in 1..<sura.ayas {
                let next = sura.start + (index - sura.start + offset) % sura.ayas
                if let pick = fitted(next...next, settings: settings, surface: surface) { return pick }
            }
            return truncated(index, settings: settings, surface: surface)
        }
    }

    /// Аят целиком (с началом предложения, если это продолжение и всё помещается).
    static func byTimeFull(_ index: Int, settings: AyahSettings, surface: AyahSurface) -> AyahPick? {
        var ranges: [ClosedRange<Int>] = []
        if !QuranStore.startsSentence(index, settings.translation) {
            let sentence = QuranStore.sentence(containing: index, settings.translation)
            ranges.append(sentence.lowerBound...index)
            if sentence.lowerBound < index - 1 { ranges.append((index - 1)...index) }
        }
        ranges.append(index...index)
        for range in ranges {
            if let pick = fitted(range, settings: settings, surface: surface) { return pick }
        }
        return nil
    }

    // MARK: Случайно — детерминированно от минуты, только понятные аяты

    static func random(minute: Date, settings: AyahSettings, surface: AyahSurface, avoiding used: Set<Int>) -> AyahPick? {
        var state = UInt64(bitPattern: Int64(minute.timeIntervalSince1970 / 60)) &+ UInt64(settings.translation.rawValue.count)
        for _ in 0..<maxAttempts {
            state = splitmix(state)
            let index = Int(state % UInt64(QuranText.ayahCount))
            guard !used.contains(index), let pick = understandable(index, settings: settings, surface: surface) else { continue }
            if used.contains(pick.index) { continue }
            return pick
        }
        return nil
    }

    /// Самостоятельный аят или законченное предложение из нескольких аятов, если помещается.
    static func understandable(_ index: Int, settings: AyahSettings, surface: AyahSurface) -> AyahPick? {
        if case .app = surface { return pick(index...index, settings: settings, surface: surface) }
        let range = QuranStore.isStandalone(index, settings.translation)
            ? index...index
            : QuranStore.sentence(containing: index, settings.translation)
        // Предложение должно быть законченным с обеих сторон.
        guard QuranStore.startsSentence(range.lowerBound, settings.translation),
              QuranStore.endsSentence(range.upperBound, settings.translation) else { return nil }
        return fitted(range, settings: settings, surface: surface, allowShrink: false)
    }

    static func splitmix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    // MARK: Размер

    /// Подбор масштаба шрифта, при котором текст помещается целиком.
    static func fitted(_ range: ClosedRange<Int>, settings: AyahSettings, surface: AyahSurface, allowShrink: Bool = true) -> AyahPick? {
        let base = pick(range, settings: settings, surface: surface)
        guard !base.text.isEmpty else { return nil }
        if case .app = surface { return base }
        let maximum = pointSize(settings, surface)
        let sizes: [CGFloat]
        if case .lock = surface {
            sizes = allowShrink ? AyahLayout.lockPointSizes(settings.style) : [maximum]
        } else {
            sizes = (allowShrink ? scales : [1]).map { maximum * $0 }
        }
        for size in sizes where fits(base, scale: size / maximum, settings: settings, surface: surface) {
            var result = base
            result.fontScale = size / maximum
            return result
        }
        return nil
    }

    /// Начало аята до конца фразы, которое помещается при минимальном читаемом шрифте.
    static func truncated(_ index: Int, settings: AyahSettings, surface: AyahSurface) -> AyahPick? {
        let base = pick(index...index, settings: settings, surface: surface)
        let maximum = pointSize(settings, surface)
        let scale: CGFloat
        if case .lock = surface { scale = AyahLayout.lockMinimumPointSize / maximum } else { scale = scales.last ?? 1 }
        for prefix in AyahTypography.truncatedPrefixes(base.text) {
            var candidate = base
            candidate.text = prefix
            candidate.arabic = nil
            if fits(candidate, scale: scale, settings: settings, surface: surface) {
                candidate.fontScale = scale
                candidate.isTruncated = true
                return candidate
            }
        }
        return nil
    }

    static func pointSize(_ settings: AyahSettings, _ surface: AyahSurface) -> CGFloat {
        if case .home = surface { return settings.style.size.homePointSize }
        return settings.style.size.lockPointSize
    }

    static func fits(_ pick: AyahPick, scale: CGFloat, settings: AyahSettings, surface: AyahSurface) -> Bool {
        switch surface {
        case .lock(let box):
            AyahFitter.fitsLock(pick.text, style: settings.style, box: box, scale: scale)
        case .home(let box, _):
            AyahFitter.fitsHome(pick.text, arabic: pick.arabic, style: settings.style, arabicFont: settings.arabicFont, box: box, scale: scale)
        case .app:
            true
        }
    }

    /// Текст и заголовок для одного аята или диапазона.
    static func pick(_ range: ClosedRange<Int>, settings: AyahSettings, surface: AyahSurface) -> AyahPick {
        let first = QuranStore.ref(at: range.lowerBound)
        let last = QuranStore.ref(at: range.upperBound)
        let sura = QuranStore.sura(first.sura)
        let withArabic: Bool
        switch surface {
        case .home(_, let arabic): withArabic = arabic
        case .app: withArabic = true
        case .lock: withArabic = false
        }
        // «…» ставится только при настоящей обрезке (см. `truncated`).
        let text = range.map { QuranStore.translation(settings.translation, at: $0) }.joined(separator: " ")
        return AyahPick(
            index: range.lowerBound,
            endIndex: range.upperBound,
            ref: first,
            text: text,
            arabic: withArabic ? range.map { QuranStore.arabic(at: $0) }.joined(separator: " ") : nil,
            title: AyahTypography.title(sura: sura, from: first, to: last),
            inlineTitle: AyahTypography.title(sura: sura, from: first, to: last, uppercased: false)
        )
    }

    // MARK: По порядку, сура, избранное — курсор в общем контейнере

    static func pool(for settings: AyahSettings, favorites: [Int]) -> [Int] {
        switch settings.mode {
        case .sura:
            guard let sura = QuranStore.sura(settings.sura) else { return Array(0..<QuranText.ayahCount) }
            return Array(sura.start..<(sura.start + sura.ayas))
        case .favorites:
            return favorites.isEmpty ? Array(0..<QuranText.ayahCount) : favorites
        default:
            return Array(0..<QuranText.ayahCount)
        }
    }

    /// Первая позиция (по кругу), где аят понятен и помещается.
    static func nextFitting(from cursor: Int, in pool: [Int], settings: AyahSettings, surface: AyahSurface) -> (position: Int, pick: AyahPick)? {
        guard !pool.isEmpty else { return nil }
        for offset in 0..<min(pool.count, maxAttempts) {
            let position = (cursor + offset) % pool.count
            // Избранное показываем как есть — его выбрал пользователь.
            let pick = settings.mode == .favorites
                ? fitted(pool[position]...pool[position], settings: settings, surface: surface) ?? truncated(pool[position], settings: settings, surface: surface)
                : understandable(pool[position], settings: settings, surface: surface)
            // Внутри предложения начинаем с его первого аята, чтобы не повторять.
            if let pick, pick.index == pool[position] || settings.mode == .favorites { return (position, pick) }
        }
        return nil
    }

    private static func cursorKey(_ settings: AyahSettings) -> String {
        switch settings.mode {
        case .sura: "ayah.cursor.sura.\(settings.sura)"
        case .favorites: "ayah.cursor.favorites"
        default: "ayah.cursor.sequential"
        }
    }

    /// Курсор на момент `date`: сохранённая позиция + прошедшие минуты.
    static func peekCursor(settings: AyahSettings, favorites: [Int], at date: Date) -> Int {
        let key = cursorKey(settings)
        let position = SharedDefaults.store.integer(forKey: key)
        guard let saved = SharedDefaults.store.object(forKey: key + ".date") as? Date else { return position }
        let minutes = max(Int(date.timeIntervalSince(saved) / 60), 0)
        let count = max(pool(for: settings, favorites: favorites).count, 1)
        return (position + minutes) % count
    }

    private static func saveCursor(_ cursor: Int, settings: AyahSettings, favorites: [Int], at date: Date) {
        let key = cursorKey(settings)
        let count = max(pool(for: settings, favorites: favorites).count, 1)
        SharedDefaults.store.set(cursor % count, forKey: key)
        SharedDefaults.store.set(date, forKey: key + ".date")
    }
}
