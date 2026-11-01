import Foundation

/// Типографика русского перевода при отображении. Сам текст (слова) не меняется:
/// только кавычки, тире и пробелы, чтобы строки ломались красиво.
nonisolated enum AyahTypography {
    static let nbsp = "\u{00A0}"

    /// Короткие слова, которые не должны оставаться в конце строки.
    static let shortWords: Set<String> = [
        "а", "в", "во", "и", "к", "ко", "о", "об", "обо", "с", "со", "у", "я", "не", "ни", "на", "но", "по",
        "за", "из", "от", "до", "для", "без", "при", "про", "над", "под", "его", "их", "её", "ее", "он", "она",
        "мы", "вы", "ты", "же", "ли", "бы", "что", "как", "где", "кто", "или", "то", "это", "все", "всё", "так",
    ]

    static func russian(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespaces)
        result = quotes(result)
        result = dashes(result)
        result = bindShortWords(result)
        result = bindLastWord(result)
        return result
    }

    /// "…" → «…»; вложенные — „…“.
    static func quotes(_ text: String) -> String {
        var output = ""
        var depth = 0
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            guard character == "\"" else {
                output.append(character)
                continue
            }
            let previous = index > 0 ? characters[index - 1] : " "
            let opens = previous.isWhitespace || "([{«„—-:".contains(previous) || index == 0
            if opens {
                output.append(depth == 0 ? "«" : "„")
                depth += 1
            } else {
                depth = max(depth - 1, 0)
                output.append(depth == 0 ? "»" : "“")
            }
        }
        return output
    }

    /// « - » → « — » с неразрывным пробелом перед тире; тире в конце фрагмента тоже.
    static func dashes(_ text: String) -> String {
        var result = text.replacingOccurrences(of: " - ", with: "\(nbsp)— ")
        if result.hasSuffix(" -") { result = String(result.dropLast(2)) + "\(nbsp)—" }
        if result.hasPrefix("- ") { result = "— " + result.dropFirst(2) }
        return result
    }

    /// Неразрывный пробел после коротких слов: «в\u{00A0}огне», «и\u{00A0}сердца».
    static func bindShortWords(_ text: String) -> String {
        let parts = text.components(separatedBy: " ")
        guard parts.count > 1 else { return text }
        var output = ""
        for (index, part) in parts.enumerated() {
            output += part
            guard index < parts.count - 1 else { break }
            let word = part.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "«„(\"—"))
            output += shortWords.contains(word) ? nbsp : " "
        }
        return output
    }

    /// Последнее слово не остаётся одно в строке: склеиваем его с предыдущим, если оно короткое.
    static func bindLastWord(_ text: String) -> String {
        guard let range = text.range(of: " ", options: .backwards) else { return text }
        let last = text[range.upperBound...]
        guard last.count <= 10 else { return text }
        return text.replacingCharacters(in: range, with: nbsp)
    }

    /// Заголовок суры: «АШ-ШАРХ 94:5».
    static func title(sura: SuraInfo?, ref: AyahRef, uppercased: Bool = true) -> String {
        let name = sura?.ru ?? "Сура \(ref.sura)"
        let text = "\(name)\(nbsp)\(ref.sura):\(ref.ayah)"
        return uppercased ? text.uppercased() : text
    }

    /// Заголовок для нескольких аятов: «АР-РАХМАН 55:1–4».
    static func title(sura: SuraInfo?, from first: AyahRef, to last: AyahRef, uppercased: Bool = true) -> String {
        guard first != last else { return title(sura: sura, ref: first, uppercased: uppercased) }
        let name = sura?.ru ?? "Сура \(first.sura)"
        let text = "\(name)\(nbsp)\(first.sura):\(first.ayah)–\(last.ayah)"
        return uppercased ? text.uppercased() : text
    }

    /// Варианты начала аята для обрезки, от длинного к короткому: сначала по концу предложения,
    /// затем по концу фразы (запятая, точка с запятой), в крайнем случае — по словам. Каждый с «…».
    static func truncatedPrefixes(_ text: String) -> [String] {
        func cuts(at characters: String) -> [String] {
            var result: [String] = []
            var index = text.startIndex
            let set = CharacterSet(charactersIn: characters)
            while let range = text.rangeOfCharacter(from: set, range: index..<text.endIndex) {
                // Закрывающие кавычки после знака остаются с предложением: «…Господа?».
                var end = range.upperBound
                while end < text.endIndex, "»\"“)".contains(text[end]) { end = text.index(after: end) }
                if end < text.endIndex { result.append(String(text[..<end])) }
                index = end
            }
            return result.reversed()
        }
        let sentences = cuts(at: ".!?")
        var phrases = cuts(at: ",;:").filter { phrase in !sentences.contains(phrase) }
        // Граница перед тире: «Он - Аллах» → «Он…».
        var search = text.startIndex
        while let range = text.range(of: " - ", range: search..<text.endIndex) {
            phrases.append(String(text[..<range.lowerBound]))
            search = range.upperBound
        }
        phrases.sort { $0.count > $1.count }
        var words: [String] = []
        var parts = text.split(separator: " ")
        while parts.count > 1 { parts.removeLast(); words.append(parts.joined(separator: " ")) }
        let ellipsis: (String) -> String = { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",;: ")) + "\(nbsp)…" }
        // Самая длинная подходящая граница предложения или фразы, слова — только в крайнем случае.
        let boundaries = Array(Set(sentences + phrases)).sorted { $0.count > $1.count }
        return (boundaries + words).map(ellipsis)
    }

    /// Законченная мысль: аят не обрывается запятой или двоеточием.
    static func isComplete(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
        return ".!?»\"…)".contains(last)
    }
}
