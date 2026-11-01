import Foundation

/// Подписки: пересчёт в месяц/год и автопоиск повторяющихся платежей в истории.
nonisolated enum SubscriptionDetector {
    struct Payment: Sendable {
        var key: String
        var title: String
        var amount: Decimal
        var date: Date
        var categoryID: UUID?
    }

    struct Candidate: Sendable, Identifiable, Equatable {
        var title: String
        var amount: Decimal
        var dayOfMonth: Int
        var months: Int
        var categoryID: UUID?
        var id: String { title }
    }

    /// Платёж, похожий на подписку: ≥3 разных месяца, суммы ±10%, число месяца стабильно (разброс ≤ 6 дней).
    static func detect(_ payments: [Payment], excluding existing: Set<String>, calendar: Calendar) -> [Candidate] {
        Dictionary(grouping: payments.filter { !$0.key.isEmpty && !existing.contains($0.key) }, by: \.key)
            .compactMap { _, items -> Candidate? in
                let months = Set(items.map { calendar.startOfMonth(for: $0.date) })
                guard months.count >= 3 else { return nil }
                let amounts = items.map(\.amount).sorted()
                let median = amounts[amounts.count / 2]
                guard median > 0, amounts.allSatisfy({ abs($0 - median) <= median * Decimal(string: "0.1")! }) else { return nil }
                let days = items.map { calendar.component(.day, from: $0.date) }.sorted()
                guard let first = days.first, let last = days.last, last - first <= 6 else { return nil }
                return Candidate(title: items[0].title, amount: median, dayOfMonth: days[days.count / 2], months: months.count, categoryID: items.last?.categoryID)
            }
            .sorted { $0.amount > $1.amount }
    }

    /// Ключ группировки: нормализованный магазин или заметка.
    static func key(merchant: String, note: String) -> String {
        let source = merchant.isEmpty ? note : merchant
        return MerchantRuleService.normalizeKey(source)
    }

    static func monthlyEquivalent(_ amount: Decimal, frequency: RecurrenceFrequency) -> Decimal {
        switch frequency {
        case .daily: amount * 30
        case .weekly: (amount * 52 / 12).rounded(2)
        case .monthly: amount
        case .yearly: (amount / 12).rounded(2)
        }
    }
}

/// Прогноз денежного потока по дням до конца месяца.
nonisolated enum CashFlowCalculator {
    struct Day: Sendable, Identifiable, Equatable {
        var date: Date
        var expense: Decimal
        var income: Decimal
        var scheduled: [ScheduledPayment]
        /// Баланс на конец дня: факт для прошлого, прогноз для будущего.
        var balance: Decimal?
        var isForecast: Bool
        var id: Date { date }
    }

    /// - Parameters:
    ///   - balanceNow: текущий общий баланс (база).
    ///   - dailySpend: средние необязательные траты в день.
    ///   - spentToday: уже потрачено сегодня.
    static func month(
        of date: Date,
        entries: [MoneyEntry],
        scheduled: [ScheduledPayment],
        balanceNow: Decimal,
        dailySpend: Decimal,
        spentToday: Decimal,
        now: Date,
        calendar: Calendar
    ) -> [Day] {
        let interval = calendar.monthInterval(for: date)
        let today = calendar.startOfDay(for: now)
        let byDay = Dictionary(grouping: entries.filter { interval.contains($0.date) }) { calendar.startOfDay(for: $0.date) }
        let scheduledByDay = Dictionary(grouping: scheduled.filter { interval.contains($0.date) }) { calendar.startOfDay(for: $0.date) }

        var running = balanceNow
        var result: [Day] = []
        var day = interval.start
        while day < interval.end {
            let items = byDay[day] ?? []
            let planned = scheduledByDay[day] ?? []
            var balance: Decimal?
            let isForecast = day > today
            if day == today {
                running -= max(dailySpend - spentToday, 0)
                running += planned.filter { $0.type == .income }.sum(\.amount) - planned.filter { $0.type == .expense }.sum(\.amount)
                balance = running
            } else if isForecast {
                running -= dailySpend
                running += planned.filter { $0.type == .income }.sum(\.amount) - planned.filter { $0.type == .expense }.sum(\.amount)
                balance = running
            }
            result.append(Day(
                date: day,
                expense: items.filter { $0.type == .expense }.sum(\.amount),
                income: items.filter { $0.type == .income }.sum(\.amount),
                scheduled: planned,
                balance: balance,
                isForecast: isForecast
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
}
