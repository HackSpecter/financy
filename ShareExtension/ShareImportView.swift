import SwiftData
import SwiftUI

/// Экран расширения: что распознано → записать → (если нужно) выбрать категорию.
struct ShareImportView: View {
    var model: ShareImportModel
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var saved: Transaction?
    @State private var message = ""
    @State private var manualAmount = ""
    @State private var manualType: TransactionType = .expense
    @State private var finished = 0

    var body: some View {
        NavigationStack {
            Form {
                switch model.state {
                case .loading:
                    Section { ProgressView("Распознаю…").frame(maxWidth: .infinity) }
                case .failed(let reason):
                    Section { Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                case .ready(let text):
                    content(for: text)
                }
            }
            .navigationTitle("Добавить в Khalid Finance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть", systemImage: "xmark", action: onClose) }
            }
            .task { await model.load() }
            .sensoryFeedback(.success, trigger: finished)
        }
    }

    @ViewBuilder
    private func content(for text: String) -> some View {
        let outcome = SMSImportService.preview(text, in: context)
        if let image = model.image {
            Section {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).frame(maxWidth: .infinity)
            }
        }
        if let saved {
            Section {
                Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }
            if saved.needsReview {
                Section("Категория") {
                    categoryGrid(kind: saved.type == .income ? .income : .expense) { category in
                        InboxService.categorize(saved, as: category, in: context)
                        close()
                    }
                }
            } else {
                Section { Button("Готово", action: close) }
            }
        } else if outcome.parsed != nil {
            Section("Распознано") { ParseOutcomeView(text: text, outcome: outcome) }
            Section {
                Button("Записать операцию", systemImage: "square.and.arrow.down.fill") {
                    let result = SMSImportService.process(text: text, source: .share, in: context)
                    message = result.message
                    if let transaction = result.transaction {
                        saved = transaction
                        if !transaction.needsReview { finished += 1 }
                    }
                }
            }
        } else {
            Section("Текст") { Text(text).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(8) }
            Section {
                Picker("Тип", selection: $manualType) {
                    Text("Расход").tag(TransactionType.expense)
                    Text("Доход").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                HStack {
                    TextField("Сумма", text: $manualAmount).keyboardType(.decimalPad).font(.title2.weight(.semibold))
                    Text(settings.currencyCode).foregroundStyle(.secondary)
                }
            } header: {
                Text("Не удалось разобрать автоматически")
            }
            .onAppear {
                if manualAmount.isEmpty, let total = ReceiptParser.parse(text).total {
                    manualAmount = Money.formatNumber(total).replacingOccurrences(of: "\u{00A0}", with: "")
                }
            }
            if let amount = Money.parse(manualAmount), amount > 0 {
                Section("Категория — тап сохраняет") {
                    categoryGrid(kind: manualType == .income ? .income : .expense) { category in
                        let transaction = TransactionService.add(
                            type: manualType,
                            amount: amount,
                            category: category,
                            account: TransactionService.lastAccount(in: context),
                            note: String(text.prefix(80)),
                            in: context
                        )
                        transaction.source = .share
                        try? context.save()
                        close()
                    }
                }
            }
        }
    }

    private func categoryGrid(kind: CategoryKind, onSelect: @escaping (Category) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            ForEach(categories.filter { $0.kind == kind && !$0.archived }) { category in
                Button { onSelect(category) } label: {
                    VStack(spacing: 4) {
                        CategoryIcon(category: category, size: 40)
                        Text(category.name).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func close() {
        finished += 1
        WidgetRefresher.reload()
        onClose()
    }
}
