import Foundation
import SwiftData
import Testing
@testable import MoiFinansy

struct GoalCalculatorTests {
    let calendar = TestCalendar.calendar
    let now = TestCalendar.date(2026, 10, 1)

    @Test func perMonthAndOnTrack() {
        let progress = GoalCalculator.progress(
            target: 6000,
            contributions: [(1000, TestCalendar.date(2026, 8, 1)), (1000, TestCalendar.date(2026, 9, 1))],
            createdAt: TestCalendar.date(2026, 7, 1),
            deadline: TestCalendar.date(2027, 2, 1),
            now: now,
            calendar: calendar
        )
        #expect(progress.saved == 2000)
        #expect(progress.remaining == 4000)
        #expect(progress.perMonth == 1000)
        #expect(abs(progress.fraction - 1.0 / 3.0) < 0.0001)
        // ~667 в месяц за последние 90 дней → 4000 за ~6 мес. → позже срока.
        #expect(progress.isOnTrack == false)
        #expect(progress.forecastDate != nil)
    }

    @Test func reachedGoal() {
        let progress = GoalCalculator.progress(target: 500, contributions: [(600, now)], createdAt: now, deadline: nil, now: now, calendar: calendar)
        #expect(progress.isReached)
        #expect(progress.remaining == 0)
        #expect(progress.fraction == 1)
        #expect(progress.isOnTrack == nil)
    }

    @Test func noContributionsNoForecast() {
        let progress = GoalCalculator.progress(target: 1000, contributions: [], createdAt: now, deadline: nil, now: now, calendar: calendar)
        #expect(progress.forecastDate == nil)
        #expect(progress.monthlyPace == 0)
    }
}

struct SavingsCalculatorTests {
    @Test func payYourselfFirst() {
        #expect(SavingsCalculator.payYourselfFirst(income: 25_000, percent: 10) == 2500)
        #expect(SavingsCalculator.payYourselfFirst(income: 25_000, percent: 0) == 0)
    }

    @Test func roundUps() {
        // 45 → 50 (+5), 20 → 20 (0), 3,50 → 10 (+6,50)
        #expect(SavingsCalculator.roundUp([45, 20, dec("3.5")], step: 10) == dec("11.5"))
    }
}

@MainActor
@Suite(.serialized)
struct PayYourselfFirstTests {
    @Test func salaryMovesPercentToSavingsAndLowersDailyLimit() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        DefaultData.seed(in: context)
        let previous = SavingsService.payYourselfPercent
        SavingsService.payYourselfPercent = 10
        defer { SavingsService.payYourselfPercent = previous }

        let salary = try #require(try context.fetch(FetchDescriptor<MoiFinansy.Category>()).first { $0.name == "Зарплата" })
        let card = try #require(try context.fetch(FetchDescriptor<Account>()).first { $0.name == "Карта" })
        let income = TransactionService.add(type: .income, amount: 25_000, category: salary, account: card, in: context)

        let transfers = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.type == .transfer }
        #expect(transfers.count == 1)
        #expect(transfers.first?.amount == 2500)
        #expect(transfers.first?.toAccount?.isSavings == true)
        #expect(card.balance == 22_500)

        // Бюджет месяца без лимита = доход − отложенное.
        let all = try context.fetch(FetchDescriptor<Transaction>())
        let allowance = try #require(FinanceService.allowance(transactions: all, budgets: [], rules: [], now: income.date))
        #expect(allowance.monthBudget == 22_500)

        // Повторный вызов не создаёт второй перевод.
        #expect(SavingsService.handleIncome(income, in: context) == nil)
    }
}

@MainActor
struct GoalContributionTests {
    @Test func alreadySavedDoesNotTouchCash() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        DefaultData.seed(in: context)
        let cash = try #require(try context.fetch(FetchDescriptor<Account>()).first { $0.name == "Наличные" })
        cash.initialBalance = 30
        let goal = SavingsGoal(name: "Машина", targetAmount: 60_000, deadline: nil, symbol: "car.fill", colorHex: "#007AFF")
        context.insert(goal)

        SavingsService.contribute(8000, to: goal, from: nil, in: context)
        #expect(cash.balance == 30)
        #expect(SavingsService.savingsAccount(in: context).balance == 8000)
        #expect(goal.saved == 8000)

        SavingsService.contribute(10, to: goal, from: cash, in: context)
        #expect(cash.balance == 20)
        #expect(SavingsService.savingsAccount(in: context).balance == 8010)
    }
}
