import SwiftData
import SwiftUI

struct TopCategoriesCard: View {
    var transactions: [Transaction]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let expenses = transactions.filter { $0.type == .expense }
        let total = expenses.sum(\.amount)
        let top = Dictionary(grouping: expenses) { $0.category }
            .map { (category: $0.key, amount: $0.value.sum(\.amount)) }
            .sorted { $0.amount > $1.amount }
            .prefix(3)

        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Топ категорий месяца", symbol: "crown.fill", tint: Theme.caution)
            if top.isEmpty {
                Text("Расходов в этом месяце ещё нет").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(Array(top), id: \.category?.id) { item in
                HStack(spacing: 12) {
                    CategoryIcon(category: item.category, size: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.category?.name ?? "Без категории").font(.subheadline.weight(.medium))
                            Spacer()
                            Text(Money.format(item.amount, currency: settings.currencyCode))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        ProgressBar(
                            value: total > 0 ? (item.amount / total).chartValue : 0,
                            tint: Color(hex: item.category?.colorHex ?? "#8E8E93"),
                            height: 6
                        )
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}

#Preview {
    let context = DemoData.previewContainer.mainContext
    return TopCategoriesCard(transactions: (try? context.fetch(FetchDescriptor<Transaction>())) ?? []).cardPreview()
}
