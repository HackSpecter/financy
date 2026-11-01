import Foundation
import SwiftData

/// Агрегированные данные для помощника. Модель не видит отдельных операций, только итоги.
enum AssistantData {
    static var context: ModelContext { DataStore.shared.mainContext }

    static func monthInterval(month: Int, year: Int) -> DateInterval? {
        let calendar = AppCalendar.calendar
        guard (1...12).contains(month), let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
        return calendar.monthInterval(for: date)
    }

    static func monthSummary(month: Int, year: Int) -> String {
        guard let interval = monthInterval(month: month, year: year) else { return "Неверный месяц" }
        let (entries, info) = load(around: interval)
        let summary = ReportCalculator.summary(entries, in: interval, now: .now, calendar: AppCalendar.calendar)
        let categories = ReportCalculator.byCategory(entries, in: interval)
        let title = interval.start.appFormatted("LLLLyyyy")
        guard summary.expense > 0 || summary.income > 0 else { return "\(title): операций нет." }
        var lines = [
            "\(title): доходы \(Money.format(summary.income)), расходы \(Money.format(summary.expense)), остаток \(Money.format(summary.balance)).",
            "Средний расход в день \(Money.format(summary.averagePerDay.rounded(0))).",
        ]
        if let rate = summary.savingsRate { lines.append("Норма сбережений \(Money.percent(rate)).") }
        lines.append("Расходы по категориям: " + categories.prefix(8).map { "\(name($0.categoryID, info)) \(Money.format($0.amount)) (\(Money.percent($0.share)))" }.joined(separator: "; "))
        return lines.joined(separator: "\n")
    }

    static func topExpenses(month: Int, year: Int, limit: Int) -> String {
        guard let interval = monthInterval(month: month, year: year) else { return "Неверный месяц" }
        let (entries, info) = load(around: interval)
        let largest = ReportCalculator.largest(entries, in: interval, count: min(max(limit, 1), 10))
        guard !largest.isEmpty else { return "Трат нет." }
        return largest.map { "\($0.date.appFormatted("dMMMM")): \(name($0.categoryID, info)) \(Money.format($0.amount))\($0.note.isEmpty ? "" : " — \($0.note)")" }.joined(separator: "\n")
    }

    static func compare(month1: Int, year1: Int, month2: Int, year2: Int) -> String {
        guard let first = monthInterval(month: month1, year: year1), let second = monthInterval(month: month2, year: year2) else { return "Неверный месяц" }
        let (entries, info) = load(around: DateInterval(start: min(first.start, second.start), end: max(first.end, second.end)))
        let a = ReportCalculator.byCategory(entries, in: first)
        let b = ReportCalculator.byCategory(entries, in: second)
        let rows = ReportCalculator.compare(current: b, previous: a).prefix(8).map {
            "\(name($0.categoryID, info)): \(Money.format($0.previous)) → \(Money.format($0.current)) (\(Money.format($0.delta, showsPlus: true)))"
        }
        return "Сравнение \(first.start.appFormatted("LLLL yyyy")) и \(second.start.appFormatted("LLLL yyyy")), всего \(Money.format(a.sum(\.amount))) → \(Money.format(b.sum(\.amount))):\n" + rows.joined(separator: "\n")
    }

    static func currentStatus() -> String {
        var lines: [String] = ["Сегодня \(Date.now.appFormatted("dMMMMyyyy"))."]
        if let allowance = FinanceService.allowance(in: context) {
            lines.append("Можно потратить сегодня \(Money.format(max(allowance.leftToday, 0))) из дневной нормы \(Money.format(allowance.dailyLimit)).")
            lines.append("В этом месяце потрачено \(Money.format(allowance.spentMonth)) из \(Money.format(allowance.monthBudget)), впереди обязательных платежей \(Money.format(allowance.mandatoryAhead)).")
        }
        lines.append("Баланс по счетам \(Money.format(FinanceService.totalBalance(in: context))).")
        let debts = (try? context.fetch(FetchDescriptor<Debt>())) ?? []
        let totals = DebtCalculator.totals(debts.map(\.snapshot)) { CurrencyService.toBase($0, from: $1) }
        if totals.owedToMe > 0 || totals.iOwe > 0 {
            lines.append("Мне должны \(Money.format(totals.owedToMe)), я должен \(Money.format(totals.iOwe)).")
        }
        let goals = ((try? context.fetch(FetchDescriptor<SavingsGoal>())) ?? []).filter { !$0.isArchived }
        for goal in goals.prefix(5) {
            lines.append("Цель «\(goal.name)»: накоплено \(Money.format(goal.saved)) из \(Money.format(goal.targetAmount)).")
        }
        return lines.joined(separator: "\n")
    }

    private static func load(around interval: DateInterval) -> ([MoneyEntry], [UUID: CategoryInfo]) {
        let start = AppCalendar.calendar.date(byAdding: .month, value: -1, to: interval.start) ?? interval.start
        let end = interval.end
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        return (transactions.map(\.entry), Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.info) }))
    }

    private static func name(_ id: UUID?, _ info: [UUID: CategoryInfo]) -> String {
        id.flatMap { info[$0]?.name } ?? "Без категории"
    }
}
