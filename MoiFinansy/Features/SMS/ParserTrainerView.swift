import SwiftData
import SwiftUI

/// «Обучить парсер»: пример SMS → подсветка → исправления → сохранённое правило.
struct ParserTrainerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BankSMSRule.order) private var rules: [BankSMSRule]

    @State private var text = ""
    @State private var bankName = ""
    @State private var senderKeywords = ""
    @State private var kind: BankSMSParser.Kind = .debit
    @State private var typePhrase = ""
    @State private var amount = ""
    @State private var balance = ""
    @State private var card = ""
    @State private var merchant = ""
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                TextField("Вставьте SMS банка целиком", text: $text, axis: .vertical)
                    .lineLimit(4...10)
                    .font(.callout.monospaced())
                if text.isEmpty {
                    Button("Вставить из буфера", systemImage: "doc.on.clipboard") {
                        text = UIPasteboard.general.string ?? ""
                    }
                }
            } header: {
                Text("1. Пример SMS")
            }

            if !text.isEmpty {
                Section("2. Что нашлось") {
                    ParseOutcomeView(text: text, outcome: current)
                }

                Section {
                    TextField("Название банка", text: $bankName)
                    TextField("Слова отправителя, через запятую", text: $senderKeywords)
                        .textInputAutocapitalization(.never)
                    Picker("Тип операции", selection: $kind) {
                        ForEach(BankSMSParser.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField("Фраза типа из SMS, напр. «Списание со счета»", text: $typePhrase)
                    field("Сумма", $amount)
                    field("Остаток", $balance)
                    field("Карта (4 цифры)", $card)
                    field("Магазин", $merchant)
                } header: {
                    Text("3. Поправьте значения")
                } footer: {
                    Text("Введите значения так, как они написаны в SMS. Из текста вокруг них \(AppInfo.name) построит правило для этого банка.")
                }

                Section {
                    Button("Сохранить правило", systemImage: "square.and.arrow.down.fill", action: save)
                        .disabled(bankName.isEmpty || amount.isEmpty)
                    if saved {
                        Label("Правило сохранено — следующие SMS этого банка разберутся по нему", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.positive)
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle("Обучить парсер")
        .onChange(of: text) { prefill() }
        .sensoryFeedback(.success, trigger: saved)
    }

    private var current: BankSMSParser.Outcome {
        BankSMSParser.parse(text, rules: rules.filter(\.isEnabled).map(\.definition))
    }

    private func field(_ title: String, _ binding: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField("—", text: binding)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .foregroundStyle(binding.wrappedValue.isEmpty || text.localizedCaseInsensitiveContains(binding.wrappedValue) ? Color.primary : Theme.negative)
        }
    }

    /// Подставляет найденные значения как текст из SMS.
    private func prefill() {
        saved = false
        let ns = text as NSString
        guard let parsed = current.parsed else {
            typePhrase = text.split(separator: "\n").first { $0.rangeOfCharacter(from: .decimalDigits) == nil }.map(String.init) ?? ""
            return
        }
        func value(_ field: BankSMSParser.Field) -> String {
            guard let range = parsed.highlights[field] else { return "" }
            return ns.substring(with: range)
        }
        kind = parsed.kind
        amount = value(.amount)
        balance = value(.balance)
        card = value(.card)
        merchant = value(.merchant)
        typePhrase = text.split(separator: "\n").map(String.init).first { line in
            line.rangeOfCharacter(from: .decimalDigits) == nil && line.rangeOfCharacter(from: .letters) != nil
        } ?? value(.type)
    }

    private func save() {
        let sample = RuleLearner.Sample(
            text: text,
            name: bankName,
            senderKeywords: senderKeywords.isEmpty ? bankName.lowercased() : senderKeywords,
            amount: amount.isEmpty ? nil : amount,
            balance: balance.isEmpty ? nil : balance,
            card: card.isEmpty ? nil : card,
            merchant: merchant.isEmpty ? nil : merchant,
            kind: kind,
            typePhrase: typePhrase
        )
        let definition = RuleLearner.makeRule(from: sample)
        var merged = definition
        let rule: BankSMSRule
        if let existing = rules.first(where: { $0.name.caseInsensitiveCompare(bankName) == .orderedSame }) {
            // Дополняем существующее правило, не стирая фразы других типов.
            let old = existing.definition
            func join(_ a: String, _ b: String) -> String { [a, b].filter { !$0.isEmpty }.joined(separator: ",") }
            merged.expenseKeywords = join(old.expenseKeywords, definition.expenseKeywords)
            merged.incomeKeywords = join(old.incomeKeywords, definition.incomeKeywords)
            merged.transferKeywords = join(old.transferKeywords, definition.transferKeywords)
            merged.cashKeywords = join(old.cashKeywords, definition.cashKeywords)
            if merged.merchantPattern.isEmpty { merged.merchantPattern = old.merchantPattern }
            if merged.balancePattern.isEmpty { merged.balancePattern = old.balancePattern }
            if merged.cardPattern.isEmpty { merged.cardPattern = old.cardPattern }
            rule = existing
        } else {
            // Новое правило проверяется первым.
            for other in rules { other.order += 1 }
            rule = BankSMSRule(name: bankName, senderKeywords: definition.senderKeywords, order: 0)
            context.insert(rule)
        }
        rule.apply(merged)
        try? context.save()
        saved = true
    }
}

#Preview {
    NavigationStack { ParserTrainerView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
