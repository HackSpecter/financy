import Foundation
import Testing
@testable import MoiFinansy

struct BudgetCalculatorTests {
    let calendar = TestCalendar.calendar
    /// 11 сентября 2026: в месяце 30 дней, осталось 20 (включая сегодня).
    let now = TestCalendar.date(2026, 9, 11, 15)

    @Test func dailyLimitSubtractsMandatoryPayments() {
        let entries = [
            expense(5000, TestCalendar.date(2026, 9, 3)),
            expense(3000, TestCalendar.date(2026, 9, 8)),
            expense(100, TestCalendar.date(2026, 9, 11, 9)),
        ]
        let upcoming = [
            ScheduledPayment(title: "Аренда", amount: 3500, date: TestCalendar.date(2026, 9, 25, 0), type: .expense, isMandatory: true),
            ScheduledPayment(title: "Подписка", amount: 50, date: TestCalendar.date(2026, 9, 20, 0), type: .expense, isMandatory: false),
            ScheduledPayment(title: "Аренда в октябре", amount: 3500, date: TestCalendar.date(2026, 10, 25, 0), type: .expense, isMandatory: true),
        ]
        let result = BudgetCalculator.calculate(monthBudget: 25_000, entries: entries, upcoming: upcoming, now: now, calendar: calendar)

        #expect(result.daysLeft == 20)
        #expect(result.mandatoryAhead == 3500)
        // (25 000 − 8 000 − 3 500) / 20 = 675
        #expect(result.dailyLimit == 675)
        #expect(result.spentToday == 100)
        #expect(result.leftToday == 575)
        #expect(result.status == .good)
    }

    @Test func recurringPaymentTodayDoesNotEatDailyLimit() {
        let entries = [expense(3500, TestCalendar.date(2026, 9, 11, 9), recurring: true)]
        let result = BudgetCalculator.calculate(monthBudget: 23_500, entries: entries, upcoming: [], now: now, calendar: calendar)
        #expect(result.spentToday == 0)
        #expect(result.dailyLimit == 1000)
        #expect(result.leftToday == 1000)
    }

    @Test func overspendIsRed() {
        let entries = [expense(900, TestCalendar.date(2026, 9, 11, 10))]
        let result = BudgetCalculator.calculate(monthBudget: 10_000, entries: entries, upcoming: [], now: now, calendar: calendar)
        #expect(result.dailyLimit == 500)
        #expect(result.leftToday == -400)
        #expect(result.status == .over)
    }

    @Test func warningWhenLittleLeft() {
        let entries = [expense(400, TestCalendar.date(2026, 9, 11, 10))]
        let result = BudgetCalculator.calculate(monthBudget: 10_000, entries: entries, upcoming: [], now: now, calendar: calendar)
        #expect(result.leftToday == 100)
        #expect(result.status == .warning)
    }

    @Test func ignoresOtherMonthsAndIncome() {
        let entries = [
            expense(9999, TestCalendar.date(2026, 8, 31, 20)),
            income(25_000, TestCalendar.date(2026, 9, 5)),
        ]
        let result = BudgetCalculator.calculate(monthBudget: 20_000, entries: entries, upcoming: [], now: now, calendar: calendar)
        #expect(result.spentMonth == 0)
        #expect(result.dailyLimit == 1000)
    }

    @Test func forecastLeftover() {
        // Потрачено 5 000 за 10 дней → 500/день; осталось 20 дней → 10 000; остаток 15 000 − 10 000 = 5 000.
        let forecast = BudgetCalculator.forecast(remaining: 15_000, discretionarySpent: 5_000, dayOfMonth: 10, daysInMonth: 30)
        #expect(forecast == .leftover(5000))
    }

    @Test func forecastRunsOut() {
        // 1 000/день, остаток 4 000 → хватит ещё на 4 дня: до 14 числа.
        let forecast = BudgetCalculator.forecast(remaining: 4_000, discretionarySpent: 10_000, dayOfMonth: 10, daysInMonth: 30)
        #expect(forecast == .runsOut(day: 14))
    }

    @Test func forecastRoundsToHundreds() {
        let forecast = BudgetCalculator.forecast(remaining: 3_249, discretionarySpent: 0, dayOfMonth: 10, daysInMonth: 30)
        #expect(forecast == .leftover(3200))
    }

    @Test func budgetAlertThresholds() {
        #expect(BudgetAlertService.crossedThreshold(spent: 79, limit: 100) == nil)
        #expect(BudgetAlertService.crossedThreshold(spent: 80, limit: 100) == dec("0.8"))
        #expect(BudgetAlertService.crossedThreshold(spent: 130, limit: 100) == 1)
    }
}
