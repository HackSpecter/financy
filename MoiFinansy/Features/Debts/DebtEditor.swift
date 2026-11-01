import Contacts
import ContactsUI
import SwiftData
import SwiftUI

struct DebtEditor: View {
    var debt: Debt?
    var direction: DebtDirection
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.order) private var accounts: [Account]

    @State private var personName = ""
    @State private var contactIdentifier = ""
    @State private var selectedDirection: DebtDirection = .theyOwe
    @State private var amountText = ""
    @State private var currency = "TJS"
    @State private var date = Date.now
    @State private var hasDueDate = false
    @State private var dueDate = AppCalendar.calendar.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var note = ""
    @State private var recordsTransaction = true
    @State private var account: Account?
    @State private var showsContacts = false

    init(debt: Debt? = nil, direction: DebtDirection) {
        self.debt = debt
        self.direction = direction
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Направление", selection: $selectedDirection) {
                        ForEach(DebtDirection.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        TextField("Имя", text: $personName)
                        Button("Контакты", systemImage: "person.crop.circle.badge.plus") { showsContacts = true }
                            .labelStyle(.iconOnly)
                    }
                    HStack {
                        TextField("Сумма", text: $amountText).keyboardType(.decimalPad).font(.title3.weight(.semibold))
                        Picker("Валюта", selection: $currency) {
                            ForEach(CurrencyService.supported, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                }
                Section {
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                    Toggle("Срок возврата", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Вернуть до", selection: $dueDate, displayedComponents: .date)
                    }
                    TextField("Заметка", text: $note, axis: .vertical)
                } footer: {
                    if hasDueDate { Text("Напомним в день срока в 10:00.") }
                }
                if debt == nil {
                    Section {
                        Toggle(selectedDirection == .theyOwe ? "Деньги ушли со счёта" : "Деньги пришли на счёт", isOn: $recordsTransaction)
                        if recordsTransaction {
                            Picker("Счёт", selection: $account) {
                                ForEach(accounts.filter { !$0.archived }) { Text($0.name).tag(Optional($0)) }
                            }
                        }
                    }
                }
            }
            .themedBackground()
            .navigationTitle(debt == nil ? "Новый долг" : "Долг")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save)
                        .disabled(personName.trimmingCharacters(in: .whitespaces).isEmpty || Money.parse(amountText) == nil)
                }
            }
            .sheet(isPresented: $showsContacts) {
                ContactPicker { name, identifier in
                    personName = name
                    contactIdentifier = identifier
                }
                .ignoresSafeArea()
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        selectedDirection = direction
        currency = settings.currencyCode
        account = TransactionService.lastAccount(in: context)
        guard let debt else { return }
        personName = debt.personName
        contactIdentifier = debt.contactIdentifier
        selectedDirection = debt.direction
        amountText = Money.formatNumber(debt.amount).replacingOccurrences(of: "\u{00A0}", with: "")
        currency = debt.currencyCode
        date = debt.date
        hasDueDate = debt.dueDate != nil
        dueDate = debt.dueDate ?? dueDate
        note = debt.note
    }

    private func save() {
        guard let amount = Money.parse(amountText), amount > 0 else { return }
        if let debt {
            debt.personName = personName
            debt.contactIdentifier = contactIdentifier
            debt.direction = selectedDirection
            debt.amount = amount
            debt.currencyCode = currency
            debt.date = date
            debt.dueDate = hasDueDate ? dueDate : nil
            debt.note = note
            try? context.save()
            DebtService.scheduleReminder(for: debt)
        } else {
            let new = Debt(personName: personName, direction: selectedDirection, amount: amount, currencyCode: currency, date: date, dueDate: hasDueDate ? dueDate : nil, note: note)
            new.contactIdentifier = contactIdentifier
            DebtService.create(new, recordIn: recordsTransaction ? account : nil, in: context)
            if hasDueDate { Task { await NotificationService.requestAuthorization() } }
        }
        dismiss()
    }
}

/// Выбор человека из «Контактов» (без запроса доступа ко всей книге).
struct ContactPicker: UIViewControllerRepresentable {
    var onPick: (String, String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String, String) -> Void

        init(onPick: @escaping (String, String) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? contact.givenName
            onPick(name, contact.identifier)
        }
    }
}
