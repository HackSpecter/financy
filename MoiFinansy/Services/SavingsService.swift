import Foundation
import SwiftData

/// Копилка: «заплати себе сначала», округления, пополнение целей.
enum SavingsService {
    static let payYourselfNote = "Заплати себе сначала"

    static var payYourselfPercent: Int {
        get { SharedDefaults.store.integer(forKey: "savings.percent") }
        set { SharedDefaults.store.set(newValue, forKey: "savings.percent") }
    }

    static var roundUpEnabled: Bool {
        get { SharedDefaults.store.bool(forKey: "savings.roundUp") }
        set { SharedDefaults.store.set(newValue, forKey: "savings.roundUp") }
    }

    static var roundUpStep: Decimal {
        get { Decimal(SharedDefaults.store.object(forKey: "savings.roundUpStep") as? Int ?? 10) }
        set { SharedDefaults.store.set(newValue.intValue, forKey: "savings.roundUpStep") }
    }

    /// Счёт-копилка; создаётся при первом обращении.
    static func savingsAccount(in context: ModelContext) -> Account {
        let accounts = (try? context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))) ?? []
        if let existing = accounts.first(where: { $0.isSavings && !$0.archived }) { return existing }
        let account = Account(name: "Копилка", symbol: "building.columns.fill", colorHex: "#FF9500", order: accounts.count)
        account.isSavings = true
        account.currencyCode = SharedDefaults.currencyCode
        context.insert(account)
        try? context.save()
        return account
    }

    /// Зарплата: категория «Зарплата» или категория регулярного правила дохода.
    static func isSalary(_ transaction: Transaction, in context: ModelContext) -> Bool {
        guard transaction.type == .income, let category = transaction.category else { return false }
        if category.name == "Зарплата" { return true }
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        return rules.contains { $0.type == .income && $0.category?.id == category.id }
    }

    /// При поступлении зарплаты переводит N% в копилку.
    @discardableResult
    static func handleIncome(_ transaction: Transaction, in context: ModelContext) -> Transaction? {
        EnvelopeService.salaryArrived(transaction, in: context)
        let percent = payYourselfPercent
        guard percent > 0, isSalary(transaction, in: context),
              let source = transaction.account, !source.isSavings else { return nil }
        let amount = SavingsCalculator.payYourselfFirst(income: transaction.amount, percent: percent)
        guard amount > 0 else { return nil }
        let savings = savingsAccount(in: context)
        let note = payYourselfNote
        let from = transaction.date.addingTimeInterval(-60)
        let to = transaction.date.addingTimeInterval(120)
        let transferType = TransactionType.transfer.rawValue
        let existing = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.typeRaw == transferType && $0.note == note && $0.date >= from && $0.date <= to
        }))) ?? []
        guard existing.isEmpty else { return nil }

        let transfer = Transaction(type: .transfer, amount: amount, account: source, toAccount: savings, date: transaction.date.addingTimeInterval(1), note: note)
        context.insert(transfer)
        try? context.save()
        return transfer
    }

    /// Округления трат текущего месяца (виртуально) и сколько из них уже переведено.
    static func roundUps(in context: ModelContext, now: Date = .now) -> (total: Decimal, transferred: Decimal) {
        let month = AppCalendar.calendar.monthInterval(for: now)
        let start = month.start
        let end = month.end
        let expense = TransactionType.expense.rawValue
        let expenses = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.typeRaw == expense && $0.date >= start && $0.date < end
        }))) ?? []
        let total = SavingsCalculator.roundUp(expenses.map(\.amount), step: roundUpStep)
        let transferred = Decimal(string: SharedDefaults.store.string(forKey: roundUpKey(now)) ?? "0") ?? 0
        return (total, transferred)
    }

    static func transferRoundUps(_ amount: Decimal, from account: Account, in context: ModelContext, now: Date = .now) {
        guard amount > 0 else { return }
        let savings = savingsAccount(in: context)
        context.insert(Transaction(type: .transfer, amount: amount, account: account, toAccount: savings, date: now, note: "Округления трат"))
        let already = roundUps(in: context, now: now).transferred
        SharedDefaults.store.set("\(already + amount)", forKey: roundUpKey(now))
        try? context.save()
        WidgetRefresher.reload()
    }

    /// Пополнение цели; по желанию — перевод денег в копилку.
    /// Пополнение цели. `account == nil` — деньги уже отложены: копилка растёт, другие счета не меняются.
    /// Иначе — перевод со счёта в копилку.
    static func contribute(_ amount: Decimal, to goal: SavingsGoal, from account: Account?, in context: ModelContext) {
        context.insert(GoalContribution(amount: amount, goal: goal))
        let savings = savingsAccount(in: context)
        if let account, !account.isSavings {
            context.insert(Transaction(type: .transfer, amount: amount, account: account, toAccount: savings, date: .now, note: "Цель «\(goal.name)»"))
        } else {
            context.insert(Transaction(type: .adjustment, amount: amount, account: savings, date: .now, note: "Цель «\(goal.name)»: уже отложено"))
        }
        try? context.save()
        WidgetRefresher.reload()
    }

    private static func roundUpKey(_ date: Date) -> String { "savings.roundUpDone.\(date.appFormatted("yyyyMM"))" }
}
