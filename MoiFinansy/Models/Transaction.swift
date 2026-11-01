import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var typeRaw: String = TransactionType.expense.rawValue
    var amount: Decimal = 0
    var category: Category?
    var account: Account?
    /// Счёт назначения для переводов.
    var toAccount: Account?
    var date: Date = Date.now
    var note: String = ""
    var isRecurring: Bool = false
    var createdAt: Date = Date.now
    /// Магазин или получатель (из SMS, чека, выписки).
    var merchant: String = ""
    /// Операция ждёт выбора категории в папке «Входящие».
    var needsReview: Bool = false
    var sourceRaw: String = TransactionSource.manual.rawValue
    /// Последние 4 цифры карты для импортированных операций.
    var cardLast4: String = ""
    /// Теги через запятую, без «#».
    var tagsRaw: String = ""
    /// Сумма зачисления для перевода между счетами в разных валютах.
    var toAmount: Decimal?

    @Relationship(deleteRule: .nullify, inverse: \SMSImportLog.transaction)
    var importLogs: [SMSImportLog]? = []
    @Relationship(deleteRule: .cascade, inverse: \Attachment.transaction)
    var attachments: [Attachment]? = []
    @Relationship(deleteRule: .nullify, inverse: \DebtPayment.transaction)
    var debtPayments: [DebtPayment]? = []

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var source: TransactionSource {
        get { TransactionSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var tags: [String] {
        get { tagsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { tagsRaw = newValue.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }.joined(separator: ",") }
    }

    init(
        type: TransactionType,
        amount: Decimal,
        category: Category? = nil,
        account: Account? = nil,
        toAccount: Account? = nil,
        date: Date = .now,
        note: String = "",
        isRecurring: Bool = false
    ) {
        self.typeRaw = type.rawValue
        self.amount = amount
        self.category = category
        self.account = account
        self.toAccount = toAccount
        self.date = date
        self.note = note
        self.isRecurring = isRecurring
        self.createdAt = .now
    }

    /// Снимок для чистых расчётов (без SwiftData).
    var entry: MoneyEntry {
        MoneyEntry(
            id: id,
            amount: CurrencyService.toBase(amount, from: currencyCode),
            date: date,
            type: type,
            categoryID: category?.id,
            isRecurring: isRecurring,
            note: note
        )
    }

    /// Валюта операции = валюта счёта.
    var currencyCode: String { account?.currencyCode ?? SharedDefaults.currencyCode }

    var displayTitle: String {
        switch type {
        case .transfer:
            "\(account?.name ?? "?") → \(toAccount?.name ?? "?")"
        case .adjustment:
            "Корректировка баланса"
        default:
            category?.name ?? (merchant.isEmpty ? (needsReview ? "Без категории" : type.title) : merchant)
        }
    }
}
