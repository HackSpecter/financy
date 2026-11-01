import SwiftData
import SwiftUI

/// Вкладка поиска: операции и планы по заметке, категории, сумме.
struct SearchView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \PlannerItem.date, order: .reverse) private var plannerItems: [PlannerItem]
    @State private var query = ""
    @State private var editing: Transaction?

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    EmptyStateView(
                        title: "Поиск",
                        symbol: "magnifyingglass",
                        message: "Ищите операции по заметке, категории или сумме, а также задачи из Планов."
                    )
                } else if foundTransactions.isEmpty, foundItems.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List {
                        if !foundTransactions.isEmpty {
                            Section("Операции · \(foundTransactions.count) · \(Money.format(foundTransactions.filter { $0.type == .expense }.sum(\.amount)))") {
                                ForEach(foundTransactions.prefix(100)) { transaction in
                                    Button { editing = transaction } label: {
                                        TransactionRow(transaction: transaction, showsDate: true)
                                    }
                                    .buttonStyle(.plain)
                                    .glassRow()
                                }
                            }
                        }
                        if !foundItems.isEmpty {
                            Section("Планы") {
                                ForEach(foundItems.prefix(50)) { item in
                                    HStack {
                                        Image(systemName: item.isDone ? "checkmark.circle.fill" : item.type.symbol)
                                            .foregroundStyle(item.isDone ? Theme.positive : .secondary)
                                        Text(item.title).strikethrough(item.isDone)
                                        Spacer()
                                        Text(item.date.dayTitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .themedBackground()
            .navigationTitle("Поиск")
            .searchable(text: $query, prompt: "Такси, 45, обед…")
            .sheet(item: $editing) { TransactionEditView(transaction: $0) }
        }
    }

    private var foundTransactions: [Transaction] {
        transactions.filter { TransactionFilter.matches($0, query: query) }
    }

    private var foundItems: [PlannerItem] {
        plannerItems.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.note.localizedCaseInsensitiveContains(query) }
    }
}

#Preview {
    SearchView()
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
