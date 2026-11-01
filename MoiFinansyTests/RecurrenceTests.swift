import Foundation
import Testing
@testable import MoiFinansy

struct RecurrenceTests {
    let calendar = TestCalendar.calendar

    @Test func monthlyClampsToLastDayOfShortMonth() {
        let rule = Recurrence(frequency: .monthly, dayOfMonth: 31, anchor: TestCalendar.date(2026, 1, 31))
        let next = rule.next(after: TestCalendar.date(2026, 1, 31), calendar: calendar)
        #expect(next == calendar.startOfDay(for: TestCalendar.date(2026, 2, 28)))
    }

    @Test func salaryOnFifthEachMonth() {
        let rule = Recurrence(frequency: .monthly, dayOfMonth: 5, anchor: TestCalendar.date(2026, 1, 1))
        let dates = rule.occurrences(from: TestCalendar.date(2026, 1, 1, 0), to: TestCalendar.date(2026, 4, 1, 0), calendar: calendar)
        #expect(dates.map { calendar.component(.day, from: $0) } == [5, 5, 5])
        #expect(dates.map { calendar.component(.month, from: $0) } == [1, 2, 3])
    }

    @Test func firstOccurrenceIncludesToday() {
        let rule = Recurrence(frequency: .monthly, dayOfMonth: 10, anchor: TestCalendar.date(2026, 3, 1))
        let first = rule.firstOccurrence(onOrAfter: TestCalendar.date(2026, 3, 10, 18), calendar: calendar)
        #expect(first == calendar.startOfDay(for: TestCalendar.date(2026, 3, 10)))
    }

    @Test func weeklyKeepsWeekday() {
        let monday = TestCalendar.date(2026, 10, 5)
        let rule = Recurrence(frequency: .weekly, dayOfMonth: 1, anchor: monday)
        let dates = rule.occurrences(from: TestCalendar.date(2026, 10, 7), to: TestCalendar.date(2026, 10, 27), calendar: calendar)
        #expect(dates.count == 3)
        #expect(dates.allSatisfy { calendar.component(.weekday, from: $0) == calendar.component(.weekday, from: monday) })
    }

    @Test func yearlyRespectsAnchorMonth() {
        let rule = Recurrence(frequency: .yearly, dayOfMonth: 15, anchor: TestCalendar.date(2025, 6, 15))
        let next = rule.firstOccurrence(onOrAfter: TestCalendar.date(2026, 7, 1), calendar: calendar)
        #expect(next == calendar.startOfDay(for: TestCalendar.date(2027, 6, 15)))
    }

    @Test func dailyOccurrences() {
        let rule = Recurrence(frequency: .daily, dayOfMonth: 1, anchor: TestCalendar.date(2026, 1, 1))
        let dates = rule.occurrences(from: TestCalendar.date(2026, 1, 1), to: TestCalendar.date(2026, 1, 8, 0), calendar: calendar)
        #expect(dates.count == 7)
    }
}
