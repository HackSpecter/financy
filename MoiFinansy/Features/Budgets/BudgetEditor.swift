import SwiftData
import SwiftUI

struct BudgetDraft: Identifiable {
    var id = UUID()
    var budget: Budget?
    var isTotal: Bool
    var limitText = ""
    var category: Category?

    init(budget: Budget) {
        self.budget = budget
        self.isTotal = budget.isTotal
        self.limitText = Money.formatNumber(budget.limit).replacingOccurrences(of: "\u{00A0}", with: "")
        self.category = budget.category
    }

    init(isTotal: Bool) {
        self.isTotal = isTotal
    }
}

struct BudgetEditor: View {
    @State var draft: BudgetDraft
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Category.order) private var categories: [Category]
    @Query private var budgets: [Budget]

    var body: some View {
        NavigationStack {
            Form {
                if !draft.isTotal {
                    Picker("Категория", selection: $draft.category) {
                        Text("Выберите").tag(Category?.none)
                        ForEach(availableCategories) { category in
                            Label(category.name, systemImage: category.symbol).tag(Optional(category))
                        }
                    }
                }
                HStack {
                    TextField("Лимит на месяц", text: $draft.limitText)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                        .fontDesign(.rounded)
                    Text(settings.currencyCode).foregroundStyle(.secondary)
                }
                Section {
                    Text("Уведомим, когда будет потрачено 80% и 100% лимита.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let budget = draft.budget {
                    Button("Удалить лимит", role: .destructive) {
                        context.delete(budget)
                        try? context.save()
                        WidgetRefresher.reload()
                        dismiss()
                    }
                }
            }
            .themedBackground()
            .navigationTitle(draft.isTotal ? "Общий бюджет" : "Лимит категории")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var availableCategories: [Category] {
        let used = Set(budgets.compactMap { $0.category?.id }).subtracting([draft.category?.id].compactMap { $0 })
        return categories.filter { $0.kind == .expense && !$0.archived && !used.contains($0.id) }
    }

    private var canSave: Bool {
        guard let limit = Money.parse(draft.limitText), limit > 0 else { return false }
        return draft.isTotal || draft.category != nil
    }

    private func save() {
        guard let limit = Money.parse(draft.limitText) else { return }
        if let budget = draft.budget {
            budget.limit = limit
            budget.category = draft.isTotal ? nil : draft.category
        } else {
            context.insert(Budget(limit: limit, category: draft.isTotal ? nil : draft.category))
        }
        try? context.save()
        WidgetRefresher.reload()
        Task { await NotificationService.requestAuthorization() }
        dismiss()
    }
}

#Preview {
    BudgetEditor(draft: BudgetDraft(isTotal: false))
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
