import SwiftData
import SwiftUI

/// Шаблоны частых операций — один тап в быстром добавлении и в виджете.
struct TemplatesSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Template.order) private var templates: [Template]
    @State private var editing: Template?
    @State private var isAdding = false

    var body: some View {
        List {
            Section {
                ForEach(templates) { template in
                    Button { editing = template } label: {
                        HStack(spacing: 12) {
                            CategoryIcon(category: template.category, size: 34)
                            VStack(alignment: .leading) {
                                Text(template.title)
                                Text("использован \(template.useCount) раз").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            MoneyText(amount: template.amount, type: template.type)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onMove { from, to in
                    var reordered = templates
                    reordered.move(fromOffsets: from, toOffset: to)
                    for (index, template) in reordered.enumerated() { template.order = index }
                    try? context.save()
                    WidgetRefresher.reload()
                }
                .onDelete { offsets in
                    offsets.map { templates[$0] }.forEach(context.delete)
                    try? context.save()
                    WidgetRefresher.reload()
                }
            } footer: {
                Text("Первые три шаблона появляются кнопками в виджете.")
            }
        }
        .themedBackground()
        .navigationTitle("Шаблоны")
        .toolbar {
            EditButton()
            Button("Добавить", systemImage: "plus") { isAdding = true }
        }
        .sheet(item: $editing) { TemplateEditor(template: $0) }
        .sheet(isPresented: $isAdding) { TemplateEditor(template: nil) }
    }
}

struct TemplateEditor: View {
    var template: Template?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Account.order) private var accounts: [Account]
    @Query private var templates: [Template]

    @State private var title = ""
    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var category: Category?
    @State private var account: Account?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название, например «Обед»", text: $title)
                Picker("Тип", selection: $type) {
                    Text("Расход").tag(TransactionType.expense)
                    Text("Доход").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                HStack {
                    TextField("Сумма", text: $amountText).keyboardType(.decimalPad)
                    Text(settings.currencyCode).foregroundStyle(.secondary)
                }
                Picker("Категория", selection: $category) {
                    Text("Выберите").tag(Category?.none)
                    ForEach(categories.filter { $0.kind == (type == .income ? .income : .expense) && !$0.archived }) {
                        Label($0.name, systemImage: $0.symbol).tag(Optional($0))
                    }
                }
                Picker("Счёт", selection: $account) {
                    Text("Последний использованный").tag(Account?.none)
                    ForEach(accounts.filter { !$0.archived }) { Text($0.name).tag(Optional($0)) }
                }
            }
            .themedBackground()
            .navigationTitle(template == nil ? "Новый шаблон" : "Шаблон")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save)
                        .disabled(title.isEmpty || category == nil || Money.parse(amountText) == nil)
                }
            }
            .onAppear {
                guard let template else { return }
                title = template.title
                type = template.type
                amountText = Money.formatNumber(template.amount).replacingOccurrences(of: "\u{00A0}", with: "")
                category = template.category
                account = template.account
            }
            .onChange(of: category) { _, new in
                if title.isEmpty, let new { title = new.name }
            }
        }
    }

    private func save() {
        guard let amount = Money.parse(amountText), amount > 0 else { return }
        let target = template ?? Template(title: title, amount: amount, category: category, order: templates.count)
        target.title = title
        target.type = type
        target.amount = amount
        target.category = category
        target.account = account
        if template == nil { context.insert(target) }
        try? context.save()
        WidgetRefresher.reload()
        dismiss()
    }
}

#Preview {
    NavigationStack { TemplatesSettingsView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
