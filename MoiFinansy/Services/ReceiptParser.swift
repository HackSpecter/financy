import Foundation

/// Разбор распознанного текста чека: итоговая сумма, магазин, дата.
nonisolated enum ReceiptParser {
    struct Result: Sendable, Equatable {
        var total: Decimal?
        var merchant: String?
        var date: Date?
    }

    /// Ключевые слова итога в порядке надёжности.
    static let totalKeywords = ["итого к оплате", "к оплате", "итого", "итог", "всего", "total", "jami", "ҷамъ", "сумма"]
    static let serviceWords = ["чек", "кассов", "инн", "ккм", "ккт", "receipt", "добро пожаловать", "welcome", "спасибо", "фискал", "смена", "кассир"]

    static func parse(_ text: String, calendar: Calendar = AppCalendar.calendar) -> Result {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Result(total: total(in: lines), merchant: merchant(in: lines), date: date(in: text, calendar: calendar))
    }

    static func total(in lines: [String]) -> Decimal? {
        for keyword in totalKeywords {
            for (index, line) in lines.enumerated() where BankSMSParser.normalize(line).contains(keyword) {
                if let amount = numbers(in: line).last { return amount }
                if index + 1 < lines.count, let amount = numbers(in: lines[index + 1]).last { return amount }
            }
        }
        // Нет слова «итого» — берём самую большую сумму с копейками.
        return lines.flatMap { line in numbers(in: line).filter { !$0.isWhole } }.max()
    }

    static func merchant(in lines: [String]) -> String? {
        lines.prefix(6).first { line in
            let lower = BankSMSParser.normalize(line)
            let letters = line.filter(\.isLetter).count
            return letters >= 3
                && !serviceWords.contains { lower.contains($0) }
                && !totalKeywords.contains { lower.contains($0) }
                && line.filter(\.isNumber).count < line.count / 2
        }
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "*-=_ \"«»")) }
    }

    static func date(in text: String, calendar: Calendar) -> Date? {
        if let full = BankSMSParser.findDate(in: text, calendar: calendar) { return full }
        let pattern = #"(\d{2})[./](\d{2})[./](\d{2,4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let ns = text as NSString
        guard let day = Int(ns.substring(with: match.range(at: 1))),
              let month = Int(ns.substring(with: match.range(at: 2))),
              var year = Int(ns.substring(with: match.range(at: 3))) else { return nil }
        if year < 100 { year += 2000 }
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }

    static func numbers(in line: String) -> [Decimal] {
        guard let regex = try? NSRegularExpression(pattern: BankSMSParser.numberPattern) else { return [] }
        let ns = line as NSString
        return regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
            .compactMap { BankSMSParser.parseNumber(ns.substring(with: $0.range(at: 1))) }
            .filter { $0 > 0 }
    }
}
