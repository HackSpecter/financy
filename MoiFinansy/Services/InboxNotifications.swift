import Foundation
import SwiftData
import UserNotifications

/// Уведомление «Новая операция — выберите категорию» с кнопками популярных категорий.
enum InboxNotifications {
    static let expenseCategoryID = "HISOB_INBOX_EXPENSE"
    static let incomeCategoryID = "HISOB_INBOX_INCOME"
    static let actionPrefix = "cat."
    nonisolated static let transactionKey = "transactionID"

    /// Регистрирует кнопки: 4 самые частые категории расходов и доходов.
    static func registerCategories(in context: ModelContext) {
        let categories = (try? context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.order)]))) ?? []
        func top(_ kind: CategoryKind) -> [Category] {
            categories
                .filter { $0.kind == kind && !$0.archived }
                .sorted { ($0.transactions?.count ?? 0) > ($1.transactions?.count ?? 0) }
                .prefix(4)
                .map { $0 }
        }
        func actions(_ list: [Category]) -> [UNNotificationAction] {
            list.map { UNNotificationAction(identifier: actionPrefix + $0.id.uuidString, title: $0.name, options: []) }
                + [UNNotificationAction(identifier: "open", title: "Другая…", options: [.foreground])]
        }
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: expenseCategoryID, actions: actions(top(.expense)), intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: incomeCategoryID, actions: actions(top(.income)), intentIdentifiers: [], options: []),
        ])
    }

    static func notify(_ transaction: Transaction) {
        let content = UNMutableNotificationContent()
        let sign = transaction.type == .income ? "+" : "−"
        content.title = "Новая операция \(sign)\(Money.format(transaction.amount, currency: transaction.account?.currencyCode ?? SharedDefaults.currencyCode))"
        var parts: [String] = []
        if !transaction.merchant.isEmpty { parts.append(transaction.merchant) }
        if !transaction.cardLast4.isEmpty { parts.append("Карта •\(transaction.cardLast4)") }
        parts.append("выберите категорию")
        content.body = parts.joined(separator: " · ")
        content.sound = .default
        content.categoryIdentifier = transaction.type == .income ? incomeCategoryID : expenseCategoryID
        content.userInfo = [transactionKey: transaction.id.uuidString]
        let request = UNNotificationRequest(identifier: identifier(transaction.id), content: content, trigger: nil)
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    static func remove(_ transaction: Transaction) {
        let id = identifier(transaction.id)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// Обработка кнопки категории прямо из уведомления. true — обработано без открытия экрана.
    static func handle(action: String, transactionID: String?, in context: ModelContext) -> Bool {
        guard action.hasPrefix(actionPrefix),
              let transactionID = transactionID.flatMap(UUID.init(uuidString:)),
              let categoryID = UUID(uuidString: String(action.dropFirst(actionPrefix.count))) else { return false }
        let transaction = try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == transactionID })).first
        let category = try? context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.id == categoryID })).first
        guard let transaction, let category else { return false }
        InboxService.categorize(transaction, as: category, in: context)
        return true
    }

    private static func identifier(_ id: UUID) -> String { "inbox-\(id.uuidString)" }
}
