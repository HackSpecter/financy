import SwiftUI

/// Прогресс месяца: потрачено X из Y, прошло N дней из M.
struct MonthProgressCard: View {
    var result: BudgetCalculator.Result
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Месяц", symbol: "calendar")
            HStack(alignment: .firstTextBaseline) {
                MoneyText(amount: result.spentMonth, font: .title3.bold())
                Text("из \(Money.format(result.monthBudget, currency: settings.currencyCode))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressBar(value: result.monthProgress, tint: tint, marker: result.timeProgress)
            HStack {
                Text("Прошло \(result.dayOfMonth) из \(result.daysInMonth) дней")
                Spacer()
                if result.mandatoryAhead > 0 {
                    Text("Впереди обязательных: \(Money.format(result.mandatoryAhead, currency: settings.currencyCode))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .card()
    }

    /// Траты опережают время — жёлтый/красный.
    private var tint: Color {
        if result.monthProgress >= 1 { return Theme.negative }
        if result.monthProgress > result.timeProgress + 0.1 { return Theme.caution }
        return Theme.positive
    }
}

#Preview {
    let result = BudgetCalculator.calculate(monthBudget: 25_000, entries: [MoneyEntry(amount: 14_000, date: .now, type: .expense)], upcoming: [], now: .now, calendar: AppCalendar.calendar)
    return MonthProgressCard(result: result).cardPreview()
}
