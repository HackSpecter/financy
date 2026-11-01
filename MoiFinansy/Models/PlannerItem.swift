import Foundation
import SwiftData

@Model
final class PlannerItem {
    var id: UUID = UUID()
    var title: String = ""
    var typeRaw: String = PlannerItemType.task.rawValue
    /// Начало дня, к которому относится задача.
    var date: Date = Date.now
    /// Время встречи (опционально).
    var time: Date?
    var note: String = ""
    var isDone: Bool = false
    var doneAt: Date?
    var reminder: Date?
    var priorityRaw: Int = PlannerPriority.none.rawValue
    var createdAt: Date = Date.now

    var type: PlannerItemType {
        get { PlannerItemType(rawValue: typeRaw) ?? .task }
        set { typeRaw = newValue.rawValue }
    }

    var priority: PlannerPriority {
        get { PlannerPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    init(
        title: String,
        type: PlannerItemType = .task,
        date: Date,
        time: Date? = nil,
        note: String = "",
        priority: PlannerPriority = .none,
        reminder: Date? = nil
    ) {
        self.title = title
        self.typeRaw = type.rawValue
        self.date = AppCalendar.calendar.startOfDay(for: date)
        self.time = time
        self.note = note
        self.priorityRaw = priority.rawValue
        self.reminder = reminder
        self.createdAt = .now
    }

    var snapshot: PlannerSnapshot {
        PlannerSnapshot(id: id, title: title, date: date, time: time, isDone: isDone, priority: priority, createdAt: createdAt)
    }
}
