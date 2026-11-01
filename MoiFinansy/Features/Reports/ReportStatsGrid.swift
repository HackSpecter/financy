import SwiftUI

/// Доход, расход, норма сбережений, средний расход в день, самый дорогой день.
struct ReportStatsGrid: View {
    var summary: ReportCalculator.Summary
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                tile("Доходы", Money.format(summary.income, currency: settings.currencyCode), "arrow.up.circle.fill", Theme.positive)
                tile("Расходы", Money.format(summary.expense, currency: settings.currencyCode), "arrow.down.circle.fill", Theme.negative)
            }
            GridRow {
                tile("Норма сбережений", summary.savingsRate.map(Money.percent) ?? "—", "banknote.fill", (summary.savingsRate ?? 0) >= 0 ? .mint : Theme.negative)
                tile("В среднем в день", Money.format(summary.averagePerDay.rounded(0), currency: settings.currencyCode), "divide.circle.fill", .blue)
            }
            if let maxDay = summary.maxDay {
                GridRow {
                    tile("Самый дорогой день · \(maxDay.date.appFormatted("dMMMM"))", Money.format(maxDay.amount, currency: settings.currencyCode), "flame.fill", Theme.caution)
                        .gridCellColumns(2)
                }
            }
        }
    }

    private func tile(_ title: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
            Text(value)
                .font(.title3.bold())
                .fontDesign(.rounded)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ReportStatsGrid(summary: ReportData.preview.summary).cardPreview()
}
