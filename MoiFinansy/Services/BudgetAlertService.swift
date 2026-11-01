import Foundation
import SwiftData

/// Уведомления при достижении 80% и 100% лимита (один раз в месяц на порог).
enum BudgetAlertService {
    static let thresholds: [Decimal] = [1, Decimal(string: "0.8")!]

    static func check(category: Category?, in context: ModelContext, now: Date = .now) {
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        let calendar = AppCalendar.calendar
        let month = calendar.monthInterval(for: now)
        let relevant = budgets.filter { $0.isTotal || ($0.category != nil && $0.category?.id == category?.id) }
        guard !relevant.isEmpty else { return }

        let start = month.start
        let end = month.end
        let expense = TransactionType.expense.rawValue
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= start && $0.date < end && $0.typeRaw == expense })
        let transactions = (try? context.fetch(descriptor)) ?? []
        let monthKey = now.appFormatted("yyyyMM")

        for budget in relevant where budget.limit > 0 {
            let spent = budget.isTotal
                ? transactions.sum(\.amount)
                : transactions.filter { $0.category?.id == budget.category?.id }.sum(\.amount)
            guard let threshold = crossedThreshold(spent: spent, limit: budget.limit) else { continue }
            let key = "\(SharedDefaults.Key.budgetAlertPrefix)\(budget.id.uuidString).\(monthKey).\(Money.percent(threshold))"
            guard !SharedDefaults.store.bool(forKey: key) else { continue }
            SharedDefaults.store.set(true, forKey: key)

            let name = budget.category?.name ?? "Общий бюджет"
            let title = threshold >= 1 ? "Лимит исчерпан: \(name)" : "Потрачено 80%: \(name)"
            let body = "\(Money.format(spent)) из \(Money.format(budget.limit)) в этом месяце"
            Task { await NotificationService.notifyNow(id: key, title: title, body: body) }
        }
    }

    /// Наибольший достигнутый порог или nil.
    static func crossedThreshold(spent: Decimal, limit: Decimal) -> Decimal? {
        guard limit > 0 else { return nil }
        let ratio = spent / limit
        return thresholds.first { ratio >= $0 }
    }
}
