import Foundation
import SwiftData

/// Конверт: часть зарплаты на группу категорий (еда, транспорт, жильё…).
@Model
final class Envelope {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "envelope.fill"
    var colorHex: String = "#007AFF"
    var monthlyAmount: Decimal = 0
    var order: Int = 0
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Category.envelope)
    var categories: [Category]? = []

    init(name: String, symbol: String, colorHex: String, monthlyAmount: Decimal, order: Int) {
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.monthlyAmount = monthlyAmount
        self.order = order
        self.createdAt = .now
    }
}

/// Архив «Месяц закрыт»: итоги сохраняются снимком.
@Model
final class MonthClosure {
    var id: UUID = UUID()
    var month: Date = Date.now
    var createdAt: Date = Date.now
    var income: Decimal = 0
    var expense: Decimal = 0
    var saved: Decimal = 0
    var summaryData: Data = Data()

    init(summary: MonthSummary) {
        self.month = summary.month
        self.income = summary.income
        self.expense = summary.expense
        self.saved = summary.saved
        self.summaryData = (try? JSONEncoder().encode(summary)) ?? Data()
        self.createdAt = .now
    }

    var summary: MonthSummary? { try? JSONDecoder().decode(MonthSummary.self, from: summaryData) }
}
