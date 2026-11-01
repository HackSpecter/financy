import Foundation

/// Расчёт «Можно потратить сегодня» и прогноза до конца месяца.
nonisolated enum BudgetCalculator {
    nonisolated enum Status: String, Sendable {
        case good, warning, over
    }

    nonisolated enum Forecast: Sendable, Equatable {
        /// К концу месяца останется сумма.
        case leftover(Decimal)
        /// Деньги закончатся в указанный день месяца.
        case runsOut(day: Int)
        case unknown
    }

    nonisolated struct Result: Sendable, Equatable {
        var monthBudget: Decimal
        var spentMonth: Decimal
        var spentToday: Decimal
        var mandatoryAhead: Decimal
        var dailyLimit: Decimal
        var leftToday: Decimal
        var remainingMonth: Decimal
        var dayOfMonth: Int
        var daysInMonth: Int
        var daysLeft: Int
        var status: Status
        var forecast: Forecast

        var monthProgress: Double {
            guard monthBudget > 0 else { return 0 }
            return min((spentMonth / monthBudget).chartValue, 1.5)
        }

        var timeProgress: Double { Double(dayOfMonth) / Double(max(daysInMonth, 1)) }
    }

    /// - Parameters:
    ///   - monthBudget: общий бюджет месяца (лимит или ожидаемый доход).
    ///   - entries: операции текущего месяца.
    ///   - upcoming: будущие регулярные платежи до конца месяца.
    ///
    /// Формула: (бюджет − потрачено до сегодня − будущие обязательные) / оставшиеся дни, включая сегодня.
    /// Регулярные операции сегодняшнего дня относятся к «до сегодня», чтобы аренда не съедала дневной лимит.
    static func calculate(
        monthBudget: Decimal,
        entries: [MoneyEntry],
        upcoming: [ScheduledPayment],
        now: Date,
        calendar: Calendar
    ) -> Result {
        let month = calendar.monthInterval(for: now)
        let today = calendar.dayInterval(for: now)
        let expenses = entries.filter { $0.type == .expense && month.contains($0.date) }

        let spentToday = expenses
            .filter { today.contains($0.date) && !$0.isRecurring }
            .sum(\.amount)
        let spentMonth = expenses.sum(\.amount)
        let spentBeforeToday = spentMonth - spentToday

        let mandatoryAhead = upcoming
            .filter { $0.type == .expense && $0.isMandatory && $0.date >= today.start && $0.date < month.end }
            .sum(\.amount)

        let daysInMonth = calendar.numberOfDays(inMonthOf: now)
        let dayOfMonth = calendar.component(.day, from: now)
        let daysLeft = max(daysInMonth - dayOfMonth + 1, 1)

        let availableAtDayStart = monthBudget - spentBeforeToday - mandatoryAhead
        let dailyLimit = max(availableAtDayStart, 0) / Decimal(daysLeft)
        let leftToday = dailyLimit - spentToday
        let remainingMonth = monthBudget - spentMonth - mandatoryAhead

        let status: Status
        if leftToday <= 0 {
            status = .over
        } else if leftToday < dailyLimit * Decimal(string: "0.3")! {
            status = .warning
        } else {
            status = .good
        }

        let discretionary = expenses.filter { !$0.isRecurring }.sum(\.amount)
        let forecast = forecast(
            remaining: remainingMonth,
            discretionarySpent: discretionary,
            dayOfMonth: dayOfMonth,
            daysInMonth: daysInMonth
        )

        return Result(
            monthBudget: monthBudget,
            spentMonth: spentMonth,
            spentToday: spentToday,
            mandatoryAhead: mandatoryAhead,
            dailyLimit: dailyLimit.rounded(2),
            leftToday: leftToday.rounded(2),
            remainingMonth: remainingMonth,
            dayOfMonth: dayOfMonth,
            daysInMonth: daysInMonth,
            daysLeft: daysLeft,
            status: status,
            forecast: forecast
        )
    }

    /// Прогноз при текущем темпе необязательных трат.
    static func forecast(remaining: Decimal, discretionarySpent: Decimal, dayOfMonth: Int, daysInMonth: Int) -> Forecast {
        guard dayOfMonth > 0 else { return .unknown }
        let pace = discretionarySpent / Decimal(dayOfMonth)
        let daysAfterToday = Decimal(daysInMonth - dayOfMonth)
        let projected = remaining - pace * daysAfterToday
        if projected >= 0 {
            return .leftover(projected.rounded(-2))
        }
        guard pace > 0 else { return .unknown }
        if remaining <= 0 { return .runsOut(day: dayOfMonth) }
        let daysCovered = (remaining / pace).rounded(0, .down).intValue
        return .runsOut(day: min(dayOfMonth + daysCovered, daysInMonth))
    }
}
