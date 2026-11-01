import SwiftUI

/// Сравнение с прошлым периодом по каждой категории.
struct CategoryComparisonCard: View {
    var data: ReportData
    var onSelect: (CategoryInfo) -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Сравнение с прошлым периодом", symbol: "arrow.left.arrow.right", tint: .indigo)
            ForEach(data.comparisons.prefix(8)) { item in
                let info = data.info(item.categoryID)
                Button {
                    onSelect(info)
                } label: {
                    HStack(spacing: 10) {
                        CategoryIcon(symbol: info.symbol, colorHex: info.colorHex, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(info.name).font(.subheadline)
                            Text("было \(Money.format(item.previous, currency: settings.currencyCode))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Money.format(item.delta, currency: settings.currencyCode, showsPlus: true))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(item.delta > 0 ? Theme.negative : Theme.positive)
                            Text(changeText(item))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    private func changeText(_ item: ReportCalculator.CategoryComparison) -> String {
        guard let change = item.change else { return "новое" }
        return (change > 0 ? "+" : "") + Money.percent(change)
    }
}

#Preview {
    CategoryComparisonCard(data: .preview) { _ in }.cardPreview()
}
