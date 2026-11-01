import Foundation
import SwiftData

/// Действия над задачами — общие для приложения и интерактивного виджета.
enum PlannerService {
    static func toggle(_ item: PlannerItem, in context: ModelContext) {
        item.isDone.toggle()
        item.doneAt = item.isDone ? .now : nil
        if item.isDone { NotificationService.cancelPlannerReminder(id: item.id) }
        try? context.save()
        WidgetRefresher.reload()
    }

    static func move(_ item: PlannerItem, to date: Date, in context: ModelContext) {
        let calendar = AppCalendar.calendar
        let newDay = calendar.startOfDay(for: date)
        let shift = calendar.daysBetween(item.date, newDay)
        item.date = newDay
        if let time = item.time { item.time = calendar.date(byAdding: .day, value: shift, to: time) }
        if let reminder = item.reminder { item.reminder = calendar.date(byAdding: .day, value: shift, to: reminder) }
        try? context.save()
        scheduleReminder(for: item)
        WidgetRefresher.reload()
    }

    static func delete(_ item: PlannerItem, in context: ModelContext) {
        NotificationService.cancelPlannerReminder(id: item.id)
        context.delete(item)
        try? context.save()
        WidgetRefresher.reload()
    }

    static func scheduleReminder(for item: PlannerItem) {
        let id = item.id
        let title = item.title
        guard let reminder = item.reminder, !item.isDone else {
            NotificationService.cancelPlannerReminder(id: id)
            return
        }
        Task { await NotificationService.schedulePlannerReminder(id: id, title: title, at: reminder) }
    }

    static func todayItems(in context: ModelContext, now: Date = .now) -> [PlannerItem] {
        let day = AppCalendar.calendar.dayInterval(for: now)
        let start = day.start
        let end = day.end
        let items = (try? context.fetch(FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        let order = PlannerLogic.sorted(items.map(\.snapshot)).map(\.id)
        return items.sorted { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
    }
}
