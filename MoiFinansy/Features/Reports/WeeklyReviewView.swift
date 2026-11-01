import SwiftData
import SwiftUI

/// Итоги недели: траты против прошлой недели, дни в пределах лимита, серия.
struct WeeklyReviewView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var rules: [RecurringRule]
    @Query(sort: \Category.order) private var categories: [Category]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let days = MotivationService.dailyResults(transactions: transactions, budgets: budgets, rules: rules, days: 14)
        let review = WeeklyReviewCalculator.review(entries: transactions.map(\.entry), days: days, now: .now, calendar: AppCalendar.calendar)
        let streak = MotivationService.streak(transactions: transactions, budgets: budgets, rules: rules)
        let info = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.info) })
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(review.week.start.appFormatted("dMMM")) – \(review.week.end.addingTimeInterval(-1).appFormatted("dMMM"))")
                        .font(.subheadline).foregroundStyle(.secondary)
                    MoneyText(amount: review.spent, font: .largeTitle.bold())
                    if let change = review.change {
                        Label("\(change > 0 ? "+" : "")\(Money.percent(change)) к прошлой неделе (\(Money.format(review.previousSpent, currency: settings.currencyCode)))",
                              systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(change > 0 ? Theme.caution : Theme.positive)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Лимит") {
                HStack(spacing: 6) {
                    ForEach(days.filter { review.week.contains($0.date) }, id: \.date) { day in
                        VStack(spacing: 4) {
                            Image(systemName: day.isWithin ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(day.isWithin ? Theme.positive : Theme.negative)
                                .font(.title3)
                            Text(day.date.appFormatted("EEEEEE").capitalizedFirst).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                LabeledContent("Дней в пределах лимита", value: "\(review.daysWithinLimit) из \(review.daysCounted)")
                LabeledContent("Серия", value: "\(streak.current) дн. · рекорд \(streak.best)")
            }
            if !review.topCategories.isEmpty {
                Section("Куда ушли деньги") {
                    ForEach(review.topCategories) { item in
                        let category = item.categoryID.flatMap { info[$0] }
                        HStack {
                            CategoryIcon(symbol: category?.symbol ?? "questionmark", colorHex: category?.colorHex ?? "#8E8E93", size: 30)
                            Text(category?.name ?? "Без категории")
                            Spacer()
                            Text(Money.format(item.amount, currency: settings.currencyCode)).monospacedDigit()
                        }
                    }
                }
            }
            if let biggest = review.biggest {
                Section("Самая крупная трата") {
                    HStack {
                        Text(biggest.note.isEmpty ? (biggest.categoryID.flatMap { info[$0]?.name } ?? "Трата") : biggest.note)
                        Spacer()
                        Text(Money.format(biggest.amount, currency: settings.currencyCode)).monospacedDigit()
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle("Недельный разбор")
    }
}

#Preview {
    NavigationStack { WeeklyReviewView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
