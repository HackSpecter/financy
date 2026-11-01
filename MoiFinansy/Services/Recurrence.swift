import Foundation

/// Расписание регулярной операции. Чистая логика — покрыта тестами.
nonisolated struct Recurrence: Sendable, Hashable {
    var frequency: RecurrenceFrequency
    var dayOfMonth: Int
    /// Опорная дата: для недельных — день недели, для годовых — месяц.
    var anchor: Date

    /// Первая дата по расписанию не раньше `date` (начало дня).
    func firstOccurrence(onOrAfter date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        switch frequency {
        case .daily:
            return day
        case .weekly:
            let weekday = calendar.component(.weekday, from: anchor)
            let current = calendar.component(.weekday, from: day)
            let shift = (weekday - current + 7) % 7
            return calendar.date(byAdding: .day, value: shift, to: day) ?? day
        case .monthly:
            let candidate = monthlyDate(inMonthOf: day, calendar: calendar)
            if candidate >= day { return candidate }
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.startOfMonth(for: day)) ?? day
            return monthlyDate(inMonthOf: nextMonth, calendar: calendar)
        case .yearly:
            let month = calendar.component(.month, from: anchor)
            let year = calendar.component(.year, from: day)
            let candidate = yearlyDate(year: year, month: month, calendar: calendar)
            if candidate >= day { return candidate }
            return yearlyDate(year: year + 1, month: month, calendar: calendar)
        }
    }

    /// Следующая дата после `date`.
    func next(after date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return firstOccurrence(onOrAfter: tomorrow, calendar: calendar)
    }

    /// Все даты в полуинтервале [from, to).
    func occurrences(from: Date, to: Date, calendar: Calendar, limit: Int = 400) -> [Date] {
        var result: [Date] = []
        var current = firstOccurrence(onOrAfter: from, calendar: calendar)
        while current < to, result.count < limit {
            result.append(current)
            current = next(after: current, calendar: calendar)
        }
        return result
    }

    private func monthlyDate(inMonthOf date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfMonth(for: date)
        let days = calendar.numberOfDays(inMonthOf: start)
        let clamped = min(max(dayOfMonth, 1), days)
        return calendar.date(byAdding: .day, value: clamped - 1, to: start) ?? start
    }

    private func yearlyDate(year: Int, month: Int, calendar: Calendar) -> Date {
        let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? anchor
        return monthlyDate(inMonthOf: monthStart, calendar: calendar)
    }
}
