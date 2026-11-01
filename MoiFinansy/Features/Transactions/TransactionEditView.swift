import SwiftData
import SwiftUI

/// Полное редактирование операции.
struct TransactionEditView: View {
    @Bindable var transaction: Transaction
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Account.order) private var accounts: [Account]

    @State private var amountText = ""
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Тип", selection: $transaction.type) {
                        ForEach(TransactionType.userCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        TextField("Сумма", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold))
                            .fontDesign(.rounded)
                        Text(settings.currencyCode).foregroundStyle(.secondary)
                    }
                }
                Section {
                    if transaction.type != .transfer {
                        Picker("Категория", selection: $transaction.category) {
                            Text("Без категории").tag(Category?.none)
                            ForEach(categories.filter { $0.kind == (transaction.type == .income ? .income : .expense) && !$0.archived }) { category in
                                Label(category.name, systemImage: category.symbol).tag(Optional(category))
                            }
                        }
                    }
                    Picker(transaction.type == .transfer ? "Откуда" : "Счёт", selection: $transaction.account) {
                        ForEach(accounts) { Text($0.name).tag(Optional($0)) }
                    }
                    if transaction.type == .transfer {
                        Picker("Куда", selection: $transaction.toAccount) {
                            ForEach(accounts) { Text($0.name).tag(Optional($0)) }
                        }
                    }
                    if transaction.type == .transfer, let from = transaction.account, let to = transaction.toAccount, from.currencyCode != to.currencyCode {
                        LabeledContent("Зачислено, \(to.currencyCode)") {
                            TextField("сумма", text: toAmountBinding).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    }
                    DatePicker("Дата", selection: $transaction.date)
                    TextField("Заметка", text: $transaction.note, axis: .vertical)
                    TextField("Теги: работа, поездка", text: tagsBinding)
                        .textInputAutocapitalization(.never)
                }
                if !transaction.merchant.isEmpty || transaction.source != .manual {
                    Section {
                        if !transaction.merchant.isEmpty { LabeledContent("Магазин", value: transaction.merchant) }
                        LabeledContent("Источник", value: transaction.source.title + (transaction.cardLast4.isEmpty ? "" : " · •\(transaction.cardLast4)"))
                    }
                }
                if transaction.type == .expense, transaction.account?.isSavings != true {
                    Section {
                        Button("Это перевод в Копилку", systemImage: "building.columns.fill") {
                            TransactionService.convertToSavings(transaction, in: context)
                            dismiss()
                        }
                    } footer: {
                        Text("Если деньги не потрачены, а отправлены на депозит или в копилку: операция станет переводом в Копилку и пропадёт из расходов.")
                    }
                }
                AttachmentsSection(transaction: transaction)
                Section {
                    Button("Удалить операцию", role: .destructive) { confirmsDelete = true }
                }
            }
            .themedBackground()
            .navigationTitle("Операция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save)
                        .disabled(Money.parse(amountText) == nil)
                }
            }
            .confirmationDialog("Удалить операцию?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    TransactionService.delete(transaction, in: context)
                    dismiss()
                }
            }
            .onAppear {
                amountText = Money.formatNumber(transaction.amount).replacingOccurrences(of: "\u{00A0}", with: "")
            }
        }
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: { transaction.tags.joined(separator: ", ") },
            set: { transaction.tags = $0.replacingOccurrences(of: "#", with: "").split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init) }
        )
    }

    private var toAmountBinding: Binding<String> {
        Binding(
            get: { transaction.toAmount.map { Money.formatNumber($0).replacingOccurrences(of: "\u{00A0}", with: "") } ?? "" },
            set: { transaction.toAmount = Money.parse($0) }
        )
    }

    private func save() {
        if let amount = Money.parse(amountText), amount > 0 {
            transaction.amount = amount
        }
        if transaction.type == .transfer {
            transaction.category = nil
            transaction.needsReview = false
        } else {
            transaction.toAccount = nil
        }
        if transaction.type == .transfer {
            // Стал переводом: SMS-зачисление на счёт назначения с той же суммой — это тот же перевод.
            try? context.save()
            TransferMatcher.absorbSMSOperations(into: transaction, in: context)
            TransactionService.didChange(in: context, category: nil)
        } else if let category = transaction.category, transaction.needsReview || !transaction.merchant.isEmpty {
            InboxService.categorize(transaction, as: category, in: context)
        } else {
            try? context.save()
            TransactionService.didChange(in: context, category: transaction.category)
        }
        dismiss()
    }
}

#Preview {
    let container = DemoData.previewContainer
    let transaction = try! container.mainContext.fetch(FetchDescriptor<Transaction>()).first!
    return TransactionEditView(transaction: transaction)
        .modelContainer(container)
        .environment(AppSettings.shared)
}
