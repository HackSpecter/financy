import SwiftData
import SwiftUI

/// Сумма долгов на Главной.
struct DebtsCard: View {
    @Query(filter: #Predicate<Debt> { !$0.isClosed }) private var debts: [Debt]

    var body: some View {
        let totals = DebtCalculator.totals(debts.map(\.snapshot)) { CurrencyService.toBase($0, from: $1) }
        let overdue = DebtCalculator.overdue(debts.map(\.snapshot), now: .now, calendar: AppCalendar.calendar).count
        NavigationLink { DebtsView() } label: {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(title: "Долги", symbol: "person.2.fill", tint: .purple) {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                if debts.isEmpty {
                    Text("Записывайте, кто кому должен — напомним о сроке").font(.footnote).foregroundStyle(.secondary)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Мне должны").font(.caption).foregroundStyle(Theme.positive)
                            MoneyText(amount: totals.owedToMe, font: .headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Я должен").font(.caption).foregroundStyle(Theme.negative)
                            MoneyText(amount: totals.iOwe, font: .headline)
                        }
                    }
                    if overdue > 0 {
                        Label("Просрочено: \(overdue)", systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(Theme.negative)
                    }
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
