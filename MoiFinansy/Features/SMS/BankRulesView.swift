import SwiftData
import SwiftUI

/// Правила разбора SMS по банкам — редактируются без обновления приложения.
struct BankRulesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BankSMSRule.order) private var rules: [BankSMSRule]
    @State private var editing: BankSMSRule?

    var body: some View {
        List {
            Section {
                ForEach(rules) { rule in
                    Button { editing = rule } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name).font(.body.weight(.medium))
                                Text(customizedSummary(rule)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !rule.isEnabled { Text("выкл.").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onMove { from, to in
                    var reordered = rules
                    reordered.move(fromOffsets: from, toOffset: to)
                    for (index, rule) in reordered.enumerated() { rule.order = index }
                    try? context.save()
                }
                .onDelete { offsets in
                    offsets.map { rules[$0] }.forEach(context.delete)
                    try? context.save()
                }
            } footer: {
                Text("Правило выбирается по словам отправителя или названию банка в тексте. Если ни одно не подошло, работает универсальное — оно понимает большинство SMS, включая формат «Списание со счета / Карта 4*4242 / Сумма / Остаток».")
            }
        }
        .themedBackground()
        .navigationTitle("Правила банков")
        .toolbar {
            EditButton()
            Button("Добавить", systemImage: "plus") {
                let rule = BankSMSRule(name: "Новый банк", senderKeywords: "", order: rules.count)
                context.insert(rule)
                editing = rule
            }
        }
        .sheet(item: $editing) { BankRuleEditor(rule: $0) }
    }

    private func customizedSummary(_ rule: BankSMSRule) -> String {
        let custom = [rule.amountPattern, rule.balancePattern, rule.cardPattern, rule.merchantPattern, rule.datePattern].filter { !$0.isEmpty }.count
        let words = rule.senderKeywords.isEmpty ? "без слов отправителя" : rule.senderKeywords
        return custom == 0 ? "\(words) · универсальные шаблоны" : "\(words) · своих шаблонов: \(custom)"
    }
}

struct BankRuleEditor: View {
    @Bindable var rule: BankSMSRule
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var sample = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $rule.name)
                    TextField("Слова отправителя / банка", text: $rule.senderKeywords)
                    Toggle("Включено", isOn: $rule.isEnabled)
                } footer: {
                    Text("Через запятую, например: alif, алиф")
                }
                Section {
                    patternField("Сумма", $rule.amountPattern)
                    patternField("Остаток", $rule.balancePattern)
                    patternField("Карта", $rule.cardPattern)
                    patternField("Магазин", $rule.merchantPattern)
                    patternField("Дата", $rule.datePattern)
                    TextField("Формат даты, напр. dd.MM.yyyy HH:mm:ss", text: $rule.dateFormat)
                        .font(.footnote.monospaced())
                } header: {
                    Text("Шаблоны (регулярные выражения)")
                } footer: {
                    Text("Значение берётся из первой группы в скобках. Пустое поле — универсальный шаблон. Проще всего создать правило через «Обучить парсер».")
                }
                Section {
                    TextField("Расход", text: $rule.expenseKeywords)
                    TextField("Доход", text: $rule.incomeKeywords)
                    TextField("Перевод", text: $rule.transferKeywords)
                    TextField("Снятие наличных", text: $rule.cashKeywords)
                    TextField("Игнорировать", text: $rule.ignoreKeywords)
                } header: {
                    Text("Ключевые фразы типа")
                } footer: {
                    Text("Дополняют встроенные слова: «списание», «покупка», «пополнение», «перевод»…")
                }
                Section("Проверка") {
                    TextField("Вставьте пример SMS", text: $sample, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.callout.monospaced())
                    if !sample.isEmpty {
                        ParseOutcomeView(text: sample, outcome: BankSMSParser.parse(sample, sender: nil, rules: [rule.definition]))
                    }
                }
            }
            .themedBackground()
            .navigationTitle(rule.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", systemImage: "checkmark") {
                        rule.updatedAt = .now
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func patternField(_ title: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("универсальный", text: binding)
                .font(.footnote.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !BankSMSParser.isValidPattern(binding.wrappedValue) {
                Label("Ошибка в шаблоне", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.negative)
            }
        }
    }
}

#Preview {
    NavigationStack { BankRulesView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
