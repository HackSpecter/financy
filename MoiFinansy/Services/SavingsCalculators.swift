import Foundation

/// Расчёт целей: сколько откладывать, успеваешь ли, когда достигнешь.
nonisolated enum GoalCalculator {
    struct Progress: Sendable, Equatable {
        var saved: Decimal
        var remaining: Decimal
        var fraction: Double
        /// Нужно откладывать в месяц / в день до срока.
        var perMonth: Decimal?
        var perDay: Decimal?
        /// Средний темп пополнений в месяц.
        var monthlyPace: Decimal
        var forecastDate: Date?
        /// nil — срок не задан.
        var isOnTrack: Bool?
        var isReached: Bool { remaining <= 0 }
    }

    static func progress(
        target: Decimal,
        contributions: [(amount: Decimal, date: Date)],
        createdAt: Date,
        deadline: Date?,
        now: Date,
        calendar: Calendar
    ) -> Progress {
        let saved = contributions.sum(\.amount)
        let remaining = max(target - saved, 0)
        let fraction = target > 0 ? min((saved / target).chartValue, 1) : 0

        var perMonth: Decimal?
        var perDay: Decimal?
        if let deadline, remaining > 0 {
            let days = max(calendar.daysBetween(now, deadline), 1)
            let months = max(calendar.dateComponents([.month], from: calendar.startOfDay(for: now), to: deadline).month ?? 0, 1)
            perMonth = (remaining / Decimal(months)).rounded(0, .up)
            perDay = (remaining / Decimal(days)).rounded(0, .up)
        }

        // Темп: пополнения за последние 90 дней (или с создания цели, если она моложе).
        let windowStart = max(calendar.date(byAdding: .day, value: -90, to: now) ?? now, createdAt)
        let windowDays = max(calendar.daysBetween(windowStart, now), 30)
        let recent = contributions.filter { $0.date >= windowStart && $0.date <= now }.sum(\.amount)
        let monthlyPace = (recent / Decimal(windowDays) * 30).rounded(2)

        var forecast: Date?
        if remaining <= 0 {
            forecast = contributions.map(\.date).max()
        } else if monthlyPace > 0 {
            let days = (remaining / monthlyPace * 30).rounded(0, .up).intValue
            forecast = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))
        }

        var onTrack: Bool?
        if let deadline {
            onTrack = remaining <= 0 || (forecast.map { $0 <= deadline } ?? false)
        }

        return Progress(
            saved: saved,
            remaining: remaining,
            fraction: fraction,
            perMonth: perMonth,
            perDay: perDay,
            monthlyPace: monthlyPace,
            forecastDate: forecast,
            isOnTrack: onTrack
        )
    }
}

nonisolated enum SavingsCalculator {
    /// Сколько отложить по правилу «заплати себе сначала».
    static func payYourselfFirst(income: Decimal, percent: Int) -> Decimal {
        guard percent > 0 else { return 0 }
        return (income * Decimal(percent) / 100).rounded(0)
    }

    /// Округление каждой траты вверх до шага (виртуальная копилка).
    static func roundUp(_ amounts: [Decimal], step: Decimal) -> Decimal {
        guard step > 0 else { return 0 }
        return amounts.reduce(Decimal.zero) { total, amount in
            let rounded = (amount / step).rounded(0, .up) * step
            return total + (rounded - amount)
        }
    }
}
