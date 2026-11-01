import Charts
import SwiftUI

/// Столбцы расходов по дням с линией дневного лимита.
struct DailySpendingChart: View {
    var days: [ReportCalculator.DayTotal]
    var dailyLimit: Decimal?
    @State private var selectedDate: Date?
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Расходы по дням", symbol: "chart.bar.fill", tint: .blue) {
                if let selected {
                    Text("\(selected.date.appFormatted("dMMM")): \(Money.format(selected.amount, currency: settings.currencyCode))")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("День", day.date, unit: .day),
                        y: .value("Расход", day.amount.chartValue)
                    )
                    .foregroundStyle(color(for: day).gradient)
                    .cornerRadius(3)
                    .opacity(selectedDate == nil || isSelected(day) ? 1 : 0.4)
                }
                if let dailyLimit, dailyLimit > 0 {
                    RuleMark(y: .value("Лимит", dailyLimit.chartValue))
                        .foregroundStyle(Theme.caution)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Лимит \(Money.compact(dailyLimit))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.caution)
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(Money.compact(Decimal(amount)))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: days.count > 10 ? 7 : 1)) {
                    AxisValueLabel(format: .dateTime.day(), centered: true)
                }
            }
            .environment(\.locale, AppCalendar.locale)
            .environment(\.timeZone, AppCalendar.timeZone)
            .frame(height: 200)
        }
        .card()
    }

    private var selected: ReportCalculator.DayTotal? {
        guard let selectedDate else { return nil }
        return days.first { isSelected($0, date: selectedDate) }
    }

    private func isSelected(_ day: ReportCalculator.DayTotal, date: Date? = nil) -> Bool {
        guard let date = date ?? selectedDate else { return false }
        return AppCalendar.calendar.isDate(day.date, inSameDayAs: date)
    }

    private func color(for day: ReportCalculator.DayTotal) -> Color {
        guard let dailyLimit, dailyLimit > 0 else { return .blue }
        return day.amount > dailyLimit ? Theme.negative : .blue
    }
}

#Preview {
    let data = ReportData.preview
    return DailySpendingChart(days: data.daily, dailyLimit: data.dailyLimit).cardPreview()
}
