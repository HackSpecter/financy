import Foundation
import SwiftData

nonisolated enum DebtCalculator {
    struct Totals: Sendable, Equatable {
        var owedToMe: Decimal
        var iOwe: Decimal
        var net: Decimal { owedToMe - iOwe }
    }

    /// Итоги открытых долгов в базовой валюте.
    static func totals(_ debts: [DebtSnapshot], convert: (Decimal, String) -> Decimal = { amount, _ in amount }) -> Totals {
        let open = debts.filter { !$0.isClosed && $0.remaining > 0 }
        return Totals(
            owedToMe: open.filter { $0.direction == .theyOwe }.sum { convert($0.remaining, $0.currencyCode) },
            iOwe: open.filter { $0.direction == .iOwe }.sum { convert($0.remaining, $0.currencyCode) }
        )
    }

    static func overdue(_ debts: [DebtSnapshot], now: Date, calendar: Calendar) -> [DebtSnapshot] {
        let today = calendar.startOfDay(for: now)
        return debts.filter { !$0.isClosed && $0.remaining > 0 && ($0.dueDate.map { $0 < today } ?? false) }
    }
}

/// Долги: создание, возвраты с операциями, напоминания.
enum DebtService {
    static func create(_ debt: Debt, recordIn account: Account?, in context: ModelContext) {
        context.insert(debt)
        if let account {
            // Дал в долг — деньги ушли (расход «Долги»), взял — пришли (доход «Прочее»).
            let type: TransactionType = debt.direction == .theyOwe ? .expense : .income
            let category = category(named: debt.direction == .theyOwe ? "Долги" : "Прочее", kind: type == .income ? .income : .expense, in: context)
            let note = debt.direction == .theyOwe ? "В долг: \(debt.personName)" : "Взял в долг у \(debt.personName)"
            context.insert(Transaction(type: type, amount: debt.amount, category: category, account: account, date: debt.date, note: note))
        }
        try? context.save()
        scheduleReminder(for: debt)
        WidgetRefresher.reload()
    }

    /// Частичный или полный возврат; создаёт операцию на счёте.
    static func addPayment(_ amount: Decimal, to debt: Debt, account: Account?, date: Date = .now, in context: ModelContext) {
        let payment = DebtPayment(amount: amount, date: date, debt: debt)
        context.insert(payment)
        if let account {
            let type: TransactionType = debt.direction == .theyOwe ? .income : .expense
            let category = category(named: debt.direction == .theyOwe ? "Возврат долга" : "Долги", kind: type == .income ? .income : .expense, in: context)
            let note = debt.direction == .theyOwe ? "Вернул долг: \(debt.personName)" : "Вернул долг \(debt.personName)"
            let transaction = Transaction(type: type, amount: amount, category: category, account: account, date: date, note: note)
            context.insert(transaction)
            payment.transaction = transaction
        }
        if debt.remaining <= 0 {
            debt.isClosed = true
            NotificationService.cancel(id: reminderID(debt.id))
        }
        try? context.save()
        WidgetRefresher.reload()
    }

    static func scheduleReminder(for debt: Debt) {
        let id = reminderID(debt.id)
        guard let due = debt.dueDate, !debt.isClosed,
              let date = AppCalendar.calendar.date(byAdding: .hour, value: 10, to: AppCalendar.calendar.startOfDay(for: due)) else {
            NotificationService.cancel(id: id)
            return
        }
        let title = debt.direction == .theyOwe ? "Срок возврата долга: \(debt.personName)" : "Пора вернуть долг: \(debt.personName)"
        let body = "Осталось \(Money.format(debt.remaining, currency: debt.currencyCode))"
        Task { await NotificationService.schedule(id: id, title: title, body: body, at: date) }
    }

    static func reminderID(_ id: UUID) -> String { "debt-\(id.uuidString)" }

    private static func category(named name: String, kind: CategoryKind, in context: ModelContext) -> Category? {
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        return categories.first { $0.name == name && $0.kind == kind }
    }
}
