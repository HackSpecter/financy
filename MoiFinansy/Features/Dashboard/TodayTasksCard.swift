import SwiftData
import SwiftUI

/// Компактный блок сегодняшних задач с галочками.
struct TodayTasksCard: View {
    var now: Date
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query private var items: [PlannerItem]

    init(now: Date) {
        self.now = now
        let day = AppCalendar.calendar.dayInterval(for: now)
        let start = day.start
        let end = day.end
        _items = Query(filter: #Predicate<PlannerItem> { $0.date >= start && $0.date < end })
    }

    var body: some View {
        let sorted = PlannerLogic.sorted(items.map(\.snapshot)).compactMap { snapshot in items.first { $0.id == snapshot.id } }
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Сегодня в планах", symbol: "checklist", tint: .blue) {
                Button("Планы") { router.selectedTab = .planner }.font(.subheadline)
            }
            if sorted.isEmpty {
                Text("На сегодня задач нет").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(sorted.prefix(5)) { item in
                PlannerCheckRow(item: item) {
                    withAnimation(.spring) { PlannerService.toggle(item, in: context) }
                }
            }
        }
        .card()
    }
}

#Preview {
    TodayTasksCard(now: .now)
        .cardPreview()
        .environment(AppRouter.shared)
        .modelContainer(DemoData.previewContainer)
}
