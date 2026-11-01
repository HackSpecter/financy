import SwiftData
import SwiftUI

/// Онбординг на 3 экрана: зарплата и дата, начальный баланс, дневное напоминание.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Account.order) private var accounts: [Account]
    @Query private var categories: [Category]

    @State private var page = 0
    @State private var salaryText = ""
    @State private var salaryDay = 1
    @State private var useSalaryAsBudget = true
    @State private var cashText = ""
    @State private var cardText = ""
    @State private var reminderOn = true
    @State private var reminderTime = AppCalendar.calendar.date(byAdding: .hour, value: 21, to: AppCalendar.calendar.startOfDay(for: .now)) ?? .now

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                salaryPage.tag(0)
                balancePage.tag(1)
                reminderPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: next) {
                Text(page == 2 ? "Начать" : "Далее")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background { AmbientBackground() }
        .animation(.snappy, value: page)
        .sensoryFeedback(.selection, trigger: page)
    }

    // MARK: Pages

    private var salaryPage: some View {
        page(symbol: "banknote.fill", tint: Theme.positive, title: "Ваша зарплата", subtitle: "Приложение само добавит её в нужный день и посчитает дневной лимит.") {
            amountField("Сумма", text: $salaryText)
            HStack {
                Text("Приходит")
                Spacer()
                Picker("Приходит", selection: $salaryDay) {
                    ForEach(1...31, id: \.self) { Text("\($0)-го числа").tag($0) }
                }
                .labelsHidden()
            }
            Toggle("Это мой бюджет на месяц", isOn: $useSalaryAsBudget)
        }
    }

    private var balancePage: some View {
        page(symbol: "wallet.bifold.fill", tint: .blue, title: "Сколько денег сейчас", subtitle: "Начальный баланс по счетам. Можно оставить пустым и указать позже.") {
            amountField("Наличные", text: $cashText)
            amountField("Карта", text: $cardText)
        }
    }

    private var reminderPage: some View {
        page(symbol: "bell.badge.fill", tint: Theme.caution, title: "Вечернее напоминание", subtitle: "Короткое уведомление «Внеси расходы за сегодня» — так ни одна трата не потеряется.") {
            Toggle("Напоминать каждый день", isOn: $reminderOn)
            if reminderOn {
                DatePicker("Время", selection: $reminderTime, displayedComponents: .hourAndMinute)
            }
        }
    }

    private func page<Content: View>(symbol: String, tint: Color, title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: symbol)
                    .font(.system(size: 64))
                    .foregroundStyle(tint.gradient)
                    .symbolEffect(.bounce, value: page)
                    .padding(.top, 48)
                Text(title).font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(subtitle).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                VStack(spacing: 16) { content() }
                    .card()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func amountField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
            Text(settings.currencyCode).foregroundStyle(.secondary)
        }
    }

    // MARK: Actions

    private func next() {
        if page < 2 {
            page += 1
        } else {
            finish()
        }
    }

    private func finish() {
        let cash = accounts.first { $0.name == "Наличные" } ?? accounts.first
        let card = accounts.first { $0.name == "Карта" } ?? accounts.last
        cash?.initialBalance = Money.parse(cashText) ?? 0
        card?.initialBalance = Money.parse(cardText) ?? 0

        if let salary = Money.parse(salaryText), salary > 0 {
            let category = categories.first { $0.kind == .income && $0.name == "Зарплата" }
            // Зарплата приходит из SMS или вручную; правило — чтобы узнавать её в SMS и считать бюджет.
            let rule = RecurringRule(title: "Зарплата", type: .income, amount: salary, category: category, account: card, frequency: .monthly, dayOfMonth: salaryDay, startDate: .now)
            rule.isActive = false
            context.insert(rule)
            if useSalaryAsBudget { context.insert(Budget(limit: salary)) }
        }
        try? context.save()

        settings.reminderTime = reminderTime
        settings.dailyReminderEnabled = reminderOn
        if reminderOn {
            let minutes = settings.dailyReminderMinutes
            Task {
                await NotificationService.requestAuthorization()
                await NotificationService.scheduleDailyReminder(minutes: minutes)
            }
        }
        WidgetRefresher.reload()
        settings.hasOnboarded = true
    }
}

#Preview {
    OnboardingView()
        .modelContainer(DataStore.makeContainer(inMemory: true))
        .environment(AppSettings.shared)
}
