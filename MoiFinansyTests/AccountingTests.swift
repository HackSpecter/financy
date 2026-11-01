import Foundation
import Testing
@testable import MoiFinansy

struct TagParserTests {
    @Test func extractsTags() {
        let result = TagParser.extract(from: "обед #Работа с коллегами #поездка, #работа")
        #expect(result.note == "обед с коллегами")
        #expect(result.tags == ["работа", "поездка"])
    }

    @Test func noTags() {
        #expect(TagParser.extract(from: "просто заметка").tags.isEmpty)
    }
}

struct NetWorthCalculatorTests {
    let calendar = TestCalendar.calendar

    @Test func monthlyHistory() {
        let movements = [
            NetWorthCalculator.Movement(date: TestCalendar.date(2026, 8, 5), delta: 25_000),
            NetWorthCalculator.Movement(date: TestCalendar.date(2026, 8, 20), delta: -20_000),
            NetWorthCalculator.Movement(date: TestCalendar.date(2026, 9, 5), delta: 25_000),
            NetWorthCalculator.Movement(date: TestCalendar.date(2026, 10, 10), delta: -3_000),
        ]
        let history = NetWorthCalculator.history(start: 1000, movements: movements, months: 3, now: TestCalendar.date(2026, 10, 23), calendar: calendar)
        #expect(history.map(\.value) == [6000, 31_000, 28_000])
    }

    @Test func breakdownTotal() {
        let breakdown = NetWorthCalculator.Breakdown(accounts: 5000, savings: 2000, owedToMe: 1000, iOwe: 500)
        #expect(breakdown.total == 7500)
    }
}

struct SubscriptionDetectorTests {
    let calendar = TestCalendar.calendar

    private func payment(_ key: String, _ amount: Decimal, _ month: Int, _ day: Int) -> SubscriptionDetector.Payment {
        .init(key: key, title: key, amount: amount, date: TestCalendar.date(2026, month, day), categoryID: nil)
    }

    @Test func detectsMonthlyPayment() {
        let payments = [
            payment("netflix", 120, 7, 12), payment("netflix", 120, 8, 13), payment("netflix", 125, 9, 12),
            payment("кафе", 45, 7, 1), payment("кафе", 300, 8, 20), payment("кафе", 30, 9, 5),
            payment("spotify", 60, 8, 3), payment("spotify", 60, 9, 3),
        ]
        let found = SubscriptionDetector.detect(payments, excluding: [], calendar: calendar)
        #expect(found.map(\.title) == ["netflix"])
        #expect(found.first?.amount == 120)
        #expect(found.first?.dayOfMonth == 12)
    }

    @Test func skipsExisting() {
        let payments = [payment("netflix", 120, 7, 12), payment("netflix", 120, 8, 12), payment("netflix", 120, 9, 12)]
        #expect(SubscriptionDetector.detect(payments, excluding: ["netflix"], calendar: calendar).isEmpty)
    }

    @Test func monthlyEquivalent() {
        #expect(SubscriptionDetector.monthlyEquivalent(1200, frequency: .yearly) == 100)
        #expect(SubscriptionDetector.monthlyEquivalent(12, frequency: .weekly) == 52)
    }
}

struct CashFlowCalculatorTests {
    let calendar = TestCalendar.calendar

    @Test func projectsBalanceToMonthEnd() {
        let now = TestCalendar.date(2026, 9, 28, 15)
        let rent = ScheduledPayment(title: "Аренда", amount: 1000, date: TestCalendar.date(2026, 9, 30, 0), type: .expense, isMandatory: true)
        let days = CashFlowCalculator.month(
            of: now,
            entries: [expense(50, TestCalendar.date(2026, 9, 28, 10))],
            scheduled: [rent],
            balanceNow: 5000,
            dailySpend: 100,
            spentToday: 50,
            now: now,
            calendar: calendar
        )
        #expect(days.count == 30)
        #expect(days[26].balance == nil)            // 27-е — прошлое
        #expect(days[27].balance == 4950)           // сегодня: ещё 50 до средней нормы
        #expect(days[28].balance == 4850)
        #expect(days[29].balance == 3750)           // аренда
        #expect(days[29].scheduled.count == 1)
        #expect(days[27].expense == 50)
    }
}

struct MonthCloserTests {
    let calendar = TestCalendar.calendar

    @Test func summaryComparesWithPreviousMonth() {
        let taxi = CategoryInfo(id: UUID(), name: "Такси", symbol: "car.fill", colorHex: "#FFCC00")
        let food = CategoryInfo(id: UUID(), name: "Продукты", symbol: "cart.fill", colorHex: "#34C759")
        let entries = [
            expense(500, TestCalendar.date(2026, 8, 10), category: taxi.id),
            expense(2000, TestCalendar.date(2026, 8, 10), category: food.id),
            expense(800, TestCalendar.date(2026, 9, 10), category: taxi.id),
            expense(1500, TestCalendar.date(2026, 9, 10), category: food.id),
            income(25_000, TestCalendar.date(2026, 9, 5)),
        ]
        let summary = MonthCloser.summary(entries: entries, categories: [taxi.id: taxi, food.id: food], saved: 2500, month: TestCalendar.date(2026, 9, 1), now: TestCalendar.date(2026, 10, 2), calendar: calendar)
        #expect(summary.expense == 2300)
        #expect(summary.income == 25_000)
        #expect(summary.saved == 2500)
        #expect(summary.previousExpense == 2500)
        #expect(summary.topCategories.first?.name == "Продукты")
        #expect(summary.worst.first?.name == "Такси")
        #expect(summary.best.first?.name == "Продукты")
        #expect(summary.expenseChange == dec("-0.08"))
    }
}

struct EnvelopeCalculatorTests {
    @Test func status() {
        let food = UUID()
        let entries = [expense(300, .now, category: food), expense(999, .now, category: UUID())]
        let status = EnvelopeCalculator.status(allocated: 1000, categoryIDs: [food], entries: entries)
        #expect(status.spent == 300)
        #expect(status.remaining == 700)
        #expect(EnvelopeCalculator.unallocated(income: 25_000, envelopes: [6000, 4000]) == 15_000)
    }
}
