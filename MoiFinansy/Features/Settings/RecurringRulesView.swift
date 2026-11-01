import SwiftData
import SwiftUI

/// Регулярные операции: зарплата, аренда, интернет, подписки.
struct RecurringRulesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringRule.nextDate) private var rules: [RecurringRule]
    @State private var editing: RecurringRule?
    @State private var isAdding = false

    var body: some View {
        List {
            if rules.isEmpty {
                EmptyStateView(
                    title: "Нет регулярных операций",
                    symbol: "repeat",
                    message: "Добавьте зарплату, аренду или интернет — они будут создаваться автоматически."
                )
                .listRowBackground(Color.clear)
            }
            ForEach(rules) { rule in
                Button { editing = rule } label: {
                    HStack(spacing: 12) {
                        CategoryIcon(category: rule.category, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.title).font(.body.weight(.medium))
                            Text("\(scheduleText(rule)) · след. \(rule.nextDate.dayTitle.lowercased())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        MoneyText(amount: rule.amount, type: rule.type)
                    }
                    .opacity(rule.isActive ? 1 : 0.5)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.map { rules[$0] }.forEach(context.delete)
                try? context.save()
                WidgetRefresher.reload()
            }
        }
        .themedBackground()
        .navigationTitle("Регулярные")
        .toolbar {
            Button("Добавить", systemImage: "plus") { isAdding = true }
        }
        .sheet(item: $editing) { RecurringRuleEditor(rule: $0) }
        .sheet(isPresented: $isAdding) { RecurringRuleEditor(rule: nil) }
    }

    private func scheduleText(_ rule: RecurringRule) -> String {
        switch rule.frequency {
        case .monthly: "\(rule.dayOfMonth)-го числа"
        case .weekly: "по \(rule.startDate.appFormatted("EEEE"))"
        case .daily: "ежедневно"
        case .yearly: "ежегодно"
        }
    }
}

struct RecurringRuleEditor: View {
    var rule: RecurringRule?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Account.order) private var accounts: [Account]

    @State private var title = ""
    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var category: Category?
    @State private var account: Account?
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var dayOfMonth = 1
    @State private var startDate = Date.now
    @State private var isMandatory = true
    @State private var isActive = true
    @State private var isSubscription = false
    @State private var remindDaysBefore = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название, например «Аренда»", text: $title)
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
                        Text("Без категории").tag(Category?.none)
                        ForEach(categories.filter { $0.kind == (type == .income ? .income : .expense) && !$0.archived }) {
                            Label($0.name, systemImage: $0.symbol).tag(Optional($0))
                        }
                    }
                    Picker("Счёт", selection: $account) {
                        ForEach(accounts.filter { !$0.archived }) { Text($0.name).tag(Optional($0)) }
                    }
                }
                Section("Расписание") {
                    Picker("Повтор", selection: $frequency) {
                        ForEach(RecurrenceFrequency.allCases) { Text($0.title).tag($0) }
                    }
                    if frequency == .monthly || frequency == .yearly {
                        Picker("День месяца", selection: $dayOfMonth) {
                            ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                        }
                    }
                    DatePicker(frequency == .weekly ? "Первая дата (день недели)" : "Начиная с", selection: $startDate, displayedComponents: .date)
                }
                Section {
                    if type == .expense {
                        Toggle("Обязательный платёж", isOn: $isMandatory)
                    }
                    Toggle("Активна", isOn: $isActive)
                    if type == .expense {
                        Toggle("Подписка", isOn: $isSubscription)
                        Picker("Напомнить", selection: $remindDaysBefore) {
                            Text("Не напоминать").tag(0)
                            Text("За 1 день").tag(1)
                            Text("За 2 дня").tag(2)
                            Text("За 3 дня").tag(3)
                        }
                    }
                } footer: {
                    Text("Обязательные платежи заранее вычитаются из «Можно потратить сегодня».")
                }
            }
            .themedBackground()
            .navigationTitle(rule == nil ? "Новая регулярная" : "Регулярная")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save)
                        .disabled(title.isEmpty || Money.parse(amountText) == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let rule else {
            account = accounts.first { !$0.archived }
            dayOfMonth = AppCalendar.calendar.component(.day, from: .now)
            return
        }
        title = rule.title
        type = rule.type
        amountText = Money.formatNumber(rule.amount).replacingOccurrences(of: "\u{00A0}", with: "")
        category = rule.category
        account = rule.account
        frequency = rule.frequency
        dayOfMonth = rule.dayOfMonth
        startDate = rule.startDate
        isMandatory = rule.isMandatory
        isActive = rule.isActive
        isSubscription = rule.isSubscription
        remindDaysBefore = rule.remindDaysBefore
    }

    private func save() {
        guard let amount = Money.parse(amountText), amount > 0 else { return }
        let calendar = AppCalendar.calendar
        let target = rule ?? RecurringRule(title: title, type: type, amount: amount, category: category, account: account, frequency: frequency, dayOfMonth: dayOfMonth, startDate: startDate)
        target.title = title
        target.type = type
        target.amount = amount
        target.category = category
        target.account = account
        target.frequency = frequency
        target.dayOfMonth = dayOfMonth
        target.startDate = startDate
        target.isMandatory = type == .expense && isMandatory
        target.isActive = isActive
        target.isSubscription = type == .expense && isSubscription
        target.remindDaysBefore = type == .expense ? remindDaysBefore : 0
        // Не создаём задним числом: следующая дата — не раньше сегодняшнего дня.
        let from = max(calendar.startOfDay(for: startDate), calendar.startOfDay(for: .now))
        target.nextDate = target.recurrence.firstOccurrence(onOrAfter: from, calendar: calendar)
        if rule == nil { context.insert(target) }
        try? context.save()
        RecurringService.processDue(in: context)
        SubscriptionReminders.reschedule(in: context)
        if remindDaysBefore > 0 { Task { await NotificationService.requestAuthorization() } }
        WidgetRefresher.reload()
        dismiss()
    }
}

#Preview {
    NavigationStack { RecurringRulesView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
