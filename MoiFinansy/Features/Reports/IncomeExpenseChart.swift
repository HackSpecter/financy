import Charts
import SwiftUI

/// Доходы vs расходы по месяцам.
struct IncomeExpenseChart: View {
    var months: [ReportCalculator.MonthTotal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Доходы и расходы по месяцам", symbol: "chart.bar.xaxis", tint: Theme.positive)
            Chart {
                ForEach(months) { month in
                    BarMark(x: .value("Месяц", month.month, unit: .month), y: .value("Сумма", month.income.chartValue))
                        .foregroundStyle(by: .value("Тип", "Доходы"))
                        .position(by: .value("Тип", "Доходы"))
                        .cornerRadius(3)
                    BarMark(x: .value("Месяц", month.month, unit: .month), y: .value("Сумма", month.expense.chartValue))
                        .foregroundStyle(by: .value("Тип", "Расходы"))
                        .position(by: .value("Тип", "Расходы"))
                        .cornerRadius(3)
                }
            }
            .chartForegroundStyleScale(["Доходы": Theme.positive, "Расходы": Theme.negative])
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text(Money.compact(Decimal(amount))) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .environment(\.locale, AppCalendar.locale)
            .environment(\.timeZone, AppCalendar.timeZone)
            .frame(height: 200)

            let savings = months.sum(\.savings)
            let income = months.sum(\.income)
            if income > 0 {
                Text("Сбережения за \(months.count) мес.: \(Money.format(savings)) · \(Money.percent(savings / income)) дохода")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

#Preview {
    IncomeExpenseChart(months: ReportData.preview.monthly).cardPreview()
}
