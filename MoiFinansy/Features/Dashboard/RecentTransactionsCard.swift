import SwiftData
import SwiftUI

struct RecentTransactionsCard: View {
    var transactions: [Transaction]
    var onShowAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Последние операции", symbol: "clock.fill") {
                Button("Все", action: onShowAll).font(.subheadline)
            }
            if transactions.isEmpty {
                Text("Нажмите «+», чтобы добавить первую операцию")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(transactions) { transaction in
                TransactionRow(transaction: transaction, showsDate: true)
                if transaction.id != transactions.last?.id { Divider().padding(.leading, 52) }
            }
        }
        .card()
    }
}

#Preview {
    let context = DemoData.previewContainer.mainContext
    let items = (try? context.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
    return RecentTransactionsCard(transactions: Array(items.prefix(5))) {}.cardPreview()
}
