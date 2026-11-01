import Charts
import SwiftUI

/// Кольцевая диаграмма расходов по категориям с процентами.
struct CategoryDonutCard: View {
    var data: ReportData
    var onSelect: (CategoryInfo) -> Void
    @Environment(AppSettings.self) private var settings
    @State private var selectedAngle: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(title: "Расходы по категориям", symbol: "chart.pie.fill", tint: Theme.caution)
            Chart(data.categories) { item in
                SectorMark(
                    angle: .value("Сумма", item.amount.chartValue),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(Color(hex: data.info(item.categoryID).colorHex))
                .opacity(selected == nil || selected?.id == item.id ? 1 : 0.35)
            }
            .chartAngleSelection(value: $selectedAngle)
            .chartBackground { proxy in
                GeometryReader { geometry in
                    if let frame = proxy.plotFrame {
                        let rect = geometry[frame]
                        VStack(spacing: 2) {
                            Text(selected.map { data.info($0.categoryID).name } ?? "Всего")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Money.format(selected?.amount ?? data.summary.expense, currency: settings.currencyCode))
                                .font(.headline)
                                .fontDesign(.rounded)
                                .monospacedDigit()
                            if let selected {
                                Text(Money.percent(selected.share)).font(.caption.bold())
                            }
                        }
                        .position(x: rect.midX, y: rect.midY)
                    }
                }
            }
            .frame(height: 220)
            .accessibilityLabel("Диаграмма расходов по категориям")

            VStack(spacing: 10) {
                ForEach(data.categories) { item in
                    let info = data.info(item.categoryID)
                    Button {
                        onSelect(info)
                    } label: {
                        HStack(spacing: 10) {
                            CategoryIcon(symbol: info.symbol, colorHex: info.colorHex, size: 30)
                            Text(info.name).font(.subheadline)
                            Spacer()
                            Text(Money.percent(item.share))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(Money.format(item.amount, currency: settings.currencyCode))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
        .onChange(of: selectedAngle) { _, angle in
            // Тап по сектору открывает детальный экран.
            if angle != nil, let selected {
                onSelect(data.info(selected.categoryID))
                selectedAngle = nil
            }
        }
    }

    private var selected: ReportCalculator.CategoryTotal? {
        guard let selectedAngle else { return nil }
        var cumulative = 0.0
        for item in data.categories {
            cumulative += item.amount.chartValue
            if selectedAngle <= cumulative { return item }
        }
        return nil
    }
}

#Preview {
    CategoryDonutCard(data: .preview) { _ in }.cardPreview()
}
