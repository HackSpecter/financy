import Foundation

/// Период отчёта: неделя / месяц / год / свой, со сдвигом назад-вперёд.
struct ReportPeriod: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case week, month, year, custom
        var id: String { rawValue }
        var title: String {
            switch self {
            case .week: "Неделя"
            case .month: "Месяц"
            case .year: "Год"
            case .custom: "Период"
            }
        }
    }

    var kind: Kind = .month
    /// 0 — текущий, −1 — предыдущий и т. д.
    var offset = 0
    var customStart = AppCalendar.calendar.date(byAdding: .day, value: -30, to: .now) ?? .now
    var customEnd = Date.now

    func interval(now: Date = .now, calendar: Calendar = AppCalendar.calendar) -> DateInterval {
        switch kind {
        case .week:
            let base = calendar.date(byAdding: .weekOfYear, value: offset, to: now) ?? now
            return calendar.dateInterval(of: .weekOfYear, for: base) ?? calendar.dayInterval(for: now)
        case .month:
            let base = calendar.date(byAdding: .month, value: offset, to: now) ?? now
            return calendar.monthInterval(for: base)
        case .year:
            let base = calendar.date(byAdding: .year, value: offset, to: now) ?? now
            return calendar.dateInterval(of: .year, for: base) ?? calendar.monthInterval(for: now)
        case .custom:
            let start = calendar.startOfDay(for: min(customStart, customEnd))
            return DateInterval(start: start, end: calendar.dayInterval(for: max(customStart, customEnd)).end)
        }
    }

    /// Такой же по длине предыдущий период — для сравнения.
    func previousInterval(now: Date = .now, calendar: Calendar = AppCalendar.calendar) -> DateInterval {
        switch kind {
        case .custom:
            let current = interval(now: now, calendar: calendar)
            return DateInterval(start: current.start.addingTimeInterval(-current.duration), end: current.start)
        default:
            var previous = self
            previous.offset -= 1
            return previous.interval(now: now, calendar: calendar)
        }
    }

    func title(now: Date = .now) -> String {
        let interval = interval(now: now)
        let lastDay = interval.end.addingTimeInterval(-1)
        switch kind {
        case .week:
            return "\(interval.start.appFormatted("dMMM")) – \(lastDay.appFormatted("dMMM"))"
        case .month:
            return interval.start.appFormatted("LLLLyyyy").capitalizedFirst
        case .year:
            return interval.start.appFormatted("yyyy")
        case .custom:
            return "\(interval.start.appFormatted("dMMMyy")) – \(lastDay.appFormatted("dMMMyy"))"
        }
    }

    /// Фраза для инсайтов: «в этом месяце».
    var phrase: String {
        switch kind {
        case .week: offset == 0 ? "на этой неделе" : "за неделю"
        case .month: offset == 0 ? "в этом месяце" : "за месяц"
        case .year: offset == 0 ? "в этом году" : "за год"
        case .custom: "за период"
        }
    }

    var canGoForward: Bool { kind != .custom && offset < 0 }
}
