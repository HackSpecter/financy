import Foundation
import Testing
@testable import MoiFinansy

struct ReportCalculatorTests {
    let calendar = TestCalendar.calendar
    let taxi = UUID()
    let cafe = UUID()
    let food = UUID()
    var september: DateInterval { calendar.monthInterval(for: TestCalendar.date(2026, 9, 15)) }
    var august: DateInterval { calendar.monthInterval(for: TestCalendar.date(2026, 8, 15)) }

    @Test func groupsByCategoryWithShares() {
        let entries = [
            expense(300, TestCalendar.date(2026, 9, 2), category: taxi),
            expense(100, TestCalendar.date(2026, 9, 3), category: taxi),
            expense(600, TestCalendar.date(2026, 9, 4), category: cafe),
            expense(999, TestCalendar.date(2026, 8, 4), category: cafe),
            income(5000, TestCalendar.date(2026, 9, 5)),
        ]
        let totals = ReportCalculator.byCategory(entries, in: september)
        #expect(totals.map(\.categoryID) == [cafe, taxi])
        #expect(totals[0].amount == 600)
        #expect(totals[0].share == dec("0.6"))
        #expect(totals[1].count == 2)
    }

    @Test func dailyIncludesEmptyDays() {
        let entries = [expense(50, TestCalendar.date(2026, 9, 1, 23, 30))]
        let days = ReportCalculator.daily(entries, in: september, calendar: calendar)
        #expect(days.count == 30)
        #expect(days[0].amount == 50)
        #expect(days[1].amount == 0)
    }

    @Test func comparesWithPreviousPeriod() {
        let current = ReportCalculator.byCategory([
            expense(700, TestCalendar.date(2026, 9, 2), category: taxi),
            expense(100, TestCalendar.date(2026, 9, 2), category: cafe),
        ], in: september)
        let previous = ReportCalculator.byCategory([
            expense(500, TestCalendar.date(2026, 8, 2), category: taxi),
            expense(300, TestCalendar.date(2026, 8, 2), category: food),
        ], in: august)
        let comparison = ReportCalculator.compare(current: current, previous: previous)
        let taxiRow = comparison.first { $0.categoryID == taxi }
        #expect(taxiRow?.delta == 200)
        #expect(taxiRow?.change == dec("0.4"))
        #expect(comparison.first { $0.categoryID == food }?.current == 0)
        #expect(comparison.first { $0.categoryID == cafe }?.change == nil)
    }

    @Test func summaryAveragesOnlyElapsedDays() {
        let entries = [
            expense(1000, TestCalendar.date(2026, 9, 1)),
            expense(500, TestCalendar.date(2026, 9, 9)),
            income(25_000, TestCalendar.date(2026, 9, 5)),
        ]
        let summary = ReportCalculator.summary(entries, in: september, now: TestCalendar.date(2026, 9, 10, 18), calendar: calendar)
        #expect(summary.expense == 1500)
        #expect(summary.averagePerDay == 150)
        #expect(summary.maxDay?.amount == 1000)
        #expect(summary.savingsRate == dec("0.94"))
    }

    @Test func weekendVersusWeekday() {
        // 5–6 сентября 2026 — суббота и воскресенье.
        var entries: [MoneyEntry] = []
        for day in 1...7 {
            let weekend = [5, 6].contains(day)
            entries.append(expense(weekend ? 200 : 100, TestCalendar.date(2026, 9, day)))
        }
        let week = DateInterval(start: TestCalendar.date(2026, 9, 1, 0), end: TestCalendar.date(2026, 9, 8, 0))
        let summary = ReportCalculator.summary(entries, in: week, now: TestCalendar.date(2026, 9, 20), calendar: calendar)
        #expect(summary.weekendAverage == 200)
        #expect(summary.weekdayAverage == 100)
    }

    @Test func monthlyTotals() {
        let entries = [
            income(25_000, TestCalendar.date(2026, 8, 5)),
            expense(20_000, TestCalendar.date(2026, 8, 10)),
            income(25_000, TestCalendar.date(2026, 9, 5)),
        ]
        let months = ReportCalculator.monthly(entries, months: 3, endingAt: TestCalendar.date(2026, 9, 20), calendar: calendar)
        #expect(months.count == 3)
        #expect(months[1].savings == 5000)
        #expect(months[2].income == 25_000)
    }
}
