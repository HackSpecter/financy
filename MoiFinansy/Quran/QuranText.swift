import Foundation
import Synchronization

/// Сура: номер, число аятов, смещение первого аята и названия.
nonisolated struct SuraInfo: Codable, Sendable, Hashable, Identifiable {
    var n: Int
    var ayas: Int
    var start: Int
    var ar: String
    var ru: String
    var meaning: String
    var type: String
    var id: Int { n }
}

/// Аят: сура и номер; `index` — сквозной номер 0…6235.
nonisolated struct AyahRef: Codable, Sendable, Hashable {
    var sura: Int
    var ayah: Int
}

/// Перевод Корана на русский (тексты Tanzil, без изменений).
nonisolated enum QuranTranslation: String, CaseIterable, Codable, Sendable, Identifiable {
    case kuliev = "ru.kuliev"
    case osmanov = "ru.osmanov"
    case krachkovsky = "ru.krachkovsky"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kuliev: "Кулиев"
        case .osmanov: "Османов"
        case .krachkovsky: "Крачковский"
        }
    }

    var translator: String {
        switch self {
        case .kuliev: "Эльмир Кулиев"
        case .osmanov: "Магомед-Нури Османов"
        case .krachkovsky: "Игнатий Крачковский"
        }
    }
}

/// Тексты Корана: файл «одна строка — один аят», читается без загрузки целиком в память.
nonisolated final class QuranText: Sendable {
    static let ayahCount = 6236
    static let arabicFile = "quran-uthmani"

    private let data: Data
    private let offsets: [Int32]

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        var offsets: [Int32] = []
        offsets.reserveCapacity(Self.ayahCount + 1)
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            var lineStart = 0
            for i in 0..<bytes.count where bytes[i] == 0x0A {
                // Строки копирайта начинаются с «#» — пропускаем.
                if bytes[lineStart] != 0x23 { offsets.append(Int32(lineStart)) }
                lineStart = i + 1
            }
            offsets.append(Int32(bytes.count))
        }
        guard offsets.count == Self.ayahCount + 1 else { return nil }
        self.data = data
        self.offsets = offsets
    }

    /// Текст аята по сквозному номеру (0…6235).
    func text(at index: Int) -> String {
        guard index >= 0, index < Self.ayahCount else { return "" }
        let start = Int(offsets[index])
        var end = Int(offsets[index + 1])
        // Последний символ строки — перевод строки.
        if end > start, data[data.startIndex + end - 1] == 0x0A { end -= 1 }
        return String(decoding: data[(data.startIndex + start)..<(data.startIndex + end)], as: UTF8.self)
    }
}

/// Доступ к данным Корана: App Group (общий с виджетом) или ресурсы приложения.
nonisolated enum QuranStore {
    static let folderName = "Quran"
    static let dataVersion = 2
    private static let cache = Mutex<[String: QuranText]>([:])
    private static let surasCache = Mutex<[SuraInfo]?>(nil)
    private static let flagsCache = Mutex<[String: [UInt8]]>([:])

    static var groupFolder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.appGroup)?
            .appending(path: folderName, directoryHint: .isDirectory)
    }

    /// Файл: сначала общий контейнер, затем ресурсы приложения.
    static func url(for name: String, ext: String) -> URL? {
        if let folder = groupFolder {
            let url = folder.appending(path: "\(name).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return Bundle.main.url(forResource: name, withExtension: ext)
    }

    /// Приложение копирует тексты в общий контейнер, чтобы виджет читал их без сети.
    static func installIntoAppGroupIfNeeded() {
        guard let folder = groupFolder else { return }
        let key = "quran.dataVersion"
        let files = [("suras", "json"), (QuranText.arabicFile, "txt")]
            + QuranTranslation.allCases.map { ($0.rawValue, "txt") }
            + QuranTranslation.allCases.map { ($0.rawValue, "flags") }
        let complete = files.allSatisfy { FileManager.default.fileExists(atPath: folder.appending(path: "\($0.0).\($0.1)").path) }
        guard !complete || SharedDefaults.store.integer(forKey: key) != dataVersion else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, ext) in files {
            guard let source = Bundle.main.url(forResource: name, withExtension: ext) else { continue }
            let target = folder.appending(path: "\(name).\(ext)")
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.copyItem(at: source, to: target)
        }
        SharedDefaults.store.set(dataVersion, forKey: key)
    }

    static var isAvailable: Bool { url(for: "suras", ext: "json") != nil }

    static var suras: [SuraInfo] {
        surasCache.withLock { cached in
            if let cached { return cached }
            guard let url = url(for: "suras", ext: "json"),
                  let data = try? Data(contentsOf: url),
                  let list = try? JSONDecoder().decode([SuraInfo].self, from: data) else { return [] }
            cached = list
            return list
        }
    }

    static func text(_ name: String) -> QuranText? {
        cache.withLock { cache in
            if let text = cache[name] { return text }
            guard let url = url(for: name, ext: "txt"), let text = QuranText(url: url) else { return nil }
            cache[name] = text
            return text
        }
    }

    static func translation(_ translation: QuranTranslation, at index: Int) -> String {
        text(translation.rawValue)?.text(at: index) ?? ""
    }

    static func arabic(at index: Int) -> String {
        text(QuranText.arabicFile)?.text(at: index) ?? ""
    }

    static func ref(at index: Int) -> AyahRef {
        let list = suras
        guard let sura = list.last(where: { $0.start <= index }) else { return AyahRef(sura: 1, ayah: 1) }
        return AyahRef(sura: sura.n, ayah: index - sura.start + 1)
    }

    static func index(of ref: AyahRef) -> Int? {
        guard let sura = suras.first(where: { $0.n == ref.sura }), (1...sura.ayas).contains(ref.ayah) else { return nil }
        return sura.start + ref.ayah - 1
    }

    static func sura(_ number: Int) -> SuraInfo? {
        suras.first { $0.n == number }
    }

    /// Признаки аятов перевода: бит 1 — начинает предложение, бит 2 — заканчивает (см. tools/build_quran_data.py).
    static func flags(_ translation: QuranTranslation) -> [UInt8] {
        flagsCache.withLock { cache in
            if let flags = cache[translation.rawValue] { return flags }
            guard let url = url(for: translation.rawValue, ext: "flags"),
                  let data = try? Data(contentsOf: url), data.count == QuranText.ayahCount else { return [] }
            let flags = data.map { $0 &- 0x30 }
            cache[translation.rawValue] = flags
            return flags
        }
    }

    static func startsSentence(_ index: Int, _ translation: QuranTranslation) -> Bool {
        let flags = flags(translation)
        return index < flags.count ? flags[index] & 1 != 0 : true
    }

    static func endsSentence(_ index: Int, _ translation: QuranTranslation) -> Bool {
        let flags = flags(translation)
        return index < flags.count ? flags[index] & 2 != 0 : true
    }

    /// Самостоятельный аят: законченная мысль, не продолжение предыдущего.
    static func isStandalone(_ index: Int, _ translation: QuranTranslation) -> Bool {
        startsSentence(index, translation) && endsSentence(index, translation)
    }

    /// Предложение, в которое входит аят: аяты той же суры от начала до конца фразы (не больше `limit`).
    static func sentence(containing index: Int, _ translation: QuranTranslation, limit: Int = 6) -> ClosedRange<Int> {
        guard let sura = sura(ref(at: index).sura) else { return index...index }
        let first = sura.start, last = sura.start + sura.ayas - 1
        var start = index
        while start > first, !startsSentence(start, translation), index - start < limit - 1 { start -= 1 }
        var end = index
        while end < last, !endsSentence(end, translation), end - start < limit - 1 { end += 1 }
        return start...end
    }
}
