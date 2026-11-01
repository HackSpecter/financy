import Foundation

nonisolated enum PlannerLogic {
    /// Невыполненные сначала (по времени, затем приоритету), выполненные — внизу.
    static func sorted(_ items: [PlannerSnapshot]) -> [PlannerSnapshot] {
        items.sorted { lhs, rhs in
            if lhs.isDone != rhs.isDone { return !lhs.isDone }
            switch (lhs.time, rhs.time) {
            case let (l?, r?) where l != r: return l < r
            case (.some, nil): return true
            case (nil, .some): return false
            default: break
            }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// Невыполненные задачи прошлых дней.
    static func overdue(_ items: [PlannerSnapshot], now: Date, calendar: Calendar) -> [PlannerSnapshot] {
        let today = calendar.startOfDay(for: now)
        return items.filter { !$0.isDone && $0.date < today }
    }

    /// Дни для полоски-календаря: неделя, содержащая дату.
    static func week(containing date: Date, calendar: Calendar) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [date] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }
}

/// Разбор быстрой строки: «Встреча с Али завтра в 15:30 !!».
nonisolated struct PlannerQuickParse: Equatable, Sendable {
    var title: String
    var dayOffset: Int
    var hour: Int?
    var minute: Int?
    var priority: PlannerPriority

    var type: PlannerItemType { hour == nil ? .task : .meeting }

    init(_ text: String) {
        var words = text.split(separator: " ").map(String.init)
        dayOffset = 0
        hour = nil
        minute = nil
        priority = .none

        if let index = words.lastIndex(where: { $0.allSatisfy { $0 == "!" } && !$0.isEmpty }) {
            priority = PlannerPriority(rawValue: min(words[index].count, 3)) ?? .none
            words.remove(at: index)
        }
        if let index = words.firstIndex(where: { $0.lowercased() == "завтра" }) {
            dayOffset = 1
            words.remove(at: index)
        } else if let index = words.firstIndex(where: { $0.lowercased() == "послезавтра" }) {
            dayOffset = 2
            words.remove(at: index)
        }
        if let index = words.lastIndex(where: { Self.time(from: $0) != nil }), let time = Self.time(from: words[index]) {
            hour = time.0
            minute = time.1
            words.remove(at: index)
            if index > 0, ["в", "к"].contains(words[index - 1].lowercased()) { words.remove(at: index - 1) }
        }
        title = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    private static func time(from word: String) -> (Int, Int)? {
        let parts = word.split(whereSeparator: { $0 == ":" || $0 == "." })
        guard parts.count == 2, parts[1].count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0..<24).contains(h), (0..<60).contains(m) else {
            return nil
        }
        return (h, m)
    }
}
