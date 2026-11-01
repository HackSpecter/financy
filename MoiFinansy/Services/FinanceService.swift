import Foundation
import SwiftData

/// Сборка входных данных для расчётов из SwiftData.
enum FinanceService {
    /// Бюджет месяца: общий лимит, иначе фактические + ожидаемые доходы месяца.
    /// `reserve` — деньги, отложенные в копилку: на расходы они не считаются.
    static func monthBudget(budgets: [Budget], entries: [MoneyEntry], upcoming: [ScheduledPayment], reserve: Decimal = 0, now: Date, calendar: Calendar) -> Decimal? {
        if let total = budgets.first(where: \.isTotal), total.limit > 0 {
            return max(total.limit - reserve, 0)
        }
        let month = calendar.monthInterval(for: now)
        let income = entries.filter { $0.type == .income && month.contains($0.date) }.sum(\.amount)
        let expectedIncome = upcoming.filter { $0.type == .income && month.contains($0.date) }.sum(\.amount)
        let total = income + expectedIncome - reserve
        return total > 0 ? total : nil
    }

    /// Будущие регулярные операции в полуинтервале [from, to).
    static func upcoming(rules: [RecurringRule], from: Date, to: Date, calendar: Calendar) -> [ScheduledPayment] {
        rules
            .filter(\.isActive)
            .flatMap { rule in
                rule.recurrence
                    .occurrences(from: max(rule.nextDate, calendar.startOfDay(for: from)), to: to, calendar: calendar)
                    .map {
                        ScheduledPayment(
                            title: rule.title,
                            amount: rule.amount,
                            date: $0,
                            type: rule.type,
                            isMandatory: rule.isMandatory,
                            categoryID: rule.category?.id
                        )
                    }
            }
            .sorted { $0.date < $1.date }
    }

    static func allowance(
        transactions: [Transaction],
        budgets: [Budget],
        rules: [RecurringRule],
        now: Date = .now,
        calendar: Calendar = AppCalendar.calendar
    ) -> BudgetCalculator.Result? {
        let month = calendar.monthInterval(for: now)
        let inMonth = transactions.filter { month.contains($0.date) }
        let entries = inMonth.map(\.entry)
        let upcoming = upcoming(rules: rules, from: now, to: month.end, calendar: calendar)
        // Уже отложено в копилку + будущие отчисления с ожидаемой зарплаты.
        let saved = inMonth.filter { $0.type == .transfer && $0.toAccount?.isSavings == true && $0.account?.isSavings != true }.sum(\.amount)
        let salaryCategories = Set(rules.filter { $0.type == .income }.compactMap { $0.category?.id })
        let expectedSalary = upcoming.filter { $0.type == .income && $0.categoryID.map(salaryCategories.contains) == true }.sum(\.amount)
        let reserve = saved + SavingsCalculator.payYourselfFirst(income: expectedSalary, percent: SavingsService.payYourselfPercent)
        guard let budget = monthBudget(budgets: budgets, entries: entries, upcoming: upcoming, reserve: reserve, now: now, calendar: calendar) else {
            return nil
        }
        return BudgetCalculator.calculate(monthBudget: budget, entries: entries, upcoming: upcoming, now: now, calendar: calendar)
    }

    /// Вариант для виджетов и интентов: сам читает базу.
    static func allowance(in context: ModelContext, now: Date = .now) -> BudgetCalculator.Result? {
        let calendar = AppCalendar.calendar
        let month = calendar.monthInterval(for: now)
        let start = month.start
        let end = month.end
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        return allowance(transactions: transactions, budgets: budgets, rules: rules, now: now, calendar: calendar)
    }

    static func expenses(in interval: DateInterval, context: ModelContext) -> Decimal {
        let start = interval.start
        let end = interval.end
        let expense = TransactionType.expense.rawValue
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= start && $0.date < end && $0.typeRaw == expense })
        return ((try? context.fetch(descriptor)) ?? []).sum(\.amount)
    }

    static func totalBalance(in context: ModelContext) -> Decimal {
        ((try? context.fetch(FetchDescriptor<Account>())) ?? []).filter { !$0.archived && $0.countsInBalance }.sum(\.balanceInBase)
    }
}
