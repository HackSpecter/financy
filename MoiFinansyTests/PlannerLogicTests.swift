import Foundation
import Testing
@testable import MoiFinansy

struct PlannerLogicTests {
    let calendar = TestCalendar.calendar

    private func item(_ title: String, done: Bool = false, day: Int = 10, hour: Int? = nil, priority: PlannerPriority = .none) -> PlannerSnapshot {
        PlannerSnapshot(
            id: UUID(),
            title: title,
            date: calendar.startOfDay(for: TestCalendar.date(2026, 9, day)),
            time: hour.map { TestCalendar.date(2026, 9, day, $0) },
            isDone: done,
            priority: priority,
            createdAt: TestCalendar.date(2026, 9, 1)
        )
    }

    @Test func doneItemsGoToBottom() {
        let sorted = PlannerLogic.sorted([
            item("Готово", done: true),
            item("Без времени"),
            item("Встреча", hour: 15),
            item("Срочно", priority: .high),
        ])
        #expect(sorted.map(\.title) == ["Встреча", "Срочно", "Без времени", "Готово"])
    }

    @Test func overdueOnlyUndonePastDays() {
        let items = [item("Вчера", day: 9), item("Вчера сделано", done: true, day: 9), item("Сегодня", day: 10)]
        let overdue = PlannerLogic.overdue(items, now: TestCalendar.date(2026, 9, 10, 8), calendar: calendar)
        #expect(overdue.map(\.title) == ["Вчера"])
    }

    @Test func weekStartsOnMonday() {
        let week = PlannerLogic.week(containing: TestCalendar.date(2026, 9, 10), calendar: calendar)
        #expect(week.count == 7)
        #expect(calendar.component(.weekday, from: week[0]) == 2)
    }

    @Test func quickParseMeeting() {
        let parsed = PlannerQuickParse("Встреча с Али завтра в 15:30 !!")
        #expect(parsed.title == "Встреча с Али")
        #expect(parsed.dayOffset == 1)
        #expect(parsed.hour == 15)
        #expect(parsed.minute == 30)
        #expect(parsed.priority == .medium)
        #expect(parsed.type == .meeting)
    }

    @Test func quickParsePlainTask() {
        let parsed = PlannerQuickParse("Купить хлеб")
        #expect(parsed.title == "Купить хлеб")
        #expect(parsed.type == .task)
        #expect(parsed.dayOffset == 0)
        #expect(parsed.priority == .none)
    }
}
