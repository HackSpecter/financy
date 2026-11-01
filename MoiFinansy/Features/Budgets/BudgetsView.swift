import SwiftData
import SwiftUI

/// Общий месячный лимит и лимиты по категориям.
struct BudgetsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query private var budgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var editing: BudgetDraft?

    var body: some View {
        let month = AppCalendar.calendar.monthInterval(for: .now)
        let expenses = transactions.filter { $0.type == .expense && month.contains($0.date) }
        let total = budgets.first(where: \.isTotal)
        let categoryBudgets = budgets.filter { !$0.isTotal }.sorted { ($0.category?.order ?? 0) < ($1.category?.order ?? 0) }

        List {
            Section {
                if let total {
                    Button { editing = BudgetDraft(budget: total) } label: {
                        BudgetRow(title: "Общий бюджет", symbol: "sum", colorHex: "#34C759", spent: expenses.sum(\.amount), limit: total.limit)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button("Задать общий лимит на месяц", systemImage: "plus.circle.fill") {
                        editing = BudgetDraft(isTotal: true)
                    }
                }
            } header: {
                Text("Месяц")
            } footer: {
                Text("От общего лимита считается «Можно потратить сегодня». Без лимита используется доход месяца.")
            }

            Section("По категориям") {
                ForEach(categoryBudgets) { budget in
                    Button { editing = BudgetDraft(budget: budget) } label: {
                        BudgetRow(
                            title: budget.category?.name ?? "",
                            symbol: budget.category?.symbol ?? "circle",
                            colorHex: budget.category?.colorHex ?? "#8E8E93",
                            spent: expenses.filter { $0.category?.id == budget.category?.id }.sum(\.amount),
                            limit: budget.limit
                        )
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    offsets.map { categoryBudgets[$0] }.forEach(context.delete)
                    try? context.save()
                }
                Button("Добавить лимит категории", systemImage: "plus") {
                    editing = BudgetDraft(isTotal: false)
                }
            }
        }
        .themedBackground()
        .navigationTitle("Бюджеты")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть", systemImage: "xmark") { dismiss() }
            }
        }
        .sheet(item: $editing) { draft in
            BudgetEditor(draft: draft)
        }
    }
}

struct BudgetRow: View {
    var title: String
    var symbol: String
    var colorHex: String
    var spent: Decimal
    var limit: Decimal
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let ratio = limit > 0 ? (spent / limit).chartValue : 0
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CategoryIcon(symbol: symbol, colorHex: colorHex, size: 32)
                Text(title).font(.body.weight(.medium))
                Spacer()
                Text(Money.percent(limit > 0 ? spent / limit : 0))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color(ratio))
            }
            ProgressBar(value: ratio, tint: color(ratio), height: 8)
            HStack {
                Text("\(Money.format(spent, currency: settings.currencyCode)) из \(Money.format(limit, currency: settings.currencyCode))")
                Spacer()
                let left = limit - spent
                Text(left >= 0 ? "осталось \(Money.format(left, currency: settings.currencyCode))" : "перерасход \(Money.format(-left, currency: settings.currencyCode))")
                    .foregroundStyle(left >= 0 ? Color.secondary : Theme.negative)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func color(_ ratio: Double) -> Color {
        ratio >= 1 ? Theme.negative : ratio >= 0.8 ? Theme.caution : Theme.positive
    }
}

#Preview {
    NavigationStack { BudgetsView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
