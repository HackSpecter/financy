import SwiftData
import SwiftUI

/// Подписки и регулярные платежи: сколько в месяц и в год, ближайшие списания, автообнаружение.
struct SubscriptionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \RecurringRule.nextDate) private var rules: [RecurringRule]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var editing: RecurringRule?
    @State private var isAdding = false

    var body: some View {
        let subscriptions = rules.filter { $0.isSubscription && $0.isActive }
        let monthly = subscriptions.sum { CurrencyService.toBase(SubscriptionDetector.monthlyEquivalent($0.amount, frequency: $0.frequency), from: $0.account?.currencyCode ?? settings.currencyCode) }
        let regular = rules.filter { !$0.isSubscription && $0.isActive && $0.type == .expense }
        List {
            Section {
                HStack {
                    total("В месяц", monthly)
                    Divider()
                    total("В год", monthly * 12)
                }
                .padding(.vertical, 4)
            }

            Section("Подписки") {
                if subscriptions.isEmpty {
                    Text("Отметьте регулярный платёж как подписку или добавьте найденные ниже.").foregroundStyle(.secondary)
                }
                ForEach(subscriptions) { rule in row(rule) }
            }

            if !candidates.isEmpty {
                Section {
                    ForEach(candidates) { candidate in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.title.capitalizedFirst).font(.body.weight(.medium))
                                Text("~\(candidate.dayOfMonth)-го числа · \(candidate.months) мес. подряд").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.format(candidate.amount, currency: settings.currencyCode)).monospacedDigit()
                            Button("Добавить", systemImage: "plus.circle.fill") { add(candidate) }
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.tint)
                        }
                    }
                } header: {
                    Text("Похоже на подписку")
                } footer: {
                    Text("Нашли в истории платежи, которые повторяются каждый месяц примерно в одно число.")
                }
            }

            if !regular.isEmpty {
                Section("Другие регулярные платежи") {
                    ForEach(regular) { rule in row(rule) }
                }
            }
        }
        .themedBackground()
        .navigationTitle("Подписки")
        .toolbar { Button("Добавить", systemImage: "plus") { isAdding = true } }
        .sheet(item: $editing) { RecurringRuleEditor(rule: $0) }
        .sheet(isPresented: $isAdding) { RecurringRuleEditor(rule: nil) }
    }

    private var candidates: [SubscriptionDetector.Candidate] {
        let since = AppCalendar.calendar.date(byAdding: .month, value: -6, to: .now) ?? .now
        let payments = transactions
            .filter { $0.type == .expense && $0.date >= since && !$0.isRecurring }
            .map { SubscriptionDetector.Payment(key: SubscriptionDetector.key(merchant: $0.merchant, note: $0.note), title: $0.merchant.isEmpty ? $0.note : $0.merchant, amount: $0.amount, date: $0.date, categoryID: $0.category?.id) }
        let existing = Set(rules.map { SubscriptionDetector.key(merchant: "", note: $0.title) })
        return SubscriptionDetector.detect(payments, excluding: existing, calendar: AppCalendar.calendar)
    }

    private func row(_ rule: RecurringRule) -> some View {
        Button { editing = rule } label: {
            HStack(spacing: 12) {
                CategoryIcon(category: rule.category, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.title).font(.body.weight(.medium))
                    HStack(spacing: 4) {
                        Text(rule.nextDate.dayTitle)
                        if rule.remindDaysBefore > 0 { Image(systemName: "bell.fill") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.format(rule.amount, currency: rule.account?.currencyCode ?? settings.currencyCode)).monospacedDigit()
                    Text(rule.frequency.title.lowercased()).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func total(_ title: String, _ amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            MoneyText(amount: amount, font: .title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add(_ candidate: SubscriptionDetector.Candidate) {
        let category = candidate.categoryID.flatMap { id in transactions.first { $0.category?.id == id }?.category }
        let calendar = AppCalendar.calendar
        let rule = RecurringRule(
            title: candidate.title.capitalizedFirst,
            type: .expense,
            amount: candidate.amount,
            category: category,
            account: TransactionService.lastAccount(in: context),
            frequency: .monthly,
            dayOfMonth: candidate.dayOfMonth,
            startDate: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        )
        rule.isSubscription = true
        rule.remindDaysBefore = 1
        context.insert(rule)
        try? context.save()
        SubscriptionReminders.reschedule(in: context)
    }
}

#Preview {
    NavigationStack { SubscriptionsView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
