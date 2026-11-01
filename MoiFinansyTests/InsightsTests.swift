import Foundation
import Testing
@testable import MoiFinansy

struct InsightsTests {
    let taxi = CategoryInfo(id: UUID(), name: "Такси", symbol: "car.fill", colorHex: "#FFCC00")
    let cafe = CategoryInfo(id: UUID(), name: "Кафе и рестораны", symbol: "fork.knife", colorHex: "#FF9500")

    private func summary(income: Decimal, expense: Decimal, weekend: Decimal = 0, weekday: Decimal = 0) -> ReportCalculator.Summary {
        ReportCalculator.Summary(income: income, expense: expense, averagePerDay: 0, maxDay: nil, savingsRate: income > 0 ? (income - expense) / income : nil, weekendAverage: weekend, weekdayAverage: weekday)
    }

    @Test func detectsGrowthAndShareAndWeekends() {
        let comparisons = [ReportCalculator.CategoryComparison(categoryID: taxi.id, current: 700, previous: 500)]
        let totals = [
            ReportCalculator.CategoryTotal(categoryID: cafe.id, amount: 4500, share: dec("0.5"), count: 10),
            ReportCalculator.CategoryTotal(categoryID: taxi.id, amount: 700, share: dec("0.1"), count: 10),
        ]
        let insights = InsightsEngine.make(
            comparisons: comparisons,
            currentTotals: totals,
            summary: summary(income: 25_000, expense: 9_000, weekend: 400, weekday: 200),
            categories: [taxi.id: taxi, cafe.id: cafe],
            currency: "TJS"
        )
        let texts = insights.map(\.text)
        #expect(texts.contains("Такси: в этом месяце на 40% больше, чем раньше"))
        #expect(texts.contains("Кафе и рестораны съедают 18% дохода"))
        #expect(texts.contains("Выходные дороже будней в 2 раза"))
        #expect(texts.contains { $0.hasPrefix("Удалось сохранить 64% дохода") })
    }

    @Test func reportsDeficit() {
        let insights = InsightsEngine.make(comparisons: [], currentTotals: [], summary: summary(income: 1000, expense: 1500), categories: [:], currency: "TJS")
        #expect(insights.contains { $0.text == "Расходы превысили доходы на 500 TJS" })
    }

    @Test func ignoresTinyCategories() {
        let comparisons = [ReportCalculator.CategoryComparison(categoryID: taxi.id, current: 30, previous: 10)]
        let insights = InsightsEngine.make(comparisons: comparisons, currentTotals: [], summary: summary(income: 0, expense: 30), categories: [taxi.id: taxi], currency: "TJS")
        #expect(insights.isEmpty)
    }

    @Test func ratioText() {
        #expect(InsightsEngine.ratioText(dec("1.54")) == "1,5")
        #expect(InsightsEngine.ratioText(2) == "2")
    }
}

struct InsightGrammarTests {
    @Test(arguments: [("Продукты", true), ("Развлечения", true), ("Кафе и рестораны", true), ("Такси", false), ("Одежда", false)])
    func pluralAgreement(name: String, plural: Bool) {
        #expect(InsightsEngine.isPlural(name) == plural)
    }
}
