import Foundation
import Testing
@testable import MoiFinansy

struct StreakCalculatorTests {
    let calendar = TestCalendar.calendar

    private func day(_ d: Int, spent: Decimal, limit: Decimal = 100) -> StreakCalculator.DayResult {
        .init(date: calendar.startOfDay(for: TestCalendar.date(2026, 9, d)), spent: spent, limit: limit)
    }

    @Test func currentAndBest() {
        let days = [day(1, spent: 50), day(2, spent: 90), day(3, spent: 99), day(4, spent: 150), day(5, spent: 20), day(6, spent: 30)]
        let result = StreakCalculator.streaks(days, today: TestCalendar.date(2026, 9, 6), calendar: calendar)
        #expect(result.current == 2)
        #expect(result.best == 3)
    }

    @Test func todayOverLimitDoesNotBreakYesterday() {
        let days = [day(4, spent: 10), day(5, spent: 20), day(6, spent: 500)]
        #expect(StreakCalculator.streaks(days, today: TestCalendar.date(2026, 9, 6), calendar: calendar).current == 2)
    }

    @Test func dailyResultsUseOnlyKnownData() {
        let entries = [expense(300, TestCalendar.date(2026, 9, 1)), expense(5000, TestCalendar.date(2026, 9, 2))]
        let results = StreakCalculator.dailyResults(entries: entries, monthBudget: { _ in 30_000 }, from: TestCalendar.date(2026, 9, 1), to: TestCalendar.date(2026, 9, 2), calendar: calendar)
        #expect(results.count == 2)
        #expect(results[0].limit == 1000)        // 30 000 / 30 дней
        #expect(results[0].isWithin)
        #expect(results[1].isWithin == false)    // 5 000 > нормы второго дня
    }
}

struct SpendingWarningsTests {
    @Test func unusualExpense() {
        let history: [Decimal] = [40, 50, 60, 45, 55]
        #expect(SpendingWarnings.unusualRatio(amount: 200, history: history) == 4)
        #expect(SpendingWarnings.unusualRatio(amount: 100, history: history) == nil)
        #expect(SpendingWarnings.unusualRatio(amount: 500, history: [40, 50]) == nil)
    }

    @Test func paceWarning() {
        let calendar = TestCalendar.calendar
        let entries = [expense(15_000, TestCalendar.date(2026, 9, 5))]
        let result = BudgetCalculator.calculate(monthBudget: 25_000, entries: entries, upcoming: [], now: TestCalendar.date(2026, 9, 12), calendar: calendar)
        #expect(SpendingWarnings.isAheadOfPace(result))
        let early = BudgetCalculator.calculate(monthBudget: 25_000, entries: entries, upcoming: [], now: TestCalendar.date(2026, 9, 6), calendar: calendar)
        #expect(SpendingWarnings.isAheadOfPace(early) == false)
    }
}

struct WeeklyReviewTests {
    @Test func comparesWithPreviousWeek() {
        let calendar = TestCalendar.calendar
        // Неделя 14–20 сентября 2026 (пн–вс).
        let entries = [expense(300, TestCalendar.date(2026, 9, 9)), expense(200, TestCalendar.date(2026, 9, 15)), expense(250, TestCalendar.date(2026, 9, 17))]
        let review = WeeklyReviewCalculator.review(entries: entries, days: [], now: TestCalendar.date(2026, 9, 18), calendar: calendar)
        #expect(review.spent == 450)
        #expect(review.previousSpent == 300)
        #expect(review.change == dec("0.5"))
        #expect(review.biggest?.amount == 250)
    }
}
