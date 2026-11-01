import Foundation
import SwiftData

/// Автоматически создаёт регулярные операции, срок которых наступил.
enum RecurringService {
    @discardableResult
    static func processDue(in context: ModelContext, now: Date = .now, calendar: Calendar = AppCalendar.calendar) -> Int {
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.isActive }))) ?? []
        let endOfToday = calendar.dayInterval(for: now).end
        var created = 0
        for rule in rules {
            var guardCounter = 0
            while rule.nextDate < endOfToday, guardCounter < 400 {
                let date = calendar.date(byAdding: .hour, value: 9, to: calendar.startOfDay(for: rule.nextDate)) ?? rule.nextDate
                // Зарплата уже пришла по SMS — не дублируем.
                if rule.type == .income, SalaryMatcher.alreadyReceived(rule, near: date, in: context) {
                    rule.nextDate = rule.recurrence.next(after: rule.nextDate, calendar: calendar)
                    guardCounter += 1
                    continue
                }
                let transaction = Transaction(
                    type: rule.type,
                    amount: rule.amount,
                    category: rule.category,
                    account: rule.account,
                    date: date,
                    note: rule.title,
                    isRecurring: true
                )
                context.insert(transaction)
                SavingsService.handleIncome(transaction, in: context)
                rule.nextDate = rule.recurrence.next(after: rule.nextDate, calendar: calendar)
                created += 1
                guardCounter += 1
            }
        }
        if created > 0 {
            try? context.save()
            WidgetRefresher.reload()
        }
        return created
    }
}

/// Напоминания о списании подписок за N дней.
enum SubscriptionReminders {
    static func reschedule(in context: ModelContext) {
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        let calendar = AppCalendar.calendar
        for rule in rules {
            let id = "sub-\(rule.id.uuidString)"
            guard rule.isActive, rule.remindDaysBefore > 0,
                  let day = calendar.date(byAdding: .day, value: -rule.remindDaysBefore, to: rule.nextDate),
                  let date = calendar.date(byAdding: .hour, value: 10, to: calendar.startOfDay(for: day)) else {
                NotificationService.cancel(id: id)
                continue
            }
            let when = rule.remindDaysBefore == 1 ? "завтра" : "через \(rule.remindDaysBefore) дн."
            let title = "\(rule.title): списание \(when)"
            let body = Money.format(rule.amount, currency: rule.account?.currencyCode ?? SharedDefaults.currencyCode)
            Task { await NotificationService.schedule(id: id, title: title, body: body, at: date) }
        }
    }
}
