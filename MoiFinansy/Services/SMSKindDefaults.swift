import Foundation
import SwiftData

/// Категория по умолчанию для типа SMS, если в тексте нет магазина: «Пополнение» → «Переводы», «Покупка» → «Покупки».
enum SMSKindDefaults {
    /// Типы, для которых в настройках выбирается категория.
    static let configurableKinds: [BankSMSParser.Kind] = [.credit, .transferIn, .purchase, .debit, .transferOut]

    static func categoryID(for kind: BankSMSParser.Kind) -> UUID? {
        SharedDefaults.store.string(forKey: key(kind)).flatMap(UUID.init(uuidString:))
    }

    static func setCategoryID(_ id: UUID?, for kind: BankSMSParser.Kind) {
        SharedDefaults.store.set(id?.uuidString, forKey: key(kind))
    }

    static func category(for kind: BankSMSParser.Kind, in context: ModelContext) -> Category? {
        guard let id = categoryID(for: kind) else { return nil }
        let category = try? context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })).first
        return category?.archived == false ? category : nil
    }

    /// Исходящие переводы: категория расхода «Переводы» (один раз, для уже установленного приложения тоже).
    static func seedTransfersOutIfNeeded(in context: ModelContext) {
        let flag = "seed.sms.v4"
        guard !SharedDefaults.store.bool(forKey: flag) else { return }
        SharedDefaults.store.set(true, forKey: flag)
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let outgoing = categories.first { $0.name == "Переводы" && $0.kind == .expense } ?? {
            let order = (categories.filter { $0.kind == .expense }.map(\.order).max() ?? -1) + 1
            let category = Category(name: "Переводы", symbol: "arrow.up.right.circle.fill", colorHex: "#5856D6", kind: .expense, order: order, keywords: "перевод,transfer,интиқол")
            context.insert(category)
            return category
        }()
        if categoryID(for: .transferOut) == nil { setCategoryID(outgoing.id, for: .transferOut) }
        try? context.save()
    }

    /// Создаёт категории «Переводы» и «Покупки» и назначает их по умолчанию (один раз).
    /// Уже лежащие во «Входящих» операции из SMS тоже получают категорию.
    static func seedIfNeeded(in context: ModelContext) {
        let flag = "seed.sms.v2"
        guard !SharedDefaults.store.bool(forKey: flag) else { return }
        SharedDefaults.store.set(true, forKey: flag)

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        func findOrCreate(_ name: String, symbol: String, color: String, kind: CategoryKind) -> Category {
            if let existing = categories.first(where: { $0.name == name && $0.kind == kind }) { return existing }
            let order = (categories.filter { $0.kind == kind }.map(\.order).max() ?? -1) + 1
            let category = Category(name: name, symbol: symbol, colorHex: color, kind: kind, order: order)
            context.insert(category)
            return category
        }
        let transfers = findOrCreate("Переводы", symbol: "arrow.down.left.circle.fill", color: "#5856D6", kind: .income)
        let purchases = findOrCreate("Покупки", symbol: "bag.fill", color: "#FF9500", kind: .expense)
        setCategoryID(transfers.id, for: .credit)
        setCategoryID(transfers.id, for: .transferIn)
        setCategoryID(purchases.id, for: .purchase)
        setCategoryID(purchases.id, for: .debit)

        let sms = TransactionSource.sms.rawValue
        let waiting = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.needsReview && $0.sourceRaw == sms }))) ?? []
        for transaction in waiting where transaction.merchant.isEmpty {
            transaction.category = transaction.type == .income ? transfers : purchases
            transaction.needsReview = false
        }
        try? context.save()
    }

    private static func key(_ kind: BankSMSParser.Kind) -> String { "sms.default.\(kind.rawValue)" }
}
