import Foundation
import SwiftData

/// Создание, дублирование и удаление операций с побочными эффектами (виджеты, лимиты).
enum TransactionService {
    @discardableResult
    static func add(
        type: TransactionType,
        amount: Decimal,
        category: Category?,
        account: Account?,
        toAccount: Account? = nil,
        date: Date = .now,
        note: String = "",
        in context: ModelContext
    ) -> Transaction {
        let transaction = Transaction(
            type: type,
            amount: amount,
            category: type == .transfer ? nil : category,
            account: account,
            toAccount: type == .transfer ? toAccount : nil,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if type == .transfer, let from = account, let to = toAccount, from.currencyCode != to.currencyCode {
            transaction.toAmount = CurrencyConverter.convert(amount, from: from.currencyCode, to: to.currencyCode, rateToBase: CurrencyService.rate(for:))
        }
        let parsedTags = TagParser.extract(from: transaction.note)
        if !parsedTags.tags.isEmpty {
            transaction.note = parsedTags.note
            transaction.tags = parsedTags.tags
        }
        context.insert(transaction)
        try? context.save()
        SavingsService.handleIncome(transaction, in: context)
        MotivationService.checkSpending(transaction, in: context)
        TransferMatcher.absorbSMSOperations(into: transaction, in: context)
        if let account { SharedDefaults.lastAccountID = account.id }
        didChange(in: context, category: category)
        return transaction
    }

    @discardableResult
    static func add(template: Template, in context: ModelContext) -> Transaction {
        template.useCount += 1
        return add(
            type: template.type,
            amount: template.amount,
            category: template.category,
            account: template.account ?? lastAccount(in: context),
            note: template.title == template.category?.name ? "" : template.title,
            in: context
        )
    }

    @discardableResult
    static func duplicate(_ transaction: Transaction, in context: ModelContext) -> Transaction {
        add(
            type: transaction.type,
            amount: transaction.amount,
            category: transaction.category,
            account: transaction.account,
            toAccount: transaction.toAccount,
            date: .now,
            note: transaction.note,
            in: context
        )
    }

    static func delete(_ transaction: Transaction, in context: ModelContext) {
        context.delete(transaction)
        try? context.save()
        WidgetRefresher.reload()
    }

    /// Расход, который на самом деле был переводом в копилку (например, на депозит из приложения банка):
    /// становится переводом «счёт → Копилка», из расходов пропадает.
    static func convertToSavings(_ transaction: Transaction, in context: ModelContext) {
        guard transaction.type == .expense, transaction.account?.isSavings != true else { return }
        transaction.type = .transfer
        transaction.toAccount = SavingsService.savingsAccount(in: context)
        transaction.category = nil
        transaction.needsReview = false
        try? context.save()
        InboxNotifications.remove(transaction)
        TransferMatcher.absorbSMSOperations(into: transaction, in: context)
        didChange(in: context, category: nil)
    }

    static func lastAccount(in context: ModelContext) -> Account? {
        let accounts = (try? context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))) ?? []
        let active = accounts.filter { !$0.archived }
        if let id = SharedDefaults.lastAccountID, let account = active.first(where: { $0.id == id }) {
            return account
        }
        return active.first
    }

    static func didChange(in context: ModelContext, category: Category?) {
        WidgetRefresher.reload()
        BudgetAlertService.check(category: category, in: context)
    }
}
