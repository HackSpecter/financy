import AppIntents
import SwiftUI
import WidgetKit

/// Виджет «Задачи на сегодня» с интерактивными галочками.
struct TasksWidget: Widget {
    let kind = "TasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinanceProvider()) { entry in
            TasksWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Задачи на сегодня")
        .description("Задачи и встречи из «Планов» — отмечайте прямо с экрана «Домой».")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TasksWidgetView: View {
    var snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var limit: Int {
        switch family {
        case .systemLarge: 9
        case .systemMedium: 4
        default: 4
        }
    }

    var body: some View {
        let pending = snapshot.tasks.filter { !$0.isDone }.count
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Сегодня", systemImage: "checklist").font(.caption.weight(.semibold)).foregroundStyle(.blue)
                Spacer()
                Text(pending == 0 ? "всё" : "\(pending)").font(.caption.bold()).foregroundStyle(.secondary)
            }
            if snapshot.tasks.isEmpty {
                Spacer()
                Text("Задач нет").font(.footnote).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(snapshot.tasks.prefix(limit)) { task in
                    Button(intent: ToggleTaskIntent(itemID: task.id)) {
                        HStack(spacing: 6) {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isDone ? Color.financeGreen : .secondary)
                            Text(task.title)
                                .strikethrough(task.isDone)
                                .foregroundStyle(task.isDone ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let time = task.time, family != .systemSmall {
                                Text(time.timeText).foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview(as: .systemMedium) {
    TasksWidget()
} timeline: {
    FinanceEntry(date: .now, snapshot: .placeholder)
}
