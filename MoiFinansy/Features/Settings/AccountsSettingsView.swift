import SwiftData
import SwiftUI

struct AccountsSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.order) private var accounts: [Account]
    @State private var editing: Account?
    @State private var isAdding = false

    var body: some View {
        List {
            ForEach(accounts) { account in
                Button { editing = account } label: {
                    HStack(spacing: 12) {
                        CategoryIcon(symbol: account.symbol, colorHex: account.colorHex, size: 36)
                        Text(account.name).foregroundStyle(account.archived ? .secondary : .primary)
                        if account.archived { Text("в архиве").font(.caption).foregroundStyle(.secondary) }
                        else if !account.countsInBalance { Text("не в балансе").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        MoneyText(amount: account.balance, currency: account.currencyCode)
                    }
                }
                .buttonStyle(.plain)
            }
            .onMove { from, to in
                var reordered = accounts
                reordered.move(fromOffsets: from, toOffset: to)
                for (index, account) in reordered.enumerated() { account.order = index }
                try? context.save()
            }
        }
        .themedBackground()
        .navigationTitle("Счета")
        .toolbar {
            EditButton()
            Button("Добавить", systemImage: "plus") { isAdding = true }
        }
        .sheet(item: $editing) { AccountEditor(account: $0) }
        .sheet(isPresented: $isAdding) { AccountEditor(account: nil) }
    }
}

struct AccountEditor: View {
    var account: Account?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query private var accounts: [Account]

    @State private var name = ""
    @State private var symbol = "creditcard.fill"
    @State private var colorHex = "#007AFF"
    @State private var balanceText = ""
    @State private var archived = false
    @State private var currency = SharedDefaults.currencyCode
    @State private var isSavings = false
    @State private var countsInBalance = true
    @State private var currentBalanceText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        CategoryIcon(symbol: symbol, colorHex: colorHex, size: 44)
                        TextField("Название", text: $name).font(.title3)
                    }
                    if account == nil {
                        HStack {
                            TextField("Начальный остаток", text: $balanceText).keyboardType(.numbersAndPunctuation)
                            Text(currency).foregroundStyle(.secondary)
                        }
                    } else {
                        LabeledContent("Баланс сейчас") {
                            HStack {
                                TextField("0", text: $currentBalanceText)
                                    .keyboardType(.numbersAndPunctuation)
                                    .multilineTextAlignment(.trailing)
                                    .font(.body.weight(.semibold))
                                Text(currency).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Picker("Валюта счёта", selection: $currency) {
                        ForEach(CurrencyService.supported, id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Копилка", isOn: $isSavings)
                        .onChange(of: isSavings) { _, saving in countsInBalance = !saving }
                    Toggle("Учитывать в балансе", isOn: $countsInBalance)
                } footer: {
                    Text("«Баланс сейчас» — сколько реально денег на счёте. Если изменить, приложение добавит операцию-корректировку: баланс станет таким, отчёты не изменятся. «Учитывать в балансе» — сумма входит в «Баланс сейчас» на Главной.")
                }
                Section("Оформление") { SymbolColorPicker(symbol: $symbol, colorHex: $colorHex) }
                if account != nil {
                    Toggle("В архиве", isOn: $archived)
                }
            }
            .themedBackground()
            .navigationTitle(account == nil ? "Новый счёт" : "Счёт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let account else { return }
                name = account.name
                symbol = account.symbol
                colorHex = account.colorHex
                balanceText = Money.formatNumber(account.initialBalance).replacingOccurrences(of: "\u{00A0}", with: "")
                archived = account.archived
                currency = account.currencyCode
                isSavings = account.isSavings
                countsInBalance = account.countsInBalance
                currentBalanceText = Money.formatNumber(account.balance).replacingOccurrences(of: "\u{00A0}", with: "")
            }
        }
    }

    private func save() {
        let balance = Money.parse(balanceText) ?? 0
        if let account {
            account.name = name
            account.symbol = symbol
            account.colorHex = colorHex
            account.archived = archived
            account.currencyCode = currency
            account.isSavings = isSavings
            account.countsInBalance = countsInBalance
            // Реальный баланс: разница записывается корректировкой.
            if let wanted = Money.parse(currentBalanceText) {
                let difference = wanted - account.balance
                if abs(difference) >= Decimal(string: "0.01")! {
                    context.insert(Transaction(type: .adjustment, amount: difference, account: account, date: .now, note: "Баланс указан вручную"))
                }
            }
        } else {
            let account = Account(name: name, symbol: symbol, colorHex: colorHex, initialBalance: balance, order: accounts.count)
            account.currencyCode = currency
            account.isSavings = isSavings
            account.countsInBalance = countsInBalance
            context.insert(account)
        }
        try? context.save()
        WidgetRefresher.reload()
        dismiss()
    }
}

#Preview {
    NavigationStack { AccountsSettingsView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
