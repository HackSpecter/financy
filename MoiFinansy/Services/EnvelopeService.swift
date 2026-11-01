import Foundation
import SwiftData

nonisolated enum EnvelopeCalculator {
    struct Status: Sendable, Equatable {
        var allocated: Decimal
        var spent: Decimal
        var remaining: Decimal { allocated - spent }
        var fraction: Double { allocated > 0 ? min((spent / allocated).chartValue, 1.5) : 0 }
    }

    static func status(allocated: Decimal, categoryIDs: Set<UUID>, entries: [MoneyEntry]) -> Status {
        Status(allocated: allocated, spent: entries.filter { $0.type == .expense && $0.categoryID.map(categoryIDs.contains) == true }.sum(\.amount))
    }

    /// Нераспределённый остаток дохода.
    static func unallocated(income: Decimal, envelopes: [Decimal]) -> Decimal {
        income - envelopes.reduce(0, +)
    }
}

enum EnvelopeService {
    static var isEnabled: Bool {
        get { SharedDefaults.store.bool(forKey: "envelopes.enabled") }
        set { SharedDefaults.store.set(newValue, forKey: "envelopes.enabled") }
    }

    /// Зарплата пришла — предложить распределить по конвертам.
    static func salaryArrived(_ transaction: Transaction, in context: ModelContext) {
        guard isEnabled, SavingsService.isSalary(transaction, in: context) else { return }
        let body = "Пришло \(Money.format(transaction.amount, currency: transaction.currencyCode)) — распределите по конвертам"
        Task { await NotificationService.notifyNow(id: "envelopes-salary", title: "Зарплата пришла", body: body) }
    }
}
