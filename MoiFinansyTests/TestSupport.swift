import Foundation
@testable import MoiFinansy

enum TestCalendar {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = AppCalendar.timeZone
        calendar.locale = AppCalendar.locale
        calendar.firstWeekday = 2
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

func dec(_ string: String) -> Decimal { Decimal(string: string)! }

func expense(_ amount: Decimal, _ date: Date, category: UUID? = nil, recurring: Bool = false, note: String = "") -> MoneyEntry {
    MoneyEntry(amount: amount, date: date, type: .expense, categoryID: category, isRecurring: recurring, note: note)
}

func income(_ amount: Decimal, _ date: Date) -> MoneyEntry {
    MoneyEntry(amount: amount, date: date, type: .income)
}
