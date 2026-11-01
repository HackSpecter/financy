import SwiftData
import SwiftUI

/// Долги и займы: кто должен мне и кому должен я.
struct DebtsView: View {
    @Query(sort: \Debt.date, order: .reverse) private var debts: [Debt]
    @Environment(AppSettings.self) private var settings
    @State private var direction: DebtDirection = .theyOwe
    @State private var isAdding = false
    @State private var showsClosed = false

    var body: some View {
        let totals = DebtCalculator.totals(debts.map(\.snapshot)) { CurrencyService.toBase($0, from: $1) }
        List {
            Section {
                HStack {
                    total("Мне должны", totals.owedToMe, Theme.positive)
                    Divider()
                    total("Я должен", totals.iOwe, Theme.negative)
                }
                .padding(.vertical, 4)
            }
            Section {
                Picker("Направление", selection: $direction) {
                    ForEach(DebtDirection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                let visible = debts.filter { $0.direction == direction && $0.isClosed == showsClosed }
                if visible.isEmpty {
                    Text(showsClosed ? "Закрытых долгов нет" : "Открытых долгов нет").foregroundStyle(.secondary)
                }
                ForEach(visible) { debt in
                    NavigationLink { DebtDetailView(debt: debt) } label: { DebtRow(debt: debt) }
                }
            } footer: {
                Button(showsClosed ? "Показать открытые" : "Показать закрытые") { showsClosed.toggle() }
            }
        }
        .themedBackground()
        .navigationTitle("Долги")
        .toolbar {
            Button("Добавить", systemImage: "plus") { isAdding = true }
        }
        .sheet(isPresented: $isAdding) { DebtEditor(direction: direction) }
    }

    private func total(_ title: String, _ amount: Decimal, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(color)
            MoneyText(amount: amount, font: .title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DebtRow: View {
    var debt: Debt

    var body: some View {
        HStack(spacing: 12) {
            Text(String(debt.personName.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background((debt.direction == .theyOwe ? Theme.positive : Theme.negative).gradient, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(debt.personName).font(.body.weight(.medium))
                HStack(spacing: 4) {
                    if let due = debt.dueDate {
                        let overdue = due < AppCalendar.calendar.startOfDay(for: .now) && !debt.isClosed
                        Image(systemName: overdue ? "exclamationmark.circle.fill" : "calendar")
                        Text("до \(due.appFormatted("dMMM"))")
                    }
                    if debt.paid > 0 { Text("· вернул \(Money.format(debt.paid, currency: debt.currencyCode))") }
                }
                .font(.caption)
                .foregroundStyle(debt.dueDate.map { $0 < .now && !debt.isClosed } == true ? Theme.negative : .secondary)
            }
            Spacer()
            Text(Money.format(debt.remaining, currency: debt.currencyCode))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }
}

struct DebtDetailView: View {
    @Bindable var debt: Debt
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.order) private var accounts: [Account]
    @State private var amountText = ""
    @State private var account: Account?
    @State private var createsTransaction = true
    @State private var editing = false
    @State private var paidCount = 0

    var body: some View {
        List {
            Section {
                LabeledContent(debt.direction.title, value: Money.format(debt.remaining, currency: debt.currencyCode))
                LabeledContent("Всего", value: Money.format(debt.amount, currency: debt.currencyCode))
                LabeledContent("Дата", value: debt.date.appFormatted("dMMMMyyyy"))
                if let due = debt.dueDate { LabeledContent("Срок возврата", value: due.appFormatted("dMMMMyyyy")) }
                if !debt.note.isEmpty { Text(debt.note).foregroundStyle(.secondary) }
            }
            if !debt.isClosed {
                Section {
                    HStack {
                        TextField("Сумма возврата", text: $amountText).keyboardType(.decimalPad)
                        Button("Весь остаток") { amountText = Money.formatNumber(debt.remaining).replacingOccurrences(of: "\u{00A0}", with: "") }
                            .font(.caption)
                    }
                    Toggle("Записать операцию", isOn: $createsTransaction)
                    if createsTransaction {
                        Picker("Счёт", selection: $account) {
                            ForEach(accounts.filter { !$0.archived }) { Text($0.name).tag(Optional($0)) }
                        }
                    }
                    Button(debt.direction == .theyOwe ? "Мне вернули" : "Я вернул", systemImage: "arrow.uturn.backward.circle.fill") {
                        guard let amount = Money.parse(amountText), amount > 0 else { return }
                        DebtService.addPayment(min(amount, debt.remaining), to: debt, account: createsTransaction ? account : nil, in: context)
                        amountText = ""
                        paidCount += 1
                    }
                    .disabled(Money.parse(amountText) == nil)
                } header: {
                    Text("Возврат")
                } footer: {
                    Text(debt.direction == .theyOwe ? "Создаст доход «Возврат долга» на выбранном счёте." : "Создаст расход «Долги» на выбранном счёте.")
                }
            }
            Section("История") {
                ForEach((debt.payments ?? []).sorted { $0.date > $1.date }) { payment in
                    HStack {
                        Text(payment.date.appFormatted("dMMMyyyy"))
                        Spacer()
                        Text(Money.format(payment.amount, currency: debt.currencyCode)).monospacedDigit()
                    }
                }
                if (debt.payments ?? []).isEmpty { Text("Возвратов ещё не было").foregroundStyle(.secondary) }
            }
            Section {
                Button(debt.isClosed ? "Открыть снова" : "Закрыть долг", systemImage: debt.isClosed ? "arrow.counterclockwise" : "checkmark.circle") {
                    debt.isClosed.toggle()
                    try? context.save()
                    DebtService.scheduleReminder(for: debt)
                }
                Button("Удалить", systemImage: "trash", role: .destructive) {
                    NotificationService.cancel(id: DebtService.reminderID(debt.id))
                    context.delete(debt)
                    try? context.save()
                    dismiss()
                }
            }
        }
        .themedBackground()
        .navigationTitle(debt.personName)
        .toolbar { Button("Изменить", systemImage: "pencil") { editing = true } }
        .sheet(isPresented: $editing) { DebtEditor(debt: debt, direction: debt.direction) }
        .onAppear { account = TransactionService.lastAccount(in: context) }
        .sensoryFeedback(.success, trigger: paidCount)
    }
}

#Preview {
    NavigationStack { DebtsView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
