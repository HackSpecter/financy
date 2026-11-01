import Foundation
import SwiftData

/// Шаблон частой операции: «Такси 20», «Обед 45».
@Model
final class Template {
    var id: UUID = UUID()
    var title: String = ""
    var typeRaw: String = TransactionType.expense.rawValue
    var amount: Decimal = 0
    var category: Category?
    var account: Account?
    var order: Int = 0
    var useCount: Int = 0

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    init(title: String, type: TransactionType = .expense, amount: Decimal, category: Category?, account: Account? = nil, order: Int = 0) {
        self.title = title
        self.typeRaw = type.rawValue
        self.amount = amount
        self.category = category
        self.account = account
        self.order = order
    }
}
