import Foundation
import SwiftData
import Testing
@testable import MoiFinansy

struct DebtCalculatorTests {
    let calendar = TestCalendar.calendar

    private func debt(_ direction: DebtDirection, _ remaining: Decimal, currency: String = "TJS", due: Date? = nil, closed: Bool = false) -> DebtSnapshot {
        DebtSnapshot(id: UUID(), direction: direction, remaining: remaining, currencyCode: currency, dueDate: due, isClosed: closed)
    }

    @Test func totalsConvertCurrencies() {
        let debts = [debt(.theyOwe, 500), debt(.theyOwe, 10, currency: "USD"), debt(.iOwe, 300), debt(.iOwe, 999, closed: true)]
        let totals = DebtCalculator.totals(debts) { amount, currency in currency == "USD" ? amount * 11 : amount }
        #expect(totals.owedToMe == 610)
        #expect(totals.iOwe == 300)
        #expect(totals.net == 310)
    }

    @Test func overdue() {
        let now = TestCalendar.date(2026, 10, 23)
        let debts = [debt(.theyOwe, 100, due: TestCalendar.date(2026, 10, 20)), debt(.iOwe, 100, due: TestCalendar.date(2026, 10, 30)), debt(.theyOwe, 0, due: TestCalendar.date(2026, 10, 1))]
        #expect(DebtCalculator.overdue(debts, now: now, calendar: calendar).count == 1)
    }
}

@MainActor
struct DebtServiceTests {
    @Test func partialAndFullRepaymentCreateTransactions() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        DefaultData.seed(in: context)
        let card = try #require(try context.fetch(FetchDescriptor<Account>()).first { $0.name == "Карта" })

        let debt = Debt(personName: "Али", direction: .theyOwe, amount: 1000, currencyCode: "TJS")
        DebtService.create(debt, recordIn: card, in: context)
        #expect(card.balance == -1000)

        DebtService.addPayment(400, to: debt, account: card, in: context)
        #expect(debt.remaining == 600)
        #expect(debt.isClosed == false)
        DebtService.addPayment(600, to: debt, account: card, in: context)
        #expect(debt.isClosed)
        #expect(card.balance == 0)

        let incomes = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.type == .income }
        #expect(incomes.count == 2)
        #expect(incomes.allSatisfy { $0.category?.name == "Возврат долга" })
    }
}

struct CurrencyConverterTests {
    let rates: [String: Decimal] = ["TJS": 1, "USD": dec("10.9"), "RUB": dec("0.13")]

    @Test func convertsThroughBase() {
        let rate: (String) -> Decimal = { rates[$0] ?? 1 }
        #expect(CurrencyConverter.convert(100, from: "USD", to: "TJS", rateToBase: rate) == 1090)
        #expect(CurrencyConverter.convert(1090, from: "TJS", to: "USD", rateToBase: rate) == 100)
        #expect(CurrencyConverter.convert(1000, from: "RUB", to: "USD", rateToBase: rate) == dec("11.93"))
        #expect(CurrencyConverter.convert(5, from: "TJS", to: "TJS", rateToBase: rate) == 5)
    }
}

@MainActor
struct BalanceInclusionTests {
    @Test func savingsExcludedByDefaultAndToggleable() {
        let card = Account(name: "Карта", symbol: "creditcard.fill", colorHex: "#007AFF", initialBalance: 1000)
        let piggy = Account(name: "Копилка", symbol: "building.columns.fill", colorHex: "#FF9500", initialBalance: 500)
        piggy.isSavings = true
        #expect(card.countsInBalance)
        #expect(piggy.countsInBalance == false)
        piggy.countsInBalance = true
        card.countsInBalance = false
        #expect(piggy.countsInBalance)
        #expect(card.countsInBalance == false)
    }
}

@MainActor
struct ReportCSVTests {
    @Test func csvHasTotals() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        DefaultData.seed(in: context)
        let accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))
        let cash = accounts[0], card = accounts[1]
        let items = [
            Transaction(type: .income, amount: 25_000, account: card),
            Transaction(type: .expense, amount: Decimal(string: "1250.5")!, account: card),
            Transaction(type: .expense, amount: 300, account: cash),
            Transaction(type: .transfer, amount: 5000, account: card, toAccount: cash),
            Transaction(type: .adjustment, amount: 10, account: cash),
        ]
        items.forEach(context.insert)
        let totals = ReportExporter.totals(items)
        #expect(totals.income == 25_000)
        #expect(totals.expense == Decimal(string: "1550.5")!)
        #expect(totals.net == Decimal(string: "23449.5")!)
        let csv = ReportExporter.csvText(items)
        #expect(csv.contains(";;;Итого доход;25000;"))
        #expect(csv.contains(";;;Итого расход;-1550,5;"))
        #expect(csv.contains(";;;Чистый итог;23449,5;"))
        #expect(csv.contains(";-1250,5;"))
    }
}
