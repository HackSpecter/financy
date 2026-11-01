import Foundation

/// Фильтры списка операций.
struct TransactionFilter: Equatable {
    enum Period: String, CaseIterable, Identifiable {
        case all, today, week, month, custom
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: "Всё время"
            case .today: "Сегодня"
            case .week: "Неделя"
            case .month: "Месяц"
            case .custom: "Свой период"
            }
        }
    }

    var period: Period = .all
    var customStart = AppCalendar.calendar.startOfMonth(for: .now)
    var customEnd = Date.now
    var categoryID: UUID?
    var accountID: UUID?
    var type: TransactionType?

    var isActive: Bool { period != .all || categoryID != nil || accountID != nil || type != nil }

    func interval(now: Date = .now, calendar: Calendar = AppCalendar.calendar) -> DateInterval? {
        switch period {
        case .all: nil
        case .today: calendar.dayInterval(for: now)
        case .week: calendar.dateInterval(of: .weekOfYear, for: now)
        case .month: calendar.monthInterval(for: now)
        case .custom:
            DateInterval(start: calendar.startOfDay(for: min(customStart, customEnd)), end: calendar.dayInterval(for: max(customStart, customEnd)).end)
        }
    }

    /// Поиск по заметке, категории и сумме («45», «1250,5»).
    static func matches(_ transaction: Transaction, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if transaction.note.localizedCaseInsensitiveContains(query) { return true }
        if transaction.merchant.localizedCaseInsensitiveContains(query) { return true }
        let tagQuery = query.hasPrefix("#") ? String(query.dropFirst()).lowercased() : query.lowercased()
        if !tagQuery.isEmpty, transaction.tags.contains(where: { $0.hasPrefix(tagQuery) }) { return true }
        if transaction.category?.name.localizedCaseInsensitiveContains(query) == true { return true }
        if let amount = Money.parse(query), amount == transaction.amount { return true }
        let digits = query.filter(\.isNumber)
        if !digits.isEmpty, Money.formatNumber(transaction.amount).filter(\.isNumber).hasPrefix(digits) { return true }
        return false
    }

    func apply(to transactions: [Transaction], query: String) -> [Transaction] {
        let interval = interval()
        return transactions.filter { transaction in
            if let interval, !interval.contains(transaction.date) { return false }
            if let type, transaction.type != type { return false }
            if let categoryID, transaction.category?.id != categoryID { return false }
            if let accountID, transaction.account?.id != accountID, transaction.toAccount?.id != accountID { return false }
            return Self.matches(transaction, query: query)
        }
    }
}

/// Группа операций за один день.
struct TransactionDay: Identifiable {
    var date: Date
    var transactions: [Transaction]
    var id: Date { date }
    var expense: Decimal { transactions.filter { $0.type == .expense }.sum(\.amount) }
    var income: Decimal { transactions.filter { $0.type == .income }.sum(\.amount) }

    static func group(_ transactions: [Transaction], calendar: Calendar = AppCalendar.calendar) -> [TransactionDay] {
        Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
            .map { TransactionDay(date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }
}
