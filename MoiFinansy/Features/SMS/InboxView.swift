import SwiftData
import SwiftUI

/// «Входящие»: импортированные операции без категории. Разбор — одним тапом.
struct InboxView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Transaction> { $0.needsReview }, sort: \Transaction.date, order: .reverse)
    private var items: [Transaction]
    @Query(filter: #Predicate<SMSImportLog> { $0.balanceDifference != nil }, sort: \SMSImportLog.receivedAt, order: .reverse)
    private var mismatches: [SMSImportLog]
    @State private var selected: Transaction?
    @State private var doneCount = 0

    var body: some View {
        NavigationStack {
            List {
                if let mismatch = mismatches.first(where: \.hasBalanceMismatch) {
                    Section {
                        NavigationLink {
                            ImportLogDetailView(log: mismatch)
                        } label: {
                            Label("Остаток по карте •\(mismatch.cardLast4) не совпадает с банком", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.caution)
                        }
                    }
                }
                if items.isEmpty {
                    EmptyStateView(title: "Всё разобрано", symbol: "tray", message: "Операции из SMS без категории будут появляться здесь.")
                        .listRowBackground(Color.clear)
                }
                ForEach(items) { item in
                    Button { selected = item } label: {
                        TransactionRow(transaction: item, showsDate: true)
                    }
                    .buttonStyle(.plain)
                    .glassRow()
                    .swipeActions {
                        Button(role: .destructive) {
                            TransactionService.delete(item, in: context)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .themedBackground()
            .navigationTitle("Входящие")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", systemImage: "checkmark") { dismiss() }
                }
            }
            .sheet(item: $selected) { item in
                InboxCategorizeSheet(transaction: item) { doneCount += 1 }
            }
            .sensoryFeedback(.success, trigger: doneCount)
        }
    }
}

/// Сетка категорий для разбора одной операции.
struct InboxCategorizeSheet: View {
    var transaction: Transaction
    var onDone: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var remembers = true

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                MoneyText(amount: transaction.amount, type: transaction.type, font: .largeTitle.bold())
                Text([transaction.merchant, transaction.cardLast4.isEmpty ? "" : "Карта •\(transaction.cardLast4)", transaction.date.appFormatted("dMMMHHmm")]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            CategoryGrid(categories: categories.filter { $0.kind == (transaction.type == .income ? .income : .expense) && !$0.archived }, highlightedID: nil) { category in
                if remembers || transaction.merchant.isEmpty {
                    InboxService.categorize(transaction, as: category, in: context)
                } else {
                    let merchant = transaction.merchant
                    transaction.merchant = ""
                    InboxService.categorize(transaction, as: category, in: context)
                    transaction.merchant = merchant
                }
                onDone()
                dismiss()
            }
            if !transaction.merchant.isEmpty {
                Toggle("Запомнить для «\(transaction.merchant)»", isOn: $remembers)
                    .font(.subheadline)
            }
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    InboxView()
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
