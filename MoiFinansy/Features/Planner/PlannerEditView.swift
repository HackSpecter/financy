import SwiftData
import SwiftUI

struct PlannerEditView: View {
    @Bindable var item: PlannerItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $item.title)
                    Picker("Тип", selection: $item.type) {
                        ForEach(PlannerItemType.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    DatePicker("День", selection: dayBinding, displayedComponents: .date)
                    Toggle("Время", isOn: hasTime.animation())
                    if let time = item.time {
                        DatePicker("Начало", selection: Binding(get: { time }, set: { item.time = $0 }), displayedComponents: .hourAndMinute)
                    }
                    Picker("Приоритет", selection: $item.priority) {
                        ForEach(PlannerPriority.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    Toggle("Напоминание", isOn: hasReminder.animation())
                    if let reminder = item.reminder {
                        DatePicker("Когда", selection: Binding(get: { reminder }, set: { item.reminder = $0 }))
                    }
                }
                Section("Заметка") {
                    TextField("Заметка", text: $item.note, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Button("Перенести на завтра", systemImage: "arrow.turn.up.right") {
                        PlannerService.move(item, to: AppCalendar.calendar.date(byAdding: .day, value: 1, to: .now) ?? .now, in: context)
                        dismiss()
                    }
                    Button("Удалить", systemImage: "trash", role: .destructive) {
                        PlannerService.delete(item, in: context)
                        dismiss()
                    }
                }
            }
            .themedBackground()
            .navigationTitle(item.type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", systemImage: "checkmark") {
                        try? context.save()
                        if item.reminder != nil {
                            Task { await NotificationService.requestAuthorization() }
                        }
                        PlannerService.scheduleReminder(for: item)
                        WidgetRefresher.reload()
                        dismiss()
                    }
                }
            }
        }
    }

    private var dayBinding: Binding<Date> {
        Binding(get: { item.date }, set: { item.date = AppCalendar.calendar.startOfDay(for: $0) })
    }

    private var hasTime: Binding<Bool> {
        Binding(
            get: { item.time != nil },
            set: { item.time = $0 ? AppCalendar.calendar.date(byAdding: .hour, value: 12, to: item.date) : nil }
        )
    }

    private var hasReminder: Binding<Bool> {
        Binding(
            get: { item.reminder != nil },
            set: { item.reminder = $0 ? (item.time?.addingTimeInterval(-15 * 60) ?? AppCalendar.calendar.date(byAdding: .hour, value: 9, to: item.date)) : nil }
        )
    }
}

#Preview {
    let container = DemoData.previewContainer
    let item = try! container.mainContext.fetch(FetchDescriptor<PlannerItem>()).first!
    return PlannerEditView(item: item).modelContainer(container)
}
