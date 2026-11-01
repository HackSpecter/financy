import Foundation

/// Автоматические текстовые выводы для отчётов.
nonisolated enum InsightsEngine {
    nonisolated struct Insight: Sendable, Hashable, Identifiable {
        enum Tone: Sendable { case positive, negative, neutral }
        var id: String
        var symbol: String
        var text: String
        var tone: Tone
    }

    static func make(
        comparisons: [ReportCalculator.CategoryComparison],
        currentTotals: [ReportCalculator.CategoryTotal],
        summary: ReportCalculator.Summary,
        categories: [UUID: CategoryInfo],
        periodName: String = "в этом месяце",
        currency: String = SharedDefaults.currencyCode
    ) -> [Insight] {
        var insights: [Insight] = []
        let minimumNoticeable = Decimal(100)

        // Рост и снижение по категориям относительно прошлого периода.
        let changed = comparisons
            .filter { $0.change != nil && max($0.current, $0.previous) >= minimumNoticeable }
            .sorted { abs($0.change!) > abs($1.change!) }
        if let growth = changed.first(where: { $0.change! >= Decimal(string: "0.2")! }), let name = name(growth.categoryID, categories) {
            insights.append(Insight(
                id: "growth-\(growth.id)",
                symbol: "arrow.up.right.circle.fill",
                text: "\(name): \(periodName) на \(Money.percent(growth.change!)) больше, чем раньше",
                tone: .negative
            ))
        }
        if let drop = changed.first(where: { $0.change! <= Decimal(string: "-0.2")! }), let name = name(drop.categoryID, categories) {
            insights.append(Insight(
                id: "drop-\(drop.id)",
                symbol: "arrow.down.right.circle.fill",
                text: "\(name): потрачено на \(Money.percent(-drop.change!)) меньше — так держать",
                tone: .positive
            ))
        }

        // Доля дохода, которую съедает крупная категория.
        if summary.income > 0, let top = currentTotals.first, let name = name(top.categoryID, categories) {
            let share = top.amount / summary.income
            if share >= Decimal(string: "0.1")! {
                insights.append(Insight(
                    id: "share-\(top.id)",
                    symbol: "chart.pie.fill",
                    text: "\(name) \(isPlural(name) ? "съедают" : "съедает") \(Money.percent(share)) дохода",
                    tone: .neutral
                ))
            }
        }

        // Выходные против будней.
        if summary.weekdayAverage > 0, summary.weekendAverage > 0 {
            let ratio = summary.weekendAverage / summary.weekdayAverage
            if ratio >= Decimal(string: "1.3")! {
                insights.append(Insight(
                    id: "weekend",
                    symbol: "calendar.badge.exclamationmark",
                    text: "Выходные дороже будней в \(ratioText(ratio)) раза",
                    tone: .negative
                ))
            }
        }

        // Сбережения.
        if let rate = summary.savingsRate {
            if rate < 0 {
                insights.append(Insight(
                    id: "deficit",
                    symbol: "exclamationmark.triangle.fill",
                    text: "Расходы превысили доходы на \(Money.format(-summary.balance, currency: currency))",
                    tone: .negative
                ))
            } else if rate >= Decimal(string: "0.05")! {
                insights.append(Insight(
                    id: "savings",
                    symbol: "banknote.fill",
                    text: "Удалось сохранить \(Money.percent(rate)) дохода — \(Money.format(summary.balance, currency: currency))",
                    tone: .positive
                ))
            }
        }

        return insights
    }

    /// «2», «1,5» — для фразы «в N раза».
    static func ratioText(_ ratio: Decimal) -> String {
        let rounded = ratio.rounded(1)
        return Money.formatNumber(rounded, maxFraction: 1)
    }

    /// «Продукты съедают», «Такси съедает».
    static func isPlural(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains(" и ") || ["ы", "и", "ия"].contains { lower.hasSuffix($0) } && lower != "такси"
    }

    private static func name(_ id: UUID?, _ categories: [UUID: CategoryInfo]) -> String? {
        guard let id else { return nil }
        return categories[id]?.name
    }
}
