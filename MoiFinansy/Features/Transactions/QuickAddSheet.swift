import SwiftData
import SwiftUI

/// Шторка быстрого добавления: сумма → тап по категории = операция сохранена.
struct QuickAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Account.order) private var accounts: [Account]
    @Query(sort: \Template.order) private var templates: [Template]
    @Query(sort: \Transaction.date, order: .reverse) private var history: [Transaction]

    @State private var model: QuickAddModel
    @State private var savedCount = 0
    @State private var showsDetails = false
    @FocusState private var noteFocused: Bool

    init(type: TransactionType = .expense) {
        _model = State(initialValue: QuickAddModel(type: type))
    }

    var body: some View {
        VStack(spacing: 12) {
            typePicker
            amountDisplay
            detailsRow
            if model.type == .transfer {
                TransferAccountsView(model: model, accounts: activeAccounts)
            } else {
                SuggestionsRow(suggestions: suggestions, onSelect: save(suggestion:))
                CategoryGrid(
                    categories: visibleCategories,
                    highlightedID: model.suggestedCategoryID,
                    onSelect: save(category:)
                )
            }
            Spacer(minLength: 0)
            if !noteFocused {
                AmountKeypad { model.input.press($0) }
                if model.type == .transfer {
                    Button(action: saveTransfer) {
                        Text("Перевести").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.error, trigger: model.missingAmountAttempts)
        .onAppear { model.prepare(accounts: accounts) }
        .onChange(of: model.note) { model.updateSuggestion(categories: categories, history: history) }
        .onChange(of: model.type) { model.updateSuggestion(categories: categories, history: history) }
        .animation(.snappy, value: model.type)
        .animation(.snappy, value: noteFocused)
    }

    // MARK: Parts

    private var typePicker: some View {
        Picker("Тип операции", selection: $model.type) {
            ForEach(TransactionType.userCases) { type in
                Text(type.title).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(model.input.display)
                .displayFont(60)
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(model.input.text.isEmpty ? .tertiary : .primary)
            Text(settings.currencyCode)
                .font(.title2.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.2), value: model.input)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Сумма \(model.input.display) \(settings.currencyCode)")
        .keyframeAnimator(initialValue: CGFloat.zero, trigger: model.missingAmountAttempts) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(-12, duration: 0.08)
                SpringKeyframe(10, duration: 0.08)
                SpringKeyframe(-6, duration: 0.08)
                SpringKeyframe(0, duration: 0.1)
            }
        }
    }

    private var detailsRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if model.type != .transfer {
                    Menu {
                        ForEach(activeAccounts) { account in
                            Button {
                                model.account = account
                            } label: {
                                Label(account.name, systemImage: account.symbol)
                            }
                        }
                    } label: {
                        Label(model.account?.name ?? "Счёт", systemImage: model.account?.symbol ?? "wallet.bifold")
                            .font(.subheadline)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(.glass)
                }
                Spacer(minLength: 0)
                DatePicker("Дата", selection: $model.date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            TextField("Заметка — категория подскажется сама", text: $model.note)
                .focused($noteFocused)
                .submitLabel(.done)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: .capsule)
        }
    }

    // MARK: Data

    private var activeAccounts: [Account] { accounts.filter { !$0.archived } }

    private var visibleCategories: [Category] {
        let kind: CategoryKind = model.type == .income ? .income : .expense
        return categories.filter { $0.kind == kind && !$0.archived }
    }

    private var suggestions: [QuickSuggestion] {
        QuickSuggestion.build(templates: templates, transactions: history, type: model.type)
    }

    // MARK: Actions

    private func save(category: Category) {
        guard let transaction = model.save(category: category, in: context) else { return }
        finish(with: transaction)
    }

    private func saveTransfer() {
        guard let transaction = model.save(category: nil, in: context) else { return }
        finish(with: transaction)
    }

    private func save(suggestion: QuickSuggestion) {
        let transaction: Transaction
        switch suggestion.source {
        case .template(let id):
            guard let template = templates.first(where: { $0.persistentModelID == id }) else { return }
            transaction = TransactionService.add(template: template, in: context)
        case .recent:
            transaction = TransactionService.add(
                type: model.type,
                amount: suggestion.amount,
                category: suggestion.category,
                account: model.account,
                date: model.date,
                note: model.note,
                in: context
            )
        }
        finish(with: transaction)
    }

    private func finish(with transaction: Transaction) {
        savedCount += 1
        let sign = transaction.type == .income ? "+" : transaction.type == .expense ? "−" : ""
        let message = "\(transaction.displayTitle) · \(sign)\(Money.format(transaction.amount, currency: settings.currencyCode))"
        let context = context
        toasts.show(message) {
            TransactionService.delete(transaction, in: context)
        }
        dismiss()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        QuickAddSheet()
    }
    .modelContainer(DemoData.previewContainer)
    .environment(AppSettings.shared)
    .environment(ToastCenter.shared)
}
