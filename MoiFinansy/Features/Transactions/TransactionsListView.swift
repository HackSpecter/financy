import SwiftData
import SwiftUI

/// Вкладка «Операции»: список по дням с итогами, фильтры, поиск, свайпы.
struct TransactionsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(filter: #Predicate<Transaction> { $0.needsReview }) private var inbox: [Transaction]

    @State private var filter = TransactionFilter()
    @State private var query = ""
    @State private var showsFilters = false
    @State private var editing: Transaction?
    @State private var showsReceipt = false
    @State private var showsStatement = false

    var body: some View {
        NavigationStack {
            content
                .themedBackground()
                .navigationTitle("Операции")
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Заметка или сумма")
                .toolbar {
                    if !inbox.isEmpty {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                router.isInboxPresented = true
                            } label: {
                                Label("Входящие: \(inbox.count)", systemImage: "tray.full.fill")
                                    .labelStyle(.titleAndIcon)
                            }
                            .tint(Theme.accent)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Сканировать чек", systemImage: "doc.text.viewfinder") { showsReceipt = true }
                            Button("Импорт выписки", systemImage: "tablecells") { showsStatement = true }
                            Button("Входящие", systemImage: "tray.full") { router.isInboxPresented = true }
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .accessibilityLabel("Импорт")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsFilters = true
                        } label: {
                            Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                        }
                        .accessibilityLabel("Фильтры")
                    }
                }
                .sheet(isPresented: $showsFilters) {
                    TransactionFilterSheet(filter: $filter)
                }
                .sheet(isPresented: $showsReceipt) { ReceiptScannerView() }
                .sheet(isPresented: $showsStatement) { StatementImportView() }
                .sheet(item: $editing) { transaction in
                    TransactionEditView(transaction: transaction)
                }
                .floatingAddButton { router.openQuickAdd() }
        }
    }

    @ViewBuilder
    private var content: some View {
        let filtered = filter.apply(to: transactions, query: query)
        if transactions.isEmpty {
            EmptyStateView(
                title: "Пока нет операций",
                symbol: "tray",
                message: "Добавьте первый расход — это 2 тапа: сумма и категория.",
                actionTitle: "Добавить расход"
            ) { router.openQuickAdd() }
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                if filter.isActive || !query.isEmpty {
                    FilterSummaryRow(transactions: filtered)
                        .glassRow()
                }
                ForEach(TransactionDay.group(filtered)) { day in
                    Section {
                        ForEach(day.transactions) { transaction in
                            Button {
                                editing = transaction
                            } label: {
                                TransactionRow(transaction: transaction)
                            }
                            .buttonStyle(.plain)
                            .glassRow()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(transaction)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                                Button {
                                    editing = transaction
                                } label: {
                                    Label("Изменить", systemImage: "pencil")
                                }
                                .tint(Theme.accent)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    duplicate(transaction)
                                } label: {
                                    Label("Повторить", systemImage: "plus.square.on.square")
                                }
                                .tint(Theme.positive)
                                if transaction.type == .expense {
                                    Button {
                                        TransactionService.convertToSavings(transaction, in: context)
                                        toasts.show("Перевод в Копилку: \(Money.format(transaction.amount, currency: transaction.currencyCode))")
                                    } label: {
                                        Label("В копилку", systemImage: "building.columns.fill")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    } header: {
                        DayHeader(day: day)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.bottom, 80, for: .scrollContent)
        }
    }

    private func delete(_ transaction: Transaction) {
        let snapshot = (transaction.type, transaction.amount, transaction.category, transaction.account, transaction.toAccount, transaction.date, transaction.note)
        let title = transaction.displayTitle
        TransactionService.delete(transaction, in: context)
        let context = context
        toasts.show("Удалено: \(title)") {
            TransactionService.add(type: snapshot.0, amount: snapshot.1, category: snapshot.2, account: snapshot.3, toAccount: snapshot.4, date: snapshot.5, note: snapshot.6, in: context)
        }
    }

    private func duplicate(_ transaction: Transaction) {
        let copy = TransactionService.duplicate(transaction, in: context)
        let context = context
        toasts.show("Повторено: \(copy.displayTitle)") {
            TransactionService.delete(copy, in: context)
        }
    }
}

private struct DayHeader: View {
    var day: TransactionDay
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack {
            Text(day.date.dayTitle)
            Spacer()
            if day.income > 0 {
                Text("+" + Money.format(day.income, currency: settings.currencyCode))
                    .foregroundStyle(Theme.positive)
            }
            if day.expense > 0 {
                Text("−" + Money.format(day.expense, currency: settings.currencyCode))
            }
        }
        .font(.footnote.weight(.semibold))
        .monospacedDigit()
    }
}

private struct FilterSummaryRow: View {
    var transactions: [Transaction]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let expense = transactions.filter { $0.type == .expense }.sum(\.amount)
        let income = transactions.filter { $0.type == .income }.sum(\.amount)
        HStack {
            VStack(alignment: .leading) {
                Text("Найдено: \(transactions.count)").font(.subheadline.weight(.semibold))
                Text("Расход \(Money.format(expense, currency: settings.currencyCode))").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if income > 0 {
                Text("+" + Money.format(income, currency: settings.currencyCode)).foregroundStyle(Theme.positive).font(.subheadline)
            }
        }
    }
}

#Preview {
    TransactionsListView()
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
        .environment(AppRouter.shared)
        .environment(ToastCenter.shared)
}
