import Compression
import Foundation

/// Разбор CSV с автоопределением разделителя и кавычками.
nonisolated enum CSVParser {
    static func parse(_ text: String) -> [[String]] {
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r" }
        let delimiter: Character = [";", "\t", ","].max { a, b in
            firstLine.filter { $0 == a }.count < firstLine.filter { $0 == b }.count
        } ?? ";"

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(text.replacingOccurrences(of: "\r\n", with: "\n")).makeIterator()
        var pending: Character?

        while let char = pending ?? iterator.next() {
            pending = nil
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") } else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else if char == delimiter {
                row.append(field.trimmingCharacters(in: .whitespaces))
                field = ""
            } else if char == "\n" || char == "\r" {
                row.append(field.trimmingCharacters(in: .whitespaces))
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []
                field = ""
            } else {
                field.append(char)
            }
        }
        row.append(field.trimmingCharacters(in: .whitespaces))
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }
}

/// Чтение первого листа .xlsx без сторонних библиотек: zip (stored/deflate) + XML.
nonisolated enum XLSXReader {
    enum ReadError: Error { case notZip, missingSheet, corrupted }

    static func rows(from data: Data) throws -> [[String]] {
        let files = try unzip(data)
        let shared = files["xl/sharedStrings.xml"].map(parseSharedStrings) ?? []
        let sheetName = files.keys.filter { $0.hasPrefix("xl/worksheets/sheet") && $0.hasSuffix(".xml") }.sorted().first
        guard let sheetName, let sheet = files[sheetName] else { throw ReadError.missingSheet }
        return parseSheet(sheet, sharedStrings: shared)
    }

    /// Минимальный разбор zip по центральному каталогу.
    static func unzip(_ data: Data) throws -> [String: Data] {
        let bytes = [UInt8](data)
        func u16(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
        func u32(_ offset: Int) -> Int { u16(offset) | u16(offset + 2) << 16 }

        guard bytes.count > 22 else { throw ReadError.notZip }
        var end = bytes.count - 22
        while end >= 0, u32(end) != 0x0605_4B50 { end -= 1 }
        guard end >= 0 else { throw ReadError.notZip }

        let count = u16(end + 10)
        var offset = u32(end + 16)
        var files: [String: Data] = [:]
        for _ in 0..<count {
            guard offset + 46 <= bytes.count, u32(offset) == 0x0201_4B50 else { throw ReadError.corrupted }
            let method = u16(offset + 10)
            let compressedSize = u32(offset + 20)
            let size = u32(offset + 24)
            let nameLength = u16(offset + 28)
            let extraLength = u16(offset + 30)
            let commentLength = u16(offset + 32)
            let localOffset = u32(offset + 42)
            let name = String(decoding: bytes[(offset + 46)..<(offset + 46 + nameLength)], as: UTF8.self)
            offset += 46 + nameLength + extraLength + commentLength

            guard localOffset + 30 <= bytes.count, u32(localOffset) == 0x0403_4B50 else { throw ReadError.corrupted }
            let start = localOffset + 30 + u16(localOffset + 26) + u16(localOffset + 28)
            guard start + compressedSize <= bytes.count else { throw ReadError.corrupted }
            let payload = Array(bytes[start..<(start + compressedSize)])
            switch method {
            case 0:
                files[name] = Data(payload)
            case 8:
                files[name] = try inflate(payload, size: size)
            default:
                continue
            }
        }
        return files
    }

    private static func inflate(_ input: [UInt8], size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        var output = [UInt8](repeating: 0, count: size)
        let written = output.withUnsafeMutableBufferPointer { destination in
            input.withUnsafeBufferPointer { source in
                compression_decode_buffer(destination.baseAddress!, size, source.baseAddress!, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw ReadError.corrupted }
        return Data(output)
    }

    static func parseSharedStrings(_ data: Data) -> [String] {
        let delegate = SharedStringsDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    static func parseSheet(_ data: Data, sharedStrings: [String]) -> [[String]] {
        let delegate = SheetDelegate(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.rows.filter { $0.contains { !$0.isEmpty } }
    }

    /// «C12» → 2.
    static func columnIndex(_ reference: String) -> Int {
        reference.prefix { $0.isLetter }.uppercased().unicodeScalars.reduce(0) { $0 * 26 + Int($1.value) - 64 } - 1
    }
}

private nonisolated final class SharedStringsDelegate: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var inText = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "si" { current = "" }
        if elementName == "t" { inText = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" { inText = false }
        if elementName == "si" { strings.append(current) }
    }
}

private nonisolated final class SheetDelegate: NSObject, XMLParserDelegate {
    let sharedStrings: [String]
    var rows: [[String]] = []
    private var row: [String] = []
    private var column = 0
    private var cellType = ""
    private var value = ""
    private var capturing = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "row": row = []
        case "c":
            column = attributeDict["r"].map(XLSXReader.columnIndex) ?? row.count
            cellType = attributeDict["t"] ?? ""
            value = ""
        case "v", "t": capturing = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { value += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "v", "t": capturing = false
        case "c":
            var text = value
            if cellType == "s", let index = Int(value), sharedStrings.indices.contains(index) { text = sharedStrings[index] }
            while row.count < column { row.append("") }
            if row.count == column { row.append(text) } else if column < row.count { row[column] = text }
        case "row": rows.append(row)
        default: break
        }
    }
}

/// Сопоставление колонок выписки и превращение строк в операции.
nonisolated enum StatementImporter {
    struct Mapping: Sendable, Equatable {
        var hasHeader = true
        var dateColumn: Int?
        var amountColumn: Int?
        /// Отдельные колонки «Расход» и «Приход» вместо одной суммы со знаком.
        var debitColumn: Int?
        var creditColumn: Int?
        var descriptionColumn: Int?
        /// Все суммы без знака считать расходами.
        var unsignedAreExpenses = true
    }

    struct Row: Sendable, Identifiable, Equatable {
        var id: Int
        var date: Date
        /// Со знаком: отрицательная — расход.
        var amount: Decimal
        var description: String
    }

    static func guessMapping(_ table: [[String]]) -> Mapping {
        var mapping = Mapping()
        guard let header = table.first else { return mapping }
        let lower = header.map(BankSMSParser.normalize)
        func find(_ words: [String]) -> Int? { lower.firstIndex { cell in words.contains { cell.contains($0) } } }
        mapping.dateColumn = find(["дата", "date", "сана"])
        mapping.debitColumn = find(["расход", "списан", "debit", "дебет"])
        mapping.creditColumn = find(["приход", "зачисл", "поступ", "credit", "кредит"])
        mapping.amountColumn = (mapping.debitColumn == nil || mapping.creditColumn == nil) ? find(["сумма", "amount", "маблағ", "sum"]) : nil
        mapping.descriptionColumn = find(["описание", "назначение", "получатель", "магазин", "description", "details", "merchant", "контрагент", "тавсиф"])
        mapping.hasHeader = mapping.dateColumn != nil || mapping.amountColumn != nil || mapping.debitColumn != nil

        // Без заголовка — угадываем по содержимому первой строки данных.
        if !mapping.hasHeader, let sample = table.first {
            mapping.dateColumn = sample.firstIndex { parseDate($0, calendar: AppCalendar.calendar) != nil }
            mapping.amountColumn = sample.indices.last { $0 != mapping.dateColumn && parseAmount(sample[$0]) != nil }
            mapping.descriptionColumn = sample.indices.max { sample[$0].filter(\.isLetter).count < sample[$1].filter(\.isLetter).count }
        }
        return mapping
    }

    static func rows(_ table: [[String]], mapping: Mapping, calendar: Calendar = AppCalendar.calendar) -> [Row] {
        let body = mapping.hasHeader ? Array(table.dropFirst()) : table
        return body.enumerated().compactMap { index, cells in
            func cell(_ column: Int?) -> String? {
                guard let column, cells.indices.contains(column) else { return nil }
                let value = cells[column].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
            guard let date = cell(mapping.dateColumn).flatMap({ parseDate($0, calendar: calendar) }) else { return nil }
            var amount: Decimal?
            if let debit = cell(mapping.debitColumn).flatMap(parseAmount), debit != 0 {
                amount = -abs(debit)
            } else if let credit = cell(mapping.creditColumn).flatMap(parseAmount), credit != 0 {
                amount = abs(credit)
            } else if let raw = cell(mapping.amountColumn), let value = parseAmount(raw) {
                let explicitSign = raw.contains("-") || raw.contains("−") || raw.contains("(") || raw.contains("+")
                amount = explicitSign || !mapping.unsignedAreExpenses ? value : -abs(value)
            }
            guard let amount, amount != 0 else { return nil }
            return Row(id: index, date: date, amount: amount, description: cell(mapping.descriptionColumn) ?? "")
        }
    }

    static func parseAmount(_ raw: String) -> Decimal? {
        let negative = raw.contains("-") || raw.contains("−") || (raw.contains("(") && raw.contains(")"))
        let digits = raw.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == " " || $0 == "\u{00A0}" }
            .trimmingCharacters(in: .whitespaces)
        guard digits.contains(where: \.isNumber), let value = BankSMSParser.parseNumber(digits) else { return nil }
        return negative ? -value : value
    }

    static func parseDate(_ raw: String, calendar: Calendar) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        // Excel хранит даты числом дней от 30.12.1899.
        if let serial = Double(value), (20_000...80_000).contains(serial) {
            var components = DateComponents(year: 1899, month: 12, day: 30)
            components.timeZone = calendar.timeZone
            guard let base = calendar.date(from: components) else { return nil }
            return calendar.date(byAdding: .day, value: Int(serial), to: base).map { $0.addingTimeInterval((serial - serial.rounded(.down)) * 86_400) }
        }
        if let date = BankSMSParser.findDate(in: value, calendar: calendar) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        for format in ["dd.MM.yyyy", "dd.MM.yy", "yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy", "yyyy/MM/dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: date))
            }
        }
        return nil
    }

    /// Текст PDF-выписки → таблица [дата, описание, сумма] по строкам с датой и суммой.
    static func table(fromText text: String) -> [[String]] {
        guard let dateRegex = try? NSRegularExpression(pattern: #"\d{2}[./-]\d{2}[./-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?"#),
              let amountRegex = try? NSRegularExpression(pattern: #"[-−+]?\s?"# + BankSMSParser.numberPattern) else { return [] }
        var rows: [[String]] = [["Дата", "Описание", "Сумма"]]
        for line in text.components(separatedBy: .newlines) {
            let ns = line as NSString
            let full = NSRange(location: 0, length: ns.length)
            guard let dateMatch = dateRegex.firstMatch(in: line, range: full) else { continue }
            let amounts = amountRegex.matches(in: line, range: full).filter {
                NSIntersectionRange($0.range, dateMatch.range).length == 0 && ns.substring(with: $0.range).contains(where: { $0 == "." || $0 == "," })
            }
            guard let amountMatch = amounts.last else { continue }
            var description = line
            for range in [amountMatch.range, dateMatch.range].sorted(by: { $0.location > $1.location }) {
                description = (description as NSString).replacingCharacters(in: range, with: " ")
            }
            rows.append([
                ns.substring(with: dateMatch.range),
                description.split(separator: " ").joined(separator: " "),
                ns.substring(with: amountMatch.range).replacingOccurrences(of: " ", with: ""),
            ])
        }
        return rows.count > 1 ? rows : []
    }
}
