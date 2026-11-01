import Foundation
import SwiftData

/// Банковская карта: SMS по ней попадают на привязанный счёт.
@Model
final class BankCard {
    var id: UUID = UUID()
    var last4: String = ""
    var name: String = ""
    var bankName: String = ""
    /// Читать SMS по этой карте.
    var isActive: Bool = true
    var createdAt: Date = Date.now
    var account: Account?

    init(last4: String, name: String = "", bankName: String = "", account: Account?) {
        self.last4 = last4
        self.name = name
        self.bankName = bankName
        self.account = account
        self.createdAt = .now
    }

    var title: String { name.isEmpty ? "Карта •\(last4)" : "\(name) •\(last4)" }
}

/// Правило разбора SMS конкретного банка. Хранится в данных — редактируется без обновления приложения.
@Model
final class BankSMSRule {
    var id: UUID = UUID()
    var name: String = ""
    /// Слова через запятую: имя отправителя или название банка в тексте.
    var senderKeywords: String = ""
    var isEnabled: Bool = true
    var isBuiltIn: Bool = false
    var order: Int = 0
    var amountPattern: String = ""
    var balancePattern: String = ""
    var cardPattern: String = ""
    var merchantPattern: String = ""
    var datePattern: String = ""
    var dateFormat: String = ""
    var expenseKeywords: String = ""
    var incomeKeywords: String = ""
    var transferKeywords: String = ""
    var cashKeywords: String = ""
    var ignoreKeywords: String = ""
    var updatedAt: Date = Date.now

    init(name: String, senderKeywords: String, order: Int, isBuiltIn: Bool = false) {
        self.name = name
        self.senderKeywords = senderKeywords
        self.order = order
        self.isBuiltIn = isBuiltIn
        self.updatedAt = .now
    }

    var definition: SMSRuleDefinition {
        SMSRuleDefinition(
            name: name,
            senderKeywords: senderKeywords,
            amountPattern: amountPattern,
            balancePattern: balancePattern,
            cardPattern: cardPattern,
            merchantPattern: merchantPattern,
            datePattern: datePattern,
            dateFormat: dateFormat,
            expenseKeywords: expenseKeywords,
            incomeKeywords: incomeKeywords,
            transferKeywords: transferKeywords,
            cashKeywords: cashKeywords,
            ignoreKeywords: ignoreKeywords
        )
    }

    func apply(_ definition: SMSRuleDefinition) {
        name = definition.name
        senderKeywords = definition.senderKeywords
        amountPattern = definition.amountPattern
        balancePattern = definition.balancePattern
        cardPattern = definition.cardPattern
        merchantPattern = definition.merchantPattern
        datePattern = definition.datePattern
        dateFormat = definition.dateFormat
        expenseKeywords = definition.expenseKeywords
        incomeKeywords = definition.incomeKeywords
        transferKeywords = definition.transferKeywords
        cashKeywords = definition.cashKeywords
        ignoreKeywords = definition.ignoreKeywords
        updatedAt = .now
    }
}

/// «Магазин → категория»: запоминается после выбора пользователя.
@Model
final class MerchantRule {
    var id: UUID = UUID()
    /// Нормализованная подстрока названия магазина.
    var pattern: String = ""
    var category: Category?
    var useCount: Int = 0
    var isUserDefined: Bool = false
    var createdAt: Date = Date.now

    init(pattern: String, category: Category?, isUserDefined: Bool) {
        self.pattern = pattern
        self.category = category
        self.isUserDefined = isUserDefined
        self.createdAt = .now
    }
}

nonisolated enum SMSImportStatus: String, Codable, CaseIterable, Sendable {
    case imported, needsReview, duplicate, ignored, unknownCard, unrecognized, merged

    var title: String {
        switch self {
        case .imported: "Записано"
        case .needsReview: "Во «Входящих»"
        case .duplicate: "Дубль"
        case .ignored: "Пропущено"
        case .unknownCard: "Чужая карта"
        case .unrecognized: "Не распознано"
        case .merged: "Перевод между картами"
        }
    }

    var symbol: String {
        switch self {
        case .imported: "checkmark.circle.fill"
        case .needsReview: "tray.full.fill"
        case .duplicate: "doc.on.doc.fill"
        case .ignored: "minus.circle.fill"
        case .unknownCard: "creditcard.trianglebadge.exclamationmark"
        case .unrecognized: "questionmark.circle.fill"
        case .merged: "arrow.left.arrow.right.circle.fill"
        }
    }
}

/// Журнал импорта: что пришло и что получилось.
@Model
final class SMSImportLog {
    var id: UUID = UUID()
    var receivedAt: Date = Date.now
    var sender: String = ""
    var text: String = ""
    var statusRaw: String = SMSImportStatus.unrecognized.rawValue
    var summary: String = ""
    var ruleName: String = ""
    var cardLast4: String = ""
    var amount: Decimal?
    var balance: Decimal?
    /// Остаток из SMS минус баланс счёта в приложении.
    var balanceDifference: Decimal?
    var operationDate: Date?
    var sourceRaw: String = TransactionSource.sms.rawValue
    var transaction: Transaction?

    init(text: String, sender: String, source: TransactionSource = .sms) {
        self.text = text
        self.sender = sender
        self.sourceRaw = source.rawValue
        self.receivedAt = .now
    }

    var status: SMSImportStatus {
        get { SMSImportStatus(rawValue: statusRaw) ?? .unrecognized }
        set { statusRaw = newValue.rawValue }
    }

    var hasBalanceMismatch: Bool {
        guard let balanceDifference else { return false }
        return abs(balanceDifference) >= Decimal(string: "0.01")!
    }
}
