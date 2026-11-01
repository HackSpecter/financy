import Foundation
import SwiftData

/// Узнаёт зарплату в SMS-зачислениях: рядом с днём зарплаты (±5 дней) и не меньше половины ожидаемой суммы.
enum SalaryMatcher {
    static let window = 5
    static let minimumShare = Decimal(string: "0.5")!

    /// Правило зарплаты, к которому относится доход, или nil.
    static func rule(forIncome amount: Decimal, at date: Date, in context: ModelContext) -> RecurringRule? {
        // Правило может быть выключено (зарплата не создаётся сама) — по нему всё равно узнаём зарплату в SMS.
        let rules = ((try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []).filter { $0.type == .income }
        let calendar = AppCalendar.calendar
        return rules.first { rule in
            guard amount >= rule.amount * minimumShare else { return false }
            let from = calendar.date(byAdding: .day, value: -window, to: calendar.startOfDay(for: date)) ?? date
            let to = calendar.date(byAdding: .day, value: window + 1, to: calendar.startOfDay(for: date)) ?? date
            return !Recurrence(frequency: rule.frequency, dayOfMonth: rule.dayOfMonth, anchor: rule.startDate)
                .occurrences(from: from, to: to, calendar: calendar).isEmpty
        }
    }

    /// Запланированная (созданная правилом) «Зарплата» рядом с датой — её обновляем по SMS.
    static func plannedTransaction(for rule: RecurringRule, near date: Date, in context: ModelContext) -> Transaction? {
        let calendar = AppCalendar.calendar
        guard let from = calendar.date(byAdding: .day, value: -window, to: date),
              let to = calendar.date(byAdding: .day, value: window, to: date) else { return nil }
        let income = TransactionType.income.rawValue
        let candidates = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.typeRaw == income && $0.isRecurring && $0.date >= from && $0.date <= to
        }))) ?? []
        let sms = TransactionSource.sms.rawValue
        return candidates.first { $0.sourceRaw != sms && ($0.category?.id == rule.category?.id || $0.note == rule.title) }
    }

    /// Зарплата уже пришла по SMS рядом с датой правила — второй раз её не создаём.
    static func alreadyReceived(_ rule: RecurringRule, near date: Date, in context: ModelContext) -> Bool {
        let calendar = AppCalendar.calendar
        guard let from = calendar.date(byAdding: .day, value: -window, to: date),
              let to = calendar.date(byAdding: .day, value: window + 1, to: date) else { return false }
        let income = TransactionType.income.rawValue
        let sms = TransactionSource.sms.rawValue
        let received = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.typeRaw == income && $0.sourceRaw == sms && $0.date >= from && $0.date < to
        }))) ?? []
        return received.contains { $0.category?.id == rule.category?.id && $0.amount >= rule.amount * minimumShare }
    }
}
