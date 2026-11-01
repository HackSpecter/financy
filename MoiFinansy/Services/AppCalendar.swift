import Foundation

/// Единый календарь приложения: календарь пользователя, но часовой пояс — Asia/Dushanbe.
nonisolated enum AppCalendar {
    static let timeZone = TimeZone(identifier: "Asia/Dushanbe") ?? .current
    static let locale = Locale(identifier: "ru_RU")

    static var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        calendar.locale = locale
        return calendar
    }
}

nonisolated extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    func endOfMonth(for date: Date) -> Date {
        self.date(byAdding: .month, value: 1, to: startOfMonth(for: date)) ?? date
    }

    func monthInterval(for date: Date) -> DateInterval {
        DateInterval(start: startOfMonth(for: date), end: endOfMonth(for: date))
    }

    func dayInterval(for date: Date) -> DateInterval {
        let start = startOfDay(for: date)
        return DateInterval(start: start, end: self.date(byAdding: .day, value: 1, to: start) ?? start)
    }

    func numberOfDays(inMonthOf date: Date) -> Int {
        range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// Количество календарных дней между началами дней (полуинтервал).
    func daysBetween(_ start: Date, _ end: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: start), to: startOfDay(for: end)).day ?? 0
    }

    func isWeekend(_ date: Date) -> Bool {
        isDateInWeekend(date)
    }
}

nonisolated extension Date {
    /// Форматирование дат в часовом поясе приложения.
    func appFormatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppCalendar.locale
        formatter.timeZone = AppCalendar.timeZone
        formatter.calendar = AppCalendar.calendar
        formatter.setLocalizedDateFormatFromTemplate(format)
        return formatter.string(from: self)
    }

    var dayTitle: String {
        let calendar = AppCalendar.calendar
        if calendar.isDateInToday(self) { return "Сегодня" }
        if calendar.isDateInYesterday(self) { return "Вчера" }
        if calendar.isDateInTomorrow(self) { return "Завтра" }
        let sameYear = calendar.isDate(self, equalTo: .now, toGranularity: .year)
        return appFormatted(sameYear ? "EEEEdMMMM" : "dMMMMyyyy").capitalizedFirst
    }

    var timeText: String { appFormatted("HHmm") }
}

nonisolated extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }

    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
