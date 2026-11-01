import Foundation
import SwiftData

/// Регулярная операция: зарплата, аренда, интернет, подписки.
@Model
final class RecurringRule {
    var id: UUID = UUID()
    var title: String = ""
    var typeRaw: String = TransactionType.expense.rawValue
    var amount: Decimal = 0
    var category: Category?
    var account: Account?
    var frequencyRaw: String = RecurrenceFrequency.monthly.rawValue
    /// День месяца для ежемесячных правил (1…31, обрезается до последнего дня).
    var dayOfMonth: Int = 1
    var startDate: Date = Date.now
    /// Дата следующей автоматической операции.
    var nextDate: Date = Date.now
    var isActive: Bool = true
    /// Обязательный платёж — учитывается в «можно потратить сегодня».
    var isMandatory: Bool = true
    /// Подписка: показывается на экране подписок, напоминание за N дней.
    var isSubscription: Bool = false
    var remindDaysBefore: Int = 0

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        title: String,
        type: TransactionType,
        amount: Decimal,
        category: Category?,
        account: Account?,
        frequency: RecurrenceFrequency,
        dayOfMonth: Int,
        startDate: Date,
        isMandatory: Bool = true
    ) {
        self.title = title
        self.typeRaw = type.rawValue
        self.amount = amount
        self.category = category
        self.account = account
        self.frequencyRaw = frequency.rawValue
        self.dayOfMonth = dayOfMonth
        self.startDate = startDate
        self.isMandatory = isMandatory
        self.nextDate = Recurrence(frequency: frequency, dayOfMonth: dayOfMonth, anchor: startDate)
            .firstOccurrence(onOrAfter: startDate, calendar: AppCalendar.calendar)
    }

    var recurrence: Recurrence {
        Recurrence(frequency: frequency, dayOfMonth: dayOfMonth, anchor: startDate)
    }
}
