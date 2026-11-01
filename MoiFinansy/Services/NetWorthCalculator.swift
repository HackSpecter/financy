import Foundation

/// Капитал: счета + копилки + мне должны − я должен, и его история по месяцам.
nonisolated enum NetWorthCalculator {
    struct Movement: Sendable {
        var date: Date
        /// Изменение капитала в базовой валюте.
        var delta: Decimal
    }

    struct Point: Sendable, Identifiable, Equatable {
        var month: Date
        var value: Decimal
        var id: Date { month }
    }

    struct Breakdown: Sendable, Equatable {
        var accounts: Decimal
        var savings: Decimal
        var owedToMe: Decimal
        var iOwe: Decimal
        var total: Decimal { accounts + savings + owedToMe - iOwe }
    }

    /// Значение на конец каждого из последних `months` месяцев.
    /// `start` — капитал до всех движений (начальные остатки счетов).
    static func history(start: Decimal, movements: [Movement], months: Int, now: Date, calendar: Calendar) -> [Point] {
        let sorted = movements.sorted { $0.date < $1.date }
        let currentMonth = calendar.startOfMonth(for: now)
        return (0..<months).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: currentMonth) else { return nil }
            let end = min(calendar.endOfMonth(for: month), now)
            let value = start + sorted.filter { $0.date < end || $0.date == end }.sum(\.delta)
            return Point(month: month, value: value)
        }
    }
}
