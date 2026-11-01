import Foundation

/// Описание правила разбора SMS. Пустые поля — используются универсальные шаблоны.
nonisolated struct SMSRuleDefinition: Sendable, Hashable, Codable {
    var name = "Универсальное"
    /// Слова через запятую: отправитель или название банка в тексте.
    var senderKeywords = ""
    /// Регулярные выражения: значение берётся из первой группы `( )`.
    var amountPattern = ""
    var balancePattern = ""
    var cardPattern = ""
    var merchantPattern = ""
    var datePattern = ""
    /// Формат даты для `datePattern`, например `dd.MM.yyyy HH:mm:ss`.
    var dateFormat = ""
    /// Ключевые фразы типа операции через запятую (дополняют встроенные).
    var expenseKeywords = ""
    var incomeKeywords = ""
    var transferKeywords = ""
    var cashKeywords = ""
    var ignoreKeywords = ""

    static let generic = SMSRuleDefinition()

    func matches(sender: String?, text: String) -> Bool {
        let keywords = Self.list(senderKeywords)
        guard !keywords.isEmpty else { return false }
        let haystack = ((sender ?? "") + "\n" + text).lowercased()
        return keywords.contains { haystack.contains($0) }
    }

    static func list(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}

/// Разбор банковских SMS на русском, таджикском и английском.
nonisolated enum BankSMSParser {
    enum Kind: String, Sendable, CaseIterable, Codable {
        case purchase, debit, credit, transferOut, transferIn, cashWithdrawal

        var title: String {
            switch self {
            case .purchase: "Покупка"
            case .debit: "Списание"
            case .credit: "Зачисление"
            case .transferOut: "Перевод (исходящий)"
            case .transferIn: "Перевод (входящий)"
            case .cashWithdrawal: "Снятие наличных"
            }
        }

        var transactionType: TransactionType {
            isOutgoing ? .expense : .income
        }

        var isOutgoing: Bool {
            switch self {
            case .purchase, .debit, .transferOut, .cashWithdrawal: true
            case .credit, .transferIn: false
            }
        }
    }

    enum Field: String, Sendable, CaseIterable, Hashable {
        case amount, balance, card, merchant, date, type

        var title: String {
            switch self {
            case .amount: "Сумма"
            case .balance: "Остаток"
            case .card: "Карта"
            case .merchant: "Магазин"
            case .date: "Дата"
            case .type: "Тип"
            }
        }
    }

    struct Parsed: Sendable, Equatable {
        var kind: Kind
        var amount: Decimal
        var currency: String
        var cardLast4: String?
        var merchant: String?
        var date: Date?
        var balance: Decimal?
        var ruleName: String
        var highlights: [Field: NSRange] = [:]
    }

    enum Outcome: Sendable, Equatable {
        case transaction(Parsed)
        /// Не про деньги: коды, реклама.
        case ignored(String)
        /// Про деньги, но разобрать не удалось.
        case unrecognized(String)

        var parsed: Parsed? {
            if case .transaction(let parsed) = self { return parsed }
            return nil
        }
    }

    // MARK: Встроенные словари

    static let ignorePhrases = [
        "код подтверждения", "код для", "ваш код", "code:", "verification", "одноразов", "пароль", "parol",
        "otp", "не сообщайте", "никому не", "рамзи", "акция", "скидк", "выиграй", "розыгрыш", "предодобрен",
        "одобрен кредит", "специальное предложение", "promo",
    ]
    static let cashPhrases = ["снятие налич", "выдача налич", "cash withdrawal", " atm", "банкомат", "гирифтани нақд", "нақд"]
    static let transferInPhrases = [
        "перевод получен", "получен перевод", "входящий перевод", "зачислен перевод", "transfer received",
        "интиқоли воридотӣ", "қабули интиқол",
    ]
    static let creditPhrases = [
        "пополнение", "зачисление", "поступление", "зачислено", "credited", "received", "refill", "top-up", "topup",
        "ворид", "пуркунӣ", "возврат", "refund", "cashback", "кэшбэк",
    ]
    static let transferOutPhrases = ["перевод", "transfer", "интиқол", "p2p"]
    static let purchasePhrases = ["покупка", "оплата", "purchase", "payment", "харид", "пардохт", "pos-"]
    static let debitPhrases = ["списание", "списано", "debit", "снято", "withdraw", "хориҷ", "гирифта шуд"]
    static let balancePhrases = ["остаток", "ост.", "баланс", "доступно", "balance", "avail", "бақия", "боқимонда", "мавҷуд"]

    static let numberPattern = #"(?<![\d*])(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d{1,3}(?:[  ]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)"#
    static let currencyPattern = #"(TJS|TJ|сомони|сомон|смн|сом|USD|\$|долл\.?|RUB|руб\.?|₽|EUR|€|евро)"#

    // MARK: Разбор

    static func parse(
        _ text: String,
        sender: String? = nil,
        rules: [SMSRuleDefinition] = [],
        baseCurrency: String = "TJS",
        calendar: Calendar = AppCalendar.calendar
    ) -> Outcome {
        let rule = rules.first { $0.matches(sender: sender, text: text) } ?? .generic
        let lower = normalize(text)

        if let phrase = (SMSRuleDefinition.list(rule.ignoreKeywords) + ignorePhrases).first(where: { lower.contains($0) }) {
            return .ignored("Служебное сообщение («\(phrase)»)")
        }

        let money = moneyMatches(in: text)
        guard let amount = amount(in: text, rule: rule, money: money, baseCurrency: baseCurrency) else {
            return .ignored("Нет суммы — не похоже на операцию")
        }
        guard amount.value > 0 else { return .ignored("Нулевая сумма") }

        guard let kind = kind(in: lower, rule: rule) else {
            return .unrecognized("Не удалось понять тип операции. Добавьте ключевую фразу в правило банка.")
        }

        var highlights: [Field: NSRange] = [.amount: amount.range]
        if let typeRange = kind.range { highlights[.type] = typeRange }

        let balance = balance(in: text, rule: rule, money: money)
        if let balance { highlights[.balance] = balance.range }
        let card = capture(rule.cardPattern.isEmpty ? nil : rule.cardPattern, in: text) ?? genericCard(in: text)
        if let card { highlights[.card] = card.range }
        let merchant = merchant(in: text, rule: rule)
        if let merchant { highlights[.merchant] = merchant.range }
        let date = date(in: text, rule: rule, calendar: calendar)
        if let date { highlights[.date] = date.range }

        return .transaction(Parsed(
            kind: kind.kind,
            amount: amount.value,
            currency: amount.currency,
            cardLast4: card?.value,
            merchant: merchant?.value,
            date: date?.value,
            balance: balance?.value,
            ruleName: rule.name,
            highlights: highlights
        ))
    }

    // MARK: Поля

    private struct MoneyMatch {
        var value: Decimal
        var currency: String
        var range: NSRange
        var isBalance: Bool
    }

    private static func moneyMatches(in text: String) -> [MoneyMatch] {
        let ns = text as NSString
        var result: [MoneyMatch] = []
        let forward = numberPattern + #"\s*"# + currencyPattern + #"(?![A-Za-zА-Яа-яЁё])"#
        let backward = currencyPattern + #"\s*"# + numberPattern
        for (pattern, numberGroup, currencyGroup) in [(forward, 1, 2), (backward, 2, 1)] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let numberRange = match.range(at: numberGroup)
                guard let value = parseNumber(ns.substring(with: numberRange)) else { continue }
                let currency = normalizeCurrency(ns.substring(with: match.range(at: currencyGroup)))
                let before = ns.substring(with: NSRange(location: max(0, match.range.location - 30), length: min(30, match.range.location)))
                let lineBefore = before.components(separatedBy: "\n").last ?? before
                let isBalance = balancePhrases.contains { normalize(lineBefore).contains($0) }
                result.append(MoneyMatch(value: value, currency: currency, range: numberRange, isBalance: isBalance))
            }
        }
        return result.sorted { $0.range.location < $1.range.location }
    }

    private static func amount(in text: String, rule: SMSRuleDefinition, money: [MoneyMatch], baseCurrency: String) -> (value: Decimal, currency: String, range: NSRange)? {
        if !rule.amountPattern.isEmpty, let match = captures(rule.amountPattern, in: text), let value = parseNumber(match.first.value) {
            let currency = match.second.map { normalizeCurrency($0) } ?? money.first { !$0.isBalance }?.currency ?? baseCurrency
            return (value, currency, match.first.range)
        }
        if let first = money.first(where: { !$0.isBalance }) {
            return (first.value, first.currency, first.range)
        }
        let labelled = #"(?:сумма|amount|маблағ|sum)\s*[:=]?\s*"# + numberPattern
        if let match = capture(labelled, in: text), let value = parseNumber(match.value) {
            return (value, baseCurrency, match.range)
        }
        return nil
    }

    private static func balance(in text: String, rule: SMSRuleDefinition, money: [MoneyMatch]) -> (value: Decimal, range: NSRange)? {
        if !rule.balancePattern.isEmpty, let match = capture(rule.balancePattern, in: text), let value = parseNumber(match.value) {
            return (value, match.range)
        }
        if let first = money.first(where: \.isBalance) {
            return (first.value, first.range)
        }
        let labelled = #"(?:остаток|баланс|balance|доступно|бақия)\s*[:=]?\s*"# + numberPattern
        if let match = capture(labelled, in: text), let value = parseNumber(match.value) {
            return (value, match.range)
        }
        return nil
    }

    private static func genericCard(in text: String) -> (value: String, range: NSRange)? {
        let patterns = [
            #"\d{0,6}[\*xX•·]+\s?(\d{4})(?!\d)"#,
            #"(?:ending|оканч\w*\s+на|последние\s+цифры|карт[аеуы]?\s*№?)\s*(\d{4})(?!\d)"#,
        ]
        for pattern in patterns {
            if let match = capture(pattern, in: text) { return match }
        }
        return nil
    }

    private static func merchant(in text: String, rule: SMSRuleDefinition) -> (value: String, range: NSRange)? {
        var found: (value: String, range: NSRange)?
        if !rule.merchantPattern.isEmpty {
            found = capture(rule.merchantPattern, in: text, options: [.caseInsensitive, .anchorsMatchLines])
        }
        if found == nil {
            let labelled = #"(?:магазин|мерчант|merchant|место|получатель|recipient|terminal|терминал|мағоза|описание|details)\s*[:\-]?\s*([^\n,;]+)"#
            found = capture(labelled, in: text, options: [.caseInsensitive, .anchorsMatchLines])
        }
        if found == nil {
            let inline = #"(?:\s|^)(?:в|В|at|AT|At)\s+([A-Za-zА-Яа-яЁё"«][^\n,;]{1,40}?)(?=\s*(?:[,;\n]|\.\s|\.$|\s(?:Остаток|остаток|Баланс|баланс|Balance|Сумма|Карта)|$))"#
            found = capture(inline, in: text, options: [.anchorsMatchLines])
        }
        guard var merchant = found else { return nil }
        merchant.value = merchant.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:-\"«»"))
        guard (2...50).contains(merchant.value.count), merchant.value.rangeOfCharacter(from: .letters) != nil else { return nil }
        return merchant
    }

    private static func date(in text: String, rule: SMSRuleDefinition, calendar: Calendar) -> (value: Date, range: NSRange)? {
        if !rule.datePattern.isEmpty, !rule.dateFormat.isEmpty, let match = capture(rule.datePattern, in: text) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = rule.dateFormat
            if let date = formatter.date(from: match.value) { return (date, match.range) }
        }
        let ns = text as NSString
        let patterns: [(String, [Int])] = [
            (#"(\d{2})[./-](\d{2})[./-](\d{2,4})[ ,T]+(\d{1,2}):(\d{2})(?::(\d{2}))?"#, [1, 2, 3, 4, 5, 6]),
            (#"(\d{4})-(\d{2})-(\d{2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?"#, [3, 2, 1, 4, 5, 6]),
        ]
        for (pattern, order) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { continue }
            func number(_ index: Int) -> Int? {
                let range = match.range(at: order[index])
                return range.location == NSNotFound ? nil : Int(ns.substring(with: range))
            }
            guard let day = number(0), let month = number(1), var year = number(2), let hour = number(3), let minute = number(4) else { continue }
            if year < 100 { year += 2000 }
            var components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: number(5) ?? 0)
            components.timeZone = calendar.timeZone
            if let date = calendar.date(from: components) { return (date, match.range) }
        }
        return nil
    }

    private static func kind(in lower: String, rule: SMSRuleDefinition) -> (kind: Kind, range: NSRange?)? {
        let custom: [(Kind, [String])] = [
            (.cashWithdrawal, SMSRuleDefinition.list(rule.cashKeywords)),
            (.transferOut, SMSRuleDefinition.list(rule.transferKeywords)),
            (.credit, SMSRuleDefinition.list(rule.incomeKeywords)),
            (.debit, SMSRuleDefinition.list(rule.expenseKeywords)),
        ]
        let builtIn: [(Kind, [String])] = [
            (.cashWithdrawal, cashPhrases),
            (.transferIn, transferInPhrases),
            (.credit, creditPhrases),
            (.transferOut, transferOutPhrases),
            (.purchase, purchasePhrases),
            (.debit, debitPhrases),
        ]
        for (kind, phrases) in custom + builtIn {
            for phrase in phrases {
                if let range = lower.range(of: normalize(phrase)) {
                    var resolved = kind
                    // Входящий перевод, если в тексте есть слова зачисления.
                    if kind == .transferOut, creditPhrases.contains(where: lower.contains) || transferInPhrases.contains(where: lower.contains) {
                        resolved = .transferIn
                    }
                    return (resolved, NSRange(range, in: lower))
                }
            }
        }
        return nil
    }

    // MARK: Утилиты

    static func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "ё", with: "е")
    }

    static func parseNumber(_ raw: String) -> Decimal? {
        var cleaned = raw.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "")
        if cleaned.contains(","), cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        } else if let comma = cleaned.firstIndex(of: ","), cleaned[cleaned.index(after: comma)...].count == 3, cleaned.filter({ $0 == "," }).count >= 1, cleaned.count > 4 {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func normalizeCurrency(_ raw: String) -> String {
        let value = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        switch value {
        case "usd", "$", "долл": return "USD"
        case "rub", "руб", "₽": return "RUB"
        case "eur", "€", "евро": return "EUR"
        default: return "TJS"
        }
    }

    private static func capture(_ pattern: String?, in text: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> (value: String, range: NSRange)? {
        guard let pattern, let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let range = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        guard range.location != NSNotFound else { return nil }
        return (ns.substring(with: range), range)
    }

    private static func captures(_ pattern: String, in text: String) -> (first: (value: String, range: NSRange), second: String?)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges > 1 else { return nil }
        let first = match.range(at: 1)
        guard first.location != NSNotFound else { return nil }
        var second: String?
        if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound {
            second = ns.substring(with: match.range(at: 2))
        }
        return ((ns.substring(with: first), first), second)
    }

    /// Дата со временем в произвольном тексте (для чеков и выписок).
    static func findDate(in text: String, calendar: Calendar = AppCalendar.calendar) -> Date? {
        date(in: text, rule: .generic, calendar: calendar)?.value
    }

    /// Проверка шаблона из редактора правил.
    static func isValidPattern(_ pattern: String) -> Bool {
        pattern.isEmpty || (try? NSRegularExpression(pattern: pattern)) != nil
    }
}

/// «Обучить парсер»: строит правило по примеру SMS и значениям, которые указал пользователь.
nonisolated enum RuleLearner {
    struct Sample: Sendable {
        var text: String
        var name: String
        var senderKeywords: String
        var amount: String?
        var balance: String?
        var card: String?
        var merchant: String?
        var kind: BankSMSParser.Kind
        var typePhrase: String
    }

    static func makeRule(from sample: Sample) -> SMSRuleDefinition {
        var rule = SMSRuleDefinition(name: sample.name, senderKeywords: sample.senderKeywords)
        if let amount = sample.amount { rule.amountPattern = pattern(for: amount, in: sample.text, field: .amount) ?? "" }
        if let balance = sample.balance { rule.balancePattern = pattern(for: balance, in: sample.text, field: .balance) ?? "" }
        if let card = sample.card { rule.cardPattern = pattern(for: card, in: sample.text, field: .card) ?? "" }
        if let merchant = sample.merchant { rule.merchantPattern = pattern(for: merchant, in: sample.text, field: .merchant) ?? "" }
        let phrase = sample.typePhrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !phrase.isEmpty {
            switch sample.kind {
            case .cashWithdrawal: rule.cashKeywords = phrase
            case .transferIn, .transferOut: rule.transferKeywords = phrase
            case .credit: rule.incomeKeywords = phrase
            case .purchase, .debit: rule.expenseKeywords = phrase
            }
        }
        return rule
    }

    /// Шаблон: текст перед значением в той же строке + форма значения.
    static func pattern(for rawValue: String, in text: String, field: BankSMSParser.Field) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let range = text.range(of: value, options: .caseInsensitive) else { return nil }

        let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        var prefix = String(text[lineStart..<range.lowerBound])
        if field == .card {
            while let last = prefix.last, "0123456789*xX•· ".contains(last) { prefix.removeLast() }
        }
        prefix = String(prefix.trimmingCharacters(in: .whitespaces).suffix(30))
        let anchor = prefix.isEmpty ? "^" : escape(prefix)

        let valuePattern: String
        switch field {
        case .amount, .balance:
            valuePattern = #"\s*([0-9](?:[0-9  ]*[0-9])?(?:[.,][0-9]{1,2})?)"#
        case .card:
            valuePattern = #"\s*[0-9]{0,6}[\*xX•·]*\s?([0-9]{4})"#
        case .merchant:
            let lineEnd = text[range.upperBound...].firstIndex(of: "\n") ?? text.endIndex
            let suffix = String(text[range.upperBound..<lineEnd]).trimmingCharacters(in: .whitespaces)
            let stop = suffix.isEmpty ? #"\s*$"# : #"\s*"# + escape(String(suffix.prefix(12)))
            valuePattern = #"\s*(.+?)(?="# + stop + ")"
        case .date, .type:
            return nil
        }
        return "(?m)" + anchor + valuePattern
    }

    private static func escape(_ text: String) -> String {
        NSRegularExpression.escapedPattern(for: text)
            .replacingOccurrences(of: #"\s+"#, with: #"\\s+"#, options: .regularExpression)
    }
}
