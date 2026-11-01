import SwiftData
import SwiftUI

/// Копилка и ближайшая цель на Главной.
struct SavingsCard: View {
    @Query(sort: \Account.order) private var accounts: [Account]
    @Query(filter: #Predicate<SavingsGoal> { !$0.isArchived }, sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationLink { SavingsView() } label: {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(title: "Накопления", symbol: "building.columns.fill", tint: Theme.caution) {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                MoneyText(amount: accounts.filter { $0.isSavings && !$0.archived }.sum(\.balanceInBase), font: .title3.bold())
                if let goal = goals.first(where: { !$0.progress.isReached }) ?? goals.first {
                    let progress = goal.progress
                    HStack {
                        Label(goal.name, systemImage: goal.symbol).font(.subheadline)
                        Spacer()
                        Text("\(Int(progress.fraction * 100))%").font(.subheadline.weight(.semibold))
                    }
                    ProgressBar(value: progress.fraction, tint: Color(hex: goal.colorHex), height: 6)
                } else {
                    Text("Добавьте цель и откладывайте процент с зарплаты").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
