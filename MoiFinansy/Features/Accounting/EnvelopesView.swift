import SwiftData
import SwiftUI

/// Метод конвертов: зарплата по конвертам, остатки видны всегда.
struct EnvelopesView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Envelope.order) private var envelopes: [Envelope]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var isEnabled = EnvelopeService.isEnabled
    @State private var editing: Envelope?
    @State private var isAdding = false
    @State private var isAllocating = false

    var body: some View {
        let month = AppCalendar.calendar.monthInterval(for: .now)
        let entries = transactions.filter { month.contains($0.date) }.map(\.entry)
        let income = entries.filter { $0.type == .income }.sum(\.amount)
        List {
            Section {
                Toggle("Метод конвертов", isOn: $isEnabled)
            } footer: {
                Text("В день зарплаты Khalid Finance предложит разложить её по конвертам. Траты категорий конверта уменьшают его остаток.")
            }
            if isEnabled {
                Section {
                    LabeledContent("Доход месяца", value: Money.format(income, currency: settings.currencyCode))
                    let free = EnvelopeCalculator.unallocated(income: income, envelopes: envelopes.map(\.monthlyAmount))
                    LabeledContent("Не распределено", value: Money.format(free, currency: settings.currencyCode))
                        .foregroundStyle(free < 0 ? Theme.negative : .primary)
                    Button("Распределить зарплату", systemImage: "square.split.2x2.fill") { isAllocating = true }
                }
                Section("Конверты") {
                    ForEach(envelopes) { envelope in
                        let status = EnvelopeCalculator.status(allocated: envelope.monthlyAmount, categoryIDs: Set((envelope.categories ?? []).map(\.id)), entries: entries)
                        Button { editing = envelope } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    CategoryIcon(symbol: envelope.symbol, colorHex: envelope.colorHex, size: 32)
                                    Text(envelope.name).font(.body.weight(.medium))
                                    Spacer()
                                    Text(Money.format(status.remaining, currency: settings.currencyCode))
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                        .foregroundStyle(status.remaining < 0 ? Theme.negative : .primary)
                                }
                                ProgressBar(value: status.fraction, tint: status.fraction >= 1 ? Theme.negative : Color(hex: envelope.colorHex), height: 8)
                                Text("потрачено \(Money.format(status.spent, currency: settings.currencyCode)) из \(Money.format(status.allocated, currency: settings.currencyCode)) · \((envelope.categories ?? []).map(\.name).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        offsets.map { envelopes[$0] }.forEach(context.delete)
                        try? context.save()
                    }
                    Button("Новый конверт", systemImage: "plus") { isAdding = true }
                }
            }
        }
        .themedBackground()
        .navigationTitle("Конверты")
        .onChange(of: isEnabled) {
            EnvelopeService.isEnabled = isEnabled
            if isEnabled, envelopes.isEmpty { createDefaults() }
        }
        .sheet(item: $editing) { EnvelopeEditor(envelope: $0) }
        .sheet(isPresented: $isAdding) { EnvelopeEditor(envelope: nil) }
        .sheet(isPresented: $isAllocating) { EnvelopeAllocationView(income: income) }
    }

    /// Стартовый набор: еда, транспорт, жильё, остальное.
    private func createDefaults() {
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        func pick(_ names: [String]) -> [Category] { categories.filter { names.contains($0.name) && $0.kind == .expense } }
        let defaults: [(String, String, String, Decimal, [String])] = [
            ("Еда", "fork.knife", "#34C759", 6000, ["Продукты", "Кафе и рестораны"]),
            ("Транспорт", "car.fill", "#FFCC00", 1500, ["Такси", "Транспорт"]),
            ("Жильё и связь", "house.fill", "#5856D6", 4000, ["Аренда/Коммуналка", "Связь и интернет"]),
            ("Остальное", "bag.fill", "#AF52DE", 4000, ["Одежда", "Здоровье", "Развлечения", "Подарки", "Семья", "Прочее"]),
        ]
        for (index, item) in defaults.enumerated() {
            let envelope = Envelope(name: item.0, symbol: item.1, colorHex: item.2, monthlyAmount: item.3, order: index)
            context.insert(envelope)
            for category in pick(item.4) { category.envelope = envelope }
        }
        try? context.save()
    }
}

struct EnvelopeEditor: View {
    var envelope: Envelope?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Category.order) private var categories: [Category]
    @Query private var envelopes: [Envelope]
    @State private var name = ""
    @State private var amountText = ""
    @State private var symbol = "envelope.fill"
    @State private var colorHex = "#007AFF"
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        CategoryIcon(symbol: symbol, colorHex: colorHex, size: 40)
                        TextField("Название", text: $name)
                    }
                    HStack {
                        TextField("Сумма в месяц", text: $amountText).keyboardType(.decimalPad)
                        Text(settings.currencyCode).foregroundStyle(.secondary)
                    }
                }
                Section("Категории") {
                    ForEach(categories.filter { $0.kind == .expense && !$0.archived }) { category in
                        Button {
                            if selected.contains(category.id) { selected.remove(category.id) } else { selected.insert(category.id) }
                        } label: {
                            HStack {
                                CategoryIcon(category: category, size: 28)
                                Text(category.name)
                                if let other = category.envelope, other.id != envelope?.id {
                                    Text("· \(other.name)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selected.contains(category.id) { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("Иконка") { SymbolColorPicker(symbol: $symbol, colorHex: $colorHex) }
            }
            .themedBackground()
            .navigationTitle(envelope == nil ? "Новый конверт" : "Конверт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save).disabled(name.isEmpty || Money.parse(amountText) == nil)
                }
            }
            .onAppear {
                guard let envelope else { return }
                name = envelope.name
                amountText = Money.formatNumber(envelope.monthlyAmount).replacingOccurrences(of: "\u{00A0}", with: "")
                symbol = envelope.symbol
                colorHex = envelope.colorHex
                selected = Set((envelope.categories ?? []).map(\.id))
            }
        }
    }

    private func save() {
        guard let amount = Money.parse(amountText) else { return }
        let target = envelope ?? Envelope(name: name, symbol: symbol, colorHex: colorHex, monthlyAmount: amount, order: envelopes.count)
        target.name = name
        target.monthlyAmount = amount
        target.symbol = symbol
        target.colorHex = colorHex
        if envelope == nil { context.insert(target) }
        for category in categories {
            if selected.contains(category.id) {
                category.envelope = target
            } else if category.envelope?.id == target.id {
                category.envelope = nil
            }
        }
        try? context.save()
        dismiss()
    }
}

/// Распределение зарплаты по конвертам.
struct EnvelopeAllocationView: View {
    var income: Decimal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Envelope.order) private var envelopes: [Envelope]
    @State private var amounts: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    let total = envelopes.sum { Money.parse(amounts[$0.id] ?? "") ?? 0 }
                    LabeledContent("Доход", value: Money.format(income, currency: settings.currencyCode))
                    LabeledContent("Осталось распределить", value: Money.format(income - total, currency: settings.currencyCode))
                        .foregroundStyle(income - total < 0 ? Theme.negative : Theme.positive)
                }
                Section("Конверты") {
                    ForEach(envelopes) { envelope in
                        HStack {
                            Label(envelope.name, systemImage: envelope.symbol)
                            TextField("0", text: Binding(get: { amounts[envelope.id] ?? "" }, set: { amounts[envelope.id] = $0 }))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .themedBackground()
            .navigationTitle("Распределить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", systemImage: "checkmark") {
                        for envelope in envelopes { envelope.monthlyAmount = Money.parse(amounts[envelope.id] ?? "") ?? 0 }
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                for envelope in envelopes {
                    amounts[envelope.id] = Money.formatNumber(envelope.monthlyAmount).replacingOccurrences(of: "\u{00A0}", with: "")
                }
            }
        }
    }
}

#Preview {
    NavigationStack { EnvelopesView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
