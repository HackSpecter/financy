import SwiftData
import SwiftUI

/// Карты, по которым читаются SMS. Каждая привязана к счёту.
struct BankCardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BankCard.createdAt) private var cards: [BankCard]
    @State private var editing: BankCard?
    @State private var isAdding = false

    var body: some View {
        List {
            if cards.isEmpty {
                EmptyStateView(title: "Нет карт", symbol: "creditcard", message: "Добавьте карту — последние 4 цифры, как в SMS банка.")
                    .listRowBackground(Color.clear)
            }
            ForEach(cards) { card in
                Button { editing = card } label: {
                    HStack(spacing: 12) {
                        CategoryIcon(symbol: "creditcard.fill", colorHex: card.account?.colorHex ?? "#007AFF", size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.title).font(.body.weight(.medium))
                            Text("→ \(card.account?.name ?? "счёт не выбран")\(card.bankName.isEmpty ? "" : " · \(card.bankName)")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !card.isActive {
                            Text("выключена").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .opacity(card.isActive ? 1 : 0.5)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.map { cards[$0] }.forEach(context.delete)
                try? context.save()
            }
        }
        .themedBackground()
        .navigationTitle("Мои карты")
        .toolbar {
            Button("Добавить", systemImage: "plus") { isAdding = true }
        }
        .sheet(item: $editing) { BankCardEditor(card: $0) }
        .sheet(isPresented: $isAdding) { BankCardEditor(card: nil) }
    }
}

struct BankCardEditor: View {
    var card: BankCard?
    var suggestedLast4 = ""
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.order) private var accounts: [Account]

    @State private var last4 = ""
    @State private var name = ""
    @State private var bankName = ""
    @State private var account: Account?
    @State private var createsAccount = false
    @State private var isActive = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Последние 4 цифры", text: $last4)
                        .keyboardType(.numberPad)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .onChange(of: last4) { last4 = String(last4.filter(\.isNumber).prefix(4)) }
                    TextField("Название (необязательно)", text: $name)
                    TextField("Банк (необязательно)", text: $bankName)
                } footer: {
                    Text("Как в SMS: «Карта 4*4242» → 4242.")
                }
                Section("Записывать операции на счёт") {
                    Toggle("Создать новый счёт", isOn: $createsAccount.animation())
                    if !createsAccount {
                        Picker("Счёт", selection: $account) {
                            ForEach(accounts.filter { !$0.archived }) { Label($0.name, systemImage: $0.symbol).tag(Optional($0)) }
                        }
                    }
                }
                Section {
                    Toggle("Читать SMS по этой карте", isOn: $isActive)
                }
            }
            .themedBackground()
            .navigationTitle(card == nil ? "Новая карта" : "Карта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save)
                        .disabled(last4.count != 4 || (!createsAccount && account == nil))
                }
            }
            .onAppear {
                if let card {
                    last4 = card.last4
                    name = card.name
                    bankName = card.bankName
                    account = card.account
                    isActive = card.isActive
                } else {
                    last4 = suggestedLast4
                    account = accounts.first { $0.name == "Карта" } ?? accounts.first
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        var target = account
        if createsAccount {
            let title = name.isEmpty ? (bankName.isEmpty ? "Карта •\(last4)" : "\(bankName) •\(last4)") : name
            let new = Account(name: title, symbol: "creditcard.fill", colorHex: Color.palette.randomElement() ?? "#007AFF", order: accounts.count)
            context.insert(new)
            target = new
        }
        let item = card ?? BankCard(last4: last4, account: target)
        item.last4 = last4
        item.name = name
        item.bankName = bankName
        item.account = target
        item.isActive = isActive
        if card == nil { context.insert(item) }
        try? context.save()
        dismiss()
    }
}

#Preview {
    NavigationStack { BankCardsView() }
        .modelContainer(DemoData.previewContainer)
}
