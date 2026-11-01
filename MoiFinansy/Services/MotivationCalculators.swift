import Foundation

/// Серия «дней в пределах лимита».
nonisolated enum StreakCalculator {
    struct DayResult: Sendable, Equatable {
        var date: Date
        var spent: Decimal
        var limit: Decimal
        var isWithin: Bool { spent <= limit }
    }

    /// Текущая серия (считая сегодня, если пока в пределах) и лучшая за период.
    static func streaks(_ days: [DayResult], today: Date, calendar: Calendar) -> (current: Int, best: Int) {
        let sorted = days.sorted { $0.date < $1.date }
        var best = 0
        var run = 0
        for day in sorted {
            run = day.isWithin ? run + 1 : 0
            best = max(best, run)
        }
        var current = 0
        for day in sorted.reversed() {
            if calendar.isDate(day.date, inSameDayAs: today), !day.isWithin { continue }
            guard day.isWithin else { break }
            current += 1
        }
        return (current, best)
    }

    /// Дневной лимит и траты для каждого прошедшего дня (как если бы считали в тот день).
    static func dailyResults(
        entries: [MoneyEntry],
        monthBudget: (Date) -> Decimal?,
        from: Date,
        to: Date,
        calendar: Calendar
    ) -> [DayResult] {
        var results: [DayResult] = []
        var day = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: to)
        while day <= last {
            if let budget = monthBudget(day) {
                let month = calendar.monthInterval(for: day)
                let dayEnd = calendar.dayInterval(for: day).end
                let known = entries.filter { month.contains($0.date) && $0.date < dayEnd }
                let noon = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
                let result = BudgetCalculator.calculate(monthBudget: budget, entries: known, upcoming: [], now: noon, calendar: calendar)
                results.append(DayResult(date: day, spent: result.spentToday, limit: result.dailyLimit))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return results
    }
}

/// Предупреждения: необычно крупная трата и опережение темпа.
nonisolated enum SpendingWarnings {
    /// Во сколько раз трата больше средней по категории (nil — обычная).
    static func unusualRatio(amount: Decimal, history: [Decimal], factor: Decimal = 3, minimumSamples: Int = 5) -> Decimal? {
        guard history.count >= minimumSamples else { return nil }
        let average = history.reduce(0, +) / Decimal(history.count)
        guard average > 0 else { return nil }
        let ratio = amount / average
        return ratio >= factor ? ratio.rounded(1) : nil
    }

    /// К середине месяца траты опережают время больше чем на 15 п. п.
    static func isAheadOfPace(_ result: BudgetCalculator.Result) -> Bool {
        result.dayOfMonth >= 10 && result.monthProgress > result.timeProgress + 0.15
    }
}

/// Итоги недели.
nonisolated enum WeeklyReviewCalculator {
    struct Review: Sendable, Equatable {
        var week: DateInterval
        var spent: Decimal
        var previousSpent: Decimal
        var income: Decimal
        var topCategories: [ReportCalculator.CategoryTotal]
        var biggest: MoneyEntry?
        var daysWithinLimit: Int
        var daysCounted: Int
        var change: Decimal? { previousSpent > 0 ? (spent - previousSpent) / previousSpent : nil }
    }

    static func review(entries: [MoneyEntry], days: [StreakCalculator.DayResult], now: Date, calendar: Calendar) -> Review {
        let week = calendar.dateInterval(of: .weekOfYear, for: now) ?? calendar.dayInterval(for: now)
        let previous = DateInterval(start: week.start.addingTimeInterval(-week.duration), end: week.start)
        let inWeek = days.filter { week.contains($0.date) }
        return Review(
            week: week,
            spent: ReportCalculator.expenses(entries, in: week).sum(\.amount),
            previousSpent: ReportCalculator.expenses(entries, in: previous).sum(\.amount),
            income: entries.filter { $0.type == .income && week.contains($0.date) }.sum(\.amount),
            topCategories: Array(ReportCalculator.byCategory(entries, in: week).prefix(3)),
            biggest: ReportCalculator.largest(entries, in: week, count: 1).first,
            daysWithinLimit: inWeek.filter(\.isWithin).count,
            daysCounted: inWeek.count
        )
    }
}
