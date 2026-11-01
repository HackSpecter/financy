import Charts
import SwiftData
import SwiftUI

/// Детальный экран категории: итог за период, динамика по месяцам, операции.
struct CategoryDetailView: View {
    var category: CategoryInfo
    var period: ReportPeriod
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let interval = period.interval()
        let own = transactions.filter { $0.category?.id == category.id && $0.type == .expense }
        let inPeriod = own.filter { interval.contains($0.date) }
        let months = ReportCalculator.monthly(own.map(\.entry), months: 6, endingAt: min(interval.end.addingTimeInterval(-1), .now), calendar: AppCalendar.calendar)

        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        CategoryIcon(symbol: category.symbol, colorHex: category.colorHex, size: 48)
                        VStack(alignment: .leading) {
                            Text(period.title()).font(.subheadline).foregroundStyle(.secondary)
                            MoneyText(amount: inPeriod.sum(\.amount), font: .title.bold())
                        }
                    }
                    Text("\(inPeriod.count) операций · в среднем \(Money.format(inPeriod.isEmpty ? 0 : (inPeriod.sum(\.amount) / Decimal(inPeriod.count)).rounded(0), currency: settings.currencyCode))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Динамика за 6 месяцев") {
                Chart(months) { month in
                    BarMark(x: .value("Месяц", month.month, unit: .month), y: .value("Расход", month.expense.chartValue))
                        .foregroundStyle(Color(hex: category.colorHex).gradient)
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            if month.expense > 0 {
                                Text(Money.compact(month.expense)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .chartYAxis(.hidden)
                .environment(\.locale, AppCalendar.locale)
                .environment(\.timeZone, AppCalendar.timeZone)
                .frame(height: 180)
                .padding(.vertical, 8)
            }
            Section("Операции") {
                if inPeriod.isEmpty {
                    Text("За период операций нет").foregroundStyle(.secondary)
                }
                ForEach(inPeriod) { TransactionRow(transaction: $0, showsDate: true) }
            }
        }
        .themedBackground()
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(category: CategoryInfo(id: UUID(), name: "Такси", symbol: "car.fill", colorHex: "#FFCC00"), period: ReportPeriod())
    }
    .modelContainer(DemoData.previewContainer)
    .environment(AppSettings.shared)
}
