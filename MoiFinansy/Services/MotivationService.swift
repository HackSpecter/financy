import Foundation
import SwiftData

/// Серии, недельный разбор и предупреждения о тратах.
enum MotivationService {
    static var warningsEnabled: Bool {
        get { SharedDefaults.store.object(forKey: "alerts.enabled") as? Bool ?? true }
        set { SharedDefaults.store.set(newValue, forKey: "alerts.enabled") }
    }

    static var weeklyReviewEnabled: Bool {
        get { SharedDefaults.store.object(forKey: "weekly.enabled") as? Bool ?? true }
        set { SharedDefaults.store.set(newValue, forKey: "weekly.enabled") }
    }

    static var bestStreak: Int {
        get { SharedDefaults.store.integer(forKey: "streak.best") }
        set { SharedDefaults.store.set(newValue, forKey: "streak.best") }
    }

    /// Результаты по дням за последние `days` дней.
    static func dailyResults(transactions: [Transaction], budgets: [Budget], rules: [RecurringRule], days: Int = 90, now: Date = .now) -> [StreakCalculator.DayResult] {
        let calendar = AppCalendar.calendar
        let entries = transactions.map(\.entry)
        // Считаем только с первой операции: дни до начала учёта — не «в пределах лимита».
        guard let first = entries.map(\.date).min() else { return [] }
        let windowStart = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        let from = max(windowStart, calendar.startOfDay(for: first))
        return StreakCalculator.dailyResults(
            entries: entries,
            monthBudget: { day in
                let month = calendar.monthInterval(for: day)
                let monthEntries = entries.filter { month.contains($0.date) }
                return FinanceService.monthBudget(budgets: budgets, entries: monthEntries, upcoming: [], now: day, calendar: calendar)
            },
            from: from,
            to: now,
            calendar: calendar
        )
    }

    static func streak(transactions: [Transaction], budgets: [Budget], rules: [RecurringRule], now: Date = .now) -> (current: Int, best: Int) {
        let calendar = AppCalendar.calendar
        let results = dailyResults(transactions: transactions, budgets: budgets, rules: rules, now: now)
        let streak = StreakCalculator.streaks(results, today: now, calendar: calendar)
        // Рекорд не может быть длиннее времени с первой операции.
        let firstDay = transactions.map(\.date).min().map { calendar.startOfDay(for: $0) }
        let possible = firstDay.map { calendar.daysBetween($0, now) + 1 } ?? 0
        if bestStreak > possible { bestStreak = possible }
        let best = max(streak.best, bestStreak)
        if best > bestStreak { bestStreak = best }
        return (streak.current, best)
    }

    /// Проверки после новой траты.
    static func checkSpending(_ transaction: Transaction, in context: ModelContext, now: Date = .now) {
        guard warningsEnabled, transaction.type == .expense else { return }
        let calendar = AppCalendar.calendar

        if let category = transaction.category {
            let since = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            let categoryID = category.id
            let id = transaction.id
            let expense = TransactionType.expense.rawValue
            let history = ((try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
                $0.typeRaw == expense && $0.date >= since && $0.id != id
            }))) ?? []).filter { $0.category?.id == categoryID }
            if let ratio = SpendingWarnings.unusualRatio(amount: transaction.amount, history: history.map(\.amount)) {
                let title = "Необычно крупная трата"
                let body = "\(Money.format(transaction.amount, currency: transaction.currencyCode)) в «\(category.name)» — в \(InsightsEngine.ratioText(ratio)) раза больше обычного"
                Task { await NotificationService.notifyNow(id: "unusual-\(transaction.id.uuidString)", title: title, body: body) }
            }
        }

        let key = "alerts.pace.\(now.appFormatted("yyyyMM"))"
        if !SharedDefaults.store.bool(forKey: key), let result = FinanceService.allowance(in: context, now: now), SpendingWarnings.isAheadOfPace(result) {
            SharedDefaults.store.set(true, forKey: key)
            let body = "Потрачено \(Money.percent(Decimal(result.monthProgress))) бюджета, а прошло \(Money.percent(Decimal(result.timeProgress))) месяца. Сегодня можно \(Money.format(max(result.leftToday, 0)))."
            Task { await NotificationService.notifyNow(id: key, title: "Темп трат опережает план", body: body) }
        }
    }

    /// Каждое воскресенье в 20:00.
    static func scheduleWeeklyReview() {
        guard weeklyReviewEnabled else {
            NotificationService.cancel(id: "weekly-review")
            return
        }
        Task { await NotificationService.scheduleWeekly(id: "weekly-review", weekday: 1, hour: 20, title: "Недельный разбор", body: "Посмотрите, как прошла неделя: траты, серия и лучшие категории") }
    }
}
