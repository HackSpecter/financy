import Foundation

/// Плоские Sendable-снимки данных для чистых расчётов, виджетов и тестов.
nonisolated struct MoneyEntry: Sendable, Hashable, Identifiable {
    var id: UUID = UUID()
    var amount: Decimal
    var date: Date
    var type: TransactionType
    var categoryID: UUID?
    var isRecurring: Bool = false
    var note: String = ""
}

nonisolated struct CategoryInfo: Sendable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
}

nonisolated struct ScheduledPayment: Sendable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var amount: Decimal
    var date: Date
    var type: TransactionType
    var isMandatory: Bool
    var categoryID: UUID?
}

nonisolated struct PlannerSnapshot: Sendable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var date: Date
    var time: Date?
    var isDone: Bool
    var priority: PlannerPriority
    var createdAt: Date
}
