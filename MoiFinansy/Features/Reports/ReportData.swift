import Foundation

/// Все вычисленные данные экрана отчётов.
struct ReportData {
    var interval: DateInterval
    var entries: [MoneyEntry]
    var summary: ReportCalculator.Summary
    var categories: [ReportCalculator.CategoryTotal]
    var comparisons: [ReportCalculator.CategoryComparison]
    var daily: [ReportCalculator.DayTotal]
    var monthly: [ReportCalculator.MonthTotal]
    var largest: [MoneyEntry]
    var insights: [InsightsEngine.Insight]
    var dailyLimit: Decimal?
    var categoryInfo: [UUID: CategoryInfo]

    static func make(
        transactions: [Transaction],
        categories: [Category],
        budgets: [Budget],
        period: ReportPeriod,
        now: Date = .now,
        calendar: Calendar = AppCalendar.calendar
    ) -> ReportData {
        let interval = period.interval(now: now, calendar: calendar)
        let previous = period.previousInterval(now: now, calendar: calendar)
        let entries = transactions.map(\.entry)
        let info = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.info) })

        let current = ReportCalculator.byCategory(entries, in: interval)
        let before = ReportCalculator.byCategory(entries, in: previous)
        let comparisons = ReportCalculator.compare(current: current, previous: before)
        let summary = ReportCalculator.summary(entries, in: interval, now: now, calendar: calendar)

        let monthsBack = period.kind == .year ? 12 : 6
        let monthlyEnd = min(interval.end.addingTimeInterval(-1), now)

        let totalLimit = budgets.first(where: \.isTotal)?.limit
        let monthBase = totalLimit ?? (summary.income > 0 && period.kind == .month ? summary.income : nil)
        let dailyLimit = monthBase.map { $0 / Decimal(calendar.numberOfDays(inMonthOf: interval.start)) }

        return ReportData(
            interval: interval,
            entries: entries.filter { interval.contains($0.date) },
            summary: summary,
            categories: current,
            comparisons: comparisons,
            daily: period.kind == .year ? [] : ReportCalculator.daily(entries, in: interval, calendar: calendar),
            monthly: ReportCalculator.monthly(entries, months: monthsBack, endingAt: monthlyEnd, calendar: calendar),
            largest: ReportCalculator.largest(entries, in: interval),
            insights: InsightsEngine.make(comparisons: comparisons, currentTotals: current, summary: summary, categories: info, periodName: period.phrase),
            dailyLimit: dailyLimit,
            categoryInfo: info
        )
    }

    func info(_ id: UUID?) -> CategoryInfo {
        id.flatMap { categoryInfo[$0] } ?? CategoryInfo(id: UUID(), name: "Без категории", symbol: "questionmark", colorHex: "#8E8E93")
    }
}
