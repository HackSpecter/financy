import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "circle.fill"
    var colorHex: String = "#8E8E93"
    var kindRaw: String = CategoryKind.expense.rawValue
    var order: Int = 0
    var archived: Bool = false
    /// Ключевые слова через запятую для автоподсказки категории по заметке.
    var keywords: String = ""
    var envelope: Envelope?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []
    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget]? = []
    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.category)
    var recurringRules: [RecurringRule]? = []
    @Relationship(deleteRule: .cascade, inverse: \Template.category)
    var templates: [Template]? = []
    @Relationship(deleteRule: .cascade, inverse: \MerchantRule.category)
    var merchantRules: [MerchantRule]? = []

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, symbol: String, colorHex: String, kind: CategoryKind, order: Int, keywords: String = "") {
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.kindRaw = kind.rawValue
        self.order = order
        self.keywords = keywords
    }

    var info: CategoryInfo {
        CategoryInfo(id: id, name: name, symbol: symbol, colorHex: colorHex)
    }
}
