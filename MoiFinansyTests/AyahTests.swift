import Foundation
import Testing
@testable import MoiFinansy

struct QuranDataTests {
    @Test func allTranslationsHaveEveryAyah() throws {
        for translation in QuranTranslation.allCases {
            let text = try #require(QuranStore.text(translation.rawValue))
            #expect(!text.text(at: 0).isEmpty)
            #expect(!text.text(at: QuranText.ayahCount - 1).isEmpty)
        }
        #expect(QuranStore.arabic(at: 0).contains("بِسْمِ"))
    }

    @Test func refsAndIndexes() throws {
        #expect(QuranStore.suras.count == 114)
        let index = try #require(QuranStore.index(of: AyahRef(sura: 94, ayah: 5)))
        #expect(QuranStore.ref(at: index) == AyahRef(sura: 94, ayah: 5))
        #expect(QuranStore.translation(.kuliev, at: index) == "Воистину, за каждой тягостью наступает облегчение.")
        #expect(QuranStore.sura(94)?.ru == "Аш-Шарх")
        #expect(QuranStore.index(of: AyahRef(sura: 94, ayah: 99)) == nil)
    }

    @Test func titleFormat() {
        let ref = AyahRef(sura: 94, ayah: 5)
        #expect(AyahTypography.title(sura: QuranStore.sura(94), ref: ref) == "АШ-ШАРХ\u{00A0}94:5")
        #expect(AyahTypography.title(sura: QuranStore.sura(94), ref: ref, uppercased: false) == "Аш-Шарх\u{00A0}94:5")
    }
}

struct AyahTypographyTests {
    let nbsp = "\u{00A0}"

    @Test func quotesAndDashes() {
        #expect(AyahTypography.quotes("Скажи: \"Он - Аллах\"") == "Скажи: «Он - Аллах»")
        #expect(AyahTypography.dashes("Он - Аллах") == "Он\(nbsp)— Аллах")
        #expect(AyahTypography.quotes("\"Он сказал: \"Да\".\"") == "«Он сказал: „Да“.»")
    }

    @Test func shortWordsAreBound() {
        let result = AyahTypography.bindShortWords("и ты будешь удовлетворен")
        #expect(result.hasPrefix("и\(nbsp)ты\(nbsp)будешь"))
    }

    @Test func lastWordIsNotAlone() {
        #expect(AyahTypography.bindLastWord("и ты будешь доволен.").hasSuffix("будешь\(nbsp)доволен."))
        // Длинное последнее слово не склеиваем — два длинных слова могли бы не поместиться в строку.
        #expect(!AyahTypography.bindLastWord("тягостью облегчение.").contains(nbsp))
    }

    @Test func wordsAreUnchanged() {
        let original = "Скажи: \"Он - Аллах Единый,"
        let pretty = AyahTypography.russian(original)
        let letters: (String) -> String = { $0.filter { $0.isLetter } }
        #expect(letters(original) == letters(pretty))
    }

    @Test func completeThought() {
        #expect(AyahTypography.isComplete("наступает облегчение."))
        #expect(!AyahTypography.isComplete("Он - Аллах Единый,"))
    }
}

@MainActor
@Suite(.serialized)
struct AyahPickerTests {
    let settings: AyahSettings = {
        var settings = AyahSettings()
        settings.mode = .random
        return settings
    }()

    @Test func everyPickFitsTheLockScreen() {
        for size in AyahStyle.Size.allCases {
            var settings = self.settings
            settings.style.size = size
            let picks = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: .now, count: 30)
            #expect(picks.count == 30)
            #expect(picks.allSatisfy { AyahFitter.fitsLock($0.1.text, style: settings.style, box: AyahLayout.lockBox, scale: $0.1.fontScale) })
            #expect(picks.allSatisfy { !$0.1.isTruncated })
        }
    }

    @Test func biggerTextGivesShorterAyahs() {
        func averageLength(_ size: AyahStyle.Size) -> Double {
            var settings = self.settings
            settings.style.size = size
            let picks = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: Date(timeIntervalSince1970: 1_800_000_000), count: 40)
            return Double(picks.map(\.1.text.count).reduce(0, +)) / Double(max(picks.count, 1))
        }
        #expect(averageLength(.extraLarge) < averageLength(.small))
    }

    @Test func randomIsDeterministicPerMinute() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let first = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: start, count: 10).map(\.1.index)
        let second = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: start, count: 10).map(\.1.index)
        #expect(first == second)
        #expect(Set(first).count == first.count)
    }

    @Test func entriesAreOneMinuteApart() {
        let picks = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: .now, count: 5)
        let gaps = zip(picks.dropFirst(), picks).map { $0.0.timeIntervalSince($1.0) }
        #expect(gaps.allSatisfy { $0 == 60 })
    }

    @Test func suraModeStaysInSura() throws {
        var settings = self.settings
        settings.mode = .sura
        settings.sura = 94
        let sura = try #require(QuranStore.sura(94))
        let picks = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: .now, count: 12)
        #expect(!picks.isEmpty)
        #expect(picks.allSatisfy { (sura.start..<(sura.start + sura.ayas)).contains($0.1.index) })
    }

    @Test func sequentialRegenerationInSameMinuteRepeats() {
        var settings = self.settings
        settings.mode = .sequential
        let start = Date.now
        let first = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: start, count: 5).map(\.1.index)
        let again = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: start, count: 5).map(\.1.index)
        #expect(first == again)
        #expect(first == first.sorted())
    }
}


struct AyahByTimeTests {
    /// Время в часовом поясе устройства.
    private func date(_ hour: Int, _ minute: Int, second: Int = 0) -> Date {
        var components = DateComponents(year: 2026, month: 10, day: 29, hour: hour, minute: minute, second: second)
        components.calendar = AyahPicker.deviceCalendar
        return AyahPicker.deviceCalendar.date(from: components)!
    }

    @Test(arguments: [
        (0, 5, 24, 5),     // 00:ММ → сура 24
        (1, 0, 1, 1),      // ЧЧ:00 → аят 1
        (13, 20, 13, 20),
        (13, 50, 13, 7),   // в суре 13 всего 43 аята: ((50−1) mod 43) + 1 = 7
        (23, 59, 23, 59),
    ])
    func refForTime(hour: Int, minute: Int, sura: Int, ayah: Int) {
        #expect(AyahPicker.timeRef(for: date(hour, minute)) == AyahRef(sura: sura, ayah: ayah))
    }

    @Test func titleShowsRealNumber() throws {
        let pick = try #require(AyahPicker.byTime(date(13, 50), settings: AyahSettings(), surface: .lock(AyahLayout.lockBox), calendar: AyahPicker.deviceCalendar))
        #expect(pick.title.hasSuffix("13:7") || pick.title.contains("–7"))
    }

    @Test func entriesStartExactlyAtMinute() {
        let settings = AyahSettings()
        let entries = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: date(13, 20, second: 37), count: 120)
        #expect(entries.count == 120)
        #expect(entries.first.map { AyahPicker.deviceCalendar.component(.hour, from: $0.0) } == 13)
        #expect(entries.allSatisfy { AyahPicker.deviceCalendar.component(.second, from: $0.0) == 0 })
        #expect(entries.allSatisfy { $0.0.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) == 0 })
        // Каждая запись — аят своей минуты.
        for (date, pick) in entries.prefix(30) {
            let ref = AyahPicker.timeRef(for: date)
            #expect(QuranStore.index(of: ref).map { (pick.index...pick.endIndex).contains($0) } == true)
        }
    }

    @Test func everyMinuteOfTheDayFits() {
        let settings = AyahSettings()
        for hour in 0..<24 {
            for minute in stride(from: 0, to: 60, by: 7) {
                let pick = AyahPicker.byTime(date(hour, minute), settings: settings, surface: .lock(AyahLayout.lockBox), calendar: AyahPicker.deviceCalendar)
                #expect(pick != nil, "\(hour):\(minute)")
                if let pick {
                    #expect(AyahFitter.fitsLock(pick.text, style: settings.style, box: AyahLayout.lockBox, scale: pick.fontScale))
                    #expect(settings.style.size.lockPointSize * pick.fontScale >= AyahPicker.minimumPointSize - 0.01)
                }
            }
        }
    }
}

struct AyahStandaloneTests {
    @Test func flagsMatchHeuristic() throws {
        let translation = QuranTranslation.kuliev
        let fatiha2 = try #require(QuranStore.index(of: AyahRef(sura: 1, ayah: 2)))
        let fatiha3 = try #require(QuranStore.index(of: AyahRef(sura: 1, ayah: 3)))
        let shrah5 = try #require(QuranStore.index(of: AyahRef(sura: 94, ayah: 5)))
        #expect(!QuranStore.endsSentence(fatiha2, translation))      // «Хвала Аллаху, Господу миров,»
        #expect(!QuranStore.startsSentence(fatiha3, translation))    // «Милостивому, Милосердному,»
        #expect(QuranStore.isStandalone(shrah5, translation))
    }

    @Test func sentenceGroupsAyahs() throws {
        let fatiha3 = try #require(QuranStore.index(of: AyahRef(sura: 1, ayah: 3)))
        let range = QuranStore.sentence(containing: fatiha3, .kuliev)
        #expect(range.lowerBound == QuranStore.index(of: AyahRef(sura: 1, ayah: 2)))
        #expect(QuranStore.endsSentence(range.upperBound, .kuliev))
    }

    @Test func randomShowsOnlyUnderstandable() {
        var settings = AyahSettings()
        settings.mode = .random
        let picks = AyahPicker.timeline(settings: settings, favorites: [], surface: .lock(AyahLayout.lockBox), start: Date(timeIntervalSince1970: 1_800_000_000), count: 60)
        #expect(picks.count == 60)
        for (_, pick) in picks {
            #expect(QuranStore.startsSentence(pick.index, .kuliev))
            #expect(QuranStore.endsSentence(pick.endIndex, .kuliev))
        }
    }

    @Test func rangeTitle() {
        let sura = QuranStore.sura(55)
        #expect(AyahTypography.title(sura: sura, from: AyahRef(sura: 55, ayah: 1), to: AyahRef(sura: 55, ayah: 4)) == "АР-РАХМАН\u{00A0}55:1–4")
    }
}


struct AyahFitV2Tests {
    let settings = AyahSettings()
    let box = AyahSurface.lock(AyahLayout.lockBox)

    private func date(_ hour: Int, _ minute: Int) -> Date {
        var parts = DateComponents(year: 2026, month: 10, day: 29, hour: hour, minute: minute)
        parts.calendar = AyahPicker.deviceCalendar
        return AyahPicker.deviceCalendar.date(from: parts)!
    }

    @Test func ellipsisOnlyWhenTruncated() {
        for hour in 0..<24 {
            for minute in stride(from: 0, to: 60, by: 5) {
                guard let pick = AyahPicker.byTime(date(hour, minute), settings: settings, surface: box, calendar: AyahPicker.deviceCalendar) else { continue }
                #expect(pick.text.contains("…") == pick.isTruncated || QuranStore.translation(settings.translation, at: pick.index).contains("…"), "\(hour):\(minute)")
            }
        }
    }

    @Test func shortestAyahsHaveNoEllipsisAndFullSize() throws {
        let lengths = (0..<QuranText.ayahCount).map { ($0, QuranStore.translation(.kuliev, at: $0).count) }.sorted { $0.1 < $1.1 }
        for (index, _) in lengths.prefix(20) {
            let pick = try #require(AyahPicker.fitted(index...index, settings: settings, surface: box))
            #expect(!pick.text.contains("…"))
            #expect(pick.fontScale == 1)
        }
    }

    @Test func longestAyahIsTruncatedAtPhrase() throws {
        let longest = try #require((0..<QuranText.ayahCount).max { QuranStore.translation(.kuliev, at: $0).count < QuranStore.translation(.kuliev, at: $1).count })
        #expect(AyahPicker.fitted(longest...longest, settings: settings, surface: box) == nil)
        let pick = try #require(AyahPicker.truncated(longest, settings: settings, surface: box))
        #expect(pick.isTruncated)
        #expect(pick.text.hasSuffix("\u{00A0}…"))
        // Обрезка по границе фразы, не посреди слова.
        let kept = String(pick.text.dropLast(2))
        #expect(QuranStore.translation(.kuliev, at: longest).hasPrefix(kept))
    }

    @Test func sizesFromMaxToMinimum() {
        let sizes = AyahLayout.lockPointSizes(settings.style)
        #expect(sizes.first == settings.style.size.lockPointSize)
        #expect(sizes.last == AyahLayout.lockMinimumPointSize)
        #expect(zip(sizes, sizes.dropFirst()).allSatisfy { $0 - $1 == 0.5 })
    }

    @Test func fourLinesMax() {
        let text = String(repeating: "слово ", count: 80)
        #expect(!AyahFitter.fitsLock(text, style: settings.style, box: CGSize(width: 172, height: 400), pointSize: 11))
    }

    @Test func shortAyahFromSameSura() throws {
        var short = settings
        short.overflow = .shortAyahSameSura
        let time = date(2, 15)
        let full = AyahPicker.byTimeFull(try #require(QuranStore.index(of: AyahPicker.timeRef(for: time))), settings: settings, surface: box)
        let pick = try #require(AyahPicker.byTime(time, settings: short, surface: box, calendar: AyahPicker.deviceCalendar))
        #expect(pick.ref.sura == 2)
        #expect(!pick.isTruncated)
        if full == nil {
            // Аят 2:15 не поместился — показан другой, и в заголовке его настоящий номер.
            #expect(pick.ref.ayah != 15)
            #expect(pick.title.hasSuffix("2:\(pick.ref.ayah)"))
        }
    }

    @Test func inlineAndRectangularShowSameAyah() {
        let lock = settings.resolvedForLock(inlineInstalled: true)
        let a = AyahPicker.timeline(settings: lock, favorites: [], surface: .lock(AyahLayout.storedLockBox), start: date(13, 39), count: 30)
        let b = AyahPicker.timeline(settings: lock, favorites: [], surface: .lock(AyahLayout.storedLockBox), start: date(13, 39), count: 30)
        #expect(a.map(\.0) == b.map(\.0))
        #expect(a.map(\.1.inlineTitle) == b.map(\.1.inlineTitle))
        #expect(a.first?.1.inlineTitle == "Ар-Раад\u{00A0}13:39")
    }

    @Test func autoTitleHidesWithInlineWidget() {
        #expect(settings.resolvedForLock(inlineInstalled: true).style.titlePosition == .hidden)
        #expect(settings.resolvedForLock(inlineInstalled: false).style.titlePosition == .top)
        var shown = settings
        shown.lockTitle = .show
        #expect(shown.resolvedForLock(inlineInstalled: true).style.titlePosition == .top)
    }

    @Test func oldSettingsDecodeWithoutLoss() throws {
        let json = #"{"translation":"ru.osmanov","mode":"sura","sura":36}"#
        let decoded = try JSONDecoder().decode(AyahSettings.self, from: Data(json.utf8))
        #expect(decoded.translation == .osmanov)
        #expect(decoded.sura == 36)
        #expect(decoded.overflow == .showBeginning)
        #expect(decoded.lockTitle == .auto)
    }
}
