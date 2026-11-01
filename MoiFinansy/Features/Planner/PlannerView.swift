import SwiftData
import SwiftUI

/// Вкладка «Планы»: полоска-календарь, задачи и встречи по дням.
struct PlannerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlannerItem.date) private var items: [PlannerItem]

    @State private var selectedDay = AppCalendar.calendar.startOfDay(for: .now)
    @State private var editing: PlannerItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeekStrip(selectedDay: $selectedDay, markedDays: markedDays)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if isToday, !overdue.isEmpty {
                    Section { OverdueBanner(count: overdue.count, onMove: moveOverdue).glassRow() }
                }
                Section {
                    if dayItems.isEmpty {
                        EmptyStateView(
                            title: "Свободный день",
                            symbol: "sun.max",
                            message: "Напишите задачу внизу. Добавьте время — «15:30» — и это будет встреча."
                        )
                        .listRowBackground(Color.clear)
                    }
                    ForEach(dayItems) { item in
                        PlannerCheckRow(item: item) {
                            withAnimation(.spring(duration: 0.45)) { PlannerService.toggle(item, in: context) }
                        }
                        .onTapGesture { editing = item }
                        .glassRow()
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation { PlannerService.delete(item, in: context) }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                withAnimation { PlannerService.move(item, to: tomorrow(of: item.date), in: context) }
                            } label: {
                                Label("На завтра", systemImage: "arrow.turn.up.right")
                            }
                            .tint(Theme.accent)
                        }
                    }
                } header: {
                    Text(selectedDay.dayTitle)
                }
            }
            .themedBackground()
            .navigationTitle("Планы")
            .toolbar {
                if !isToday {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Сегодня") {
                            withAnimation(.snappy) { selectedDay = AppCalendar.calendar.startOfDay(for: .now) }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                QuickPlannerInput(day: selectedDay)
            }
            .sheet(item: $editing) { PlannerEditView(item: $0) }
            .animation(.spring(duration: 0.45), value: dayItems.map(\.isDone))
        }
    }

    private var calendar: Calendar { AppCalendar.calendar }
    private var isToday: Bool { calendar.isDateInToday(selectedDay) }

    private var dayItems: [PlannerItem] {
        let own = items.filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }
        let order = PlannerLogic.sorted(own.map(\.snapshot)).map(\.id)
        return own.sorted { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
    }

    private var overdue: [PlannerItem] {
        let ids = Set(PlannerLogic.overdue(items.map(\.snapshot), now: .now, calendar: calendar).map(\.id))
        return items.filter { ids.contains($0.id) }
    }

    private var markedDays: Set<Date> {
        Set(items.filter { !$0.isDone }.map { calendar.startOfDay(for: $0.date) })
    }

    private func tomorrow(of date: Date) -> Date {
        let base = max(calendar.startOfDay(for: date), calendar.startOfDay(for: .now))
        return calendar.date(byAdding: .day, value: 1, to: base) ?? base
    }

    private func moveOverdue() {
        withAnimation(.spring) {
            for item in overdue { PlannerService.move(item, to: .now, in: context) }
        }
    }
}

private struct OverdueBanner: View {
    var count: Int
    var onMove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.title2)
                .foregroundStyle(Theme.caution)
            VStack(alignment: .leading, spacing: 2) {
                Text("Не выполнено ранее: \(count)").font(.subheadline.weight(.semibold))
                Text("Перенести на сегодня одним тапом").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Перенести", action: onMove)
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
        }
    }
}

#Preview {
    PlannerView()
        .modelContainer(DemoData.previewContainer)
}
