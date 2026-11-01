import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "creditcard.fill"
    var colorHex: String = "#0A84FF"
    var initialBalance: Decimal = 0
    var order: Int = 0
    var archived: Bool = false
    /// Валюта счёта; отчёты пересчитываются в базовую.
    var currencyCode: String = "TJS"
    /// Копилка: деньги отсюда не считаются доступными на расходы.
    var isSavings: Bool = false
    /// Учитывать в «Балансе сейчас»: 0 — автоматически (копилки нет, остальные да), 1 — да, 2 — нет.
    var balanceInclusionRaw: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \BankCard.account)
    var cards: [BankCard]? = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction]? = []
    @Relationship(deleteRule: .nullify, inverse: \Transaction.toAccount)
    var incomingTransfers: [Transaction]? = []
    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.account)
    var recurringRules: [RecurringRule]? = []
    @Relationship(deleteRule: .nullify, inverse: \Template.account)
    var templates: [Template]? = []

    init(name: String, symbol: String, colorHex: String, initialBalance: Decimal = 0, order: Int = 0) {
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.initialBalance = initialBalance
        self.order = order
    }

    /// Входит ли счёт в «Баланс сейчас» на Главной.
    var countsInBalance: Bool {
        get {
            switch balanceInclusionRaw {
            case 1: true
            case 2: false
            default: !isSavings
            }
        }
        set { balanceInclusionRaw = newValue ? 1 : 2 }
    }

    /// Баланс в базовой валюте — для общих сумм.
    var balanceInBase: Decimal { CurrencyService.toBase(balance, from: currencyCode) }

    /// Текущий баланс: начальный остаток + доходы − расходы ± переводы.
    var balance: Decimal {
        let own = (transactions ?? []).reduce(Decimal.zero) { sum, transaction in
            switch transaction.type {
            case .income, .adjustment: sum + transaction.amount
            case .expense, .transfer: sum - transaction.amount
            }
        }
        let incoming = (incomingTransfers ?? []).reduce(Decimal.zero) { $0 + ($1.toAmount ?? $1.amount) }
        return initialBalance + own + incoming
    }
}
