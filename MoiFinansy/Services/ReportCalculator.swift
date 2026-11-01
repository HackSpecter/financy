import Foundation

/// Агрегаты для экрана отчётов. Чистые функции над `MoneyEntry`.
nonisolated enum ReportCalculator {
    nonisolated struct CategoryTotal: Sendable, Hashable, Identifiable {
        var categoryID: UUID?
        var amount: Decimal
        var share: Decimal
        var count: Int
        var id: String { categoryID?.uuidString ?? "none" }
    }

    nonisolated struct DayTotal: Sendable, Hashable, Identifiable {
        var date: Date
        var amount: Decimal
        var id: Date { date }
    }

    nonisolated struct MonthTotal: Sendable, Hashable, Identifiable {
        var month: Date
        var income: Decimal
        var expense: Decimal
        var id: Date { month }
        var savings: Decimal { income - expense }
    }

    nonisolated struct CategoryComparison: Sendable, Hashable, Identifiable {
        var categoryID: UUID?
        var current: Decimal
        var previous: Decimal
        var id: String { categoryID?.uuidString ?? "none" }
        var delta: Decimal { current - previous }
        /// nil, если в прошлом периоде трат не было.
        var change: Decimal? {
            guard previous > 0 else { return nil }
            return (current - previous) / previous
        }
    }

    nonisolated struct Summary: Sendable, Equatable {
        var income: Decimal
        var expense: Decimal
        var averagePerDay: Decimal
        var maxDay: DayTotal?
        var savingsRate: Decimal?
        var weekendAverage: Decimal
        var weekdayAverage: Decimal
        var balance: Decimal { income - expense }
    }

    static func expenses(_ entries: [MoneyEntry], in interval: DateInterval) -> [MoneyEntry] {
        entries.filter { $0.type == .expense && interval.contains($0.date) }
    }

    static func byCategory(_ entries: [MoneyEntry], in interval: DateInterval) -> [CategoryTotal] {
        let expenses = expenses(entries, in: interval)
        let total = expenses.sum(\.amount)
        let grouped = Dictionary(grouping: expenses, by: \.categoryID)
        return grouped
            .map { key, items in
                let amount = items.sum(\.amount)
                return CategoryTotal(categoryID: key, amount: amount, share: total > 0 ? amount / total : 0, count: items.count)
            }
            .sorted { $0.amount > $1.amount }
    }

    /// Расход по каждому дню интервала (включая дни без трат).
    static func daily(_ entries: [MoneyEntry], in interval: DateInterval, calendar: Calendar) -> [DayTotal] {
        let expenses = expenses(entries, in: interval)
        let grouped = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
        var result: [DayTotal] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            result.append(DayTotal(date: day, amount: grouped[day]?.sum(\.amount) ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    static func monthly(_ entries: [MoneyEntry], months: Int, endingAt date: Date, calendar: Calendar) -> [MonthTotal] {
        let lastMonth = calendar.startOfMonth(for: date)
        return (0..<months).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: lastMonth) else { return nil }
            let interval = calendar.monthInterval(for: month)
            let inMonth = entries.filter { interval.contains($0.date) }
            return MonthTotal(
                month: month,
                income: inMonth.filter { $0.type == .income }.sum(\.amount),
                expense: inMonth.filter { $0.type == .expense }.sum(\.amount)
            )
        }
    }

    static func compare(current: [CategoryTotal], previous: [CategoryTotal]) -> [CategoryComparison] {
        var previousByID: [UUID?: Decimal] = [:]
        for item in previous { previousByID[item.categoryID] = item.amount }
        var result = current.map {
            CategoryComparison(categoryID: $0.categoryID, current: $0.amount, previous: previousByID.removeValue(forKey: $0.categoryID) ?? 0)
        }
        result += previousByID.map { CategoryComparison(categoryID: $0.key, current: 0, previous: $0.value) }
        return result.sorted { abs($0.delta) > abs($1.delta) }
    }

    /// Сводка. Средний расход считается по прошедшим дням периода (не дальше `now`).
    static func summary(_ entries: [MoneyEntry], in interval: DateInterval, now: Date, calendar: Calendar) -> Summary {
        let inPeriod = entries.filter { interval.contains($0.date) }
        let income = inPeriod.filter { $0.type == .income }.sum(\.amount)
        let expense = inPeriod.filter { $0.type == .expense }.sum(\.amount)

        let effectiveEnd = min(interval.end, calendar.dayInterval(for: now).end)
        let days = calendar.daily(in: DateInterval(start: interval.start, end: max(effectiveEnd, interval.start)))
        let daily = self.daily(entries, in: interval, calendar: calendar).filter { days.contains($0.date) }
        let elapsedDays = max(days.count, 1)

        let weekend = daily.filter { calendar.isWeekend($0.date) }
        let weekdays = daily.filter { !calendar.isWeekend($0.date) }

        return Summary(
            income: income,
            expense: expense,
            averagePerDay: (expense / Decimal(elapsedDays)).rounded(2),
            maxDay: daily.filter { $0.amount > 0 }.max { $0.amount < $1.amount },
            savingsRate: income > 0 ? (income - expense) / income : nil,
            weekendAverage: weekend.isEmpty ? 0 : weekend.sum(\.amount) / Decimal(weekend.count),
            weekdayAverage: weekdays.isEmpty ? 0 : weekdays.sum(\.amount) / Decimal(weekdays.count)
        )
    }

    static func largest(_ entries: [MoneyEntry], in interval: DateInterval, count: Int = 5) -> [MoneyEntry] {
        Array(expenses(entries, in: interval).sorted { $0.amount > $1.amount }.prefix(count))
    }
}

nonisolated extension Calendar {
    /// Начала всех дней интервала.
    func daily(in interval: DateInterval) -> Set<Date> {
        var result: Set<Date> = []
        var day = startOfDay(for: interval.start)
        while day < interval.end {
            result.insert(day)
            guard let next = date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
}
