import SwiftUI
import WatchKit

/// Задачи на сегодня с галочками.
struct WatchTasksView: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        List {
            if store.snapshot.tasks.isEmpty {
                Text("На сегодня задач нет").foregroundStyle(.secondary)
            }
            ForEach(store.snapshot.tasks) { task in
                Button {
                    store.toggle(task)
                    WKInterfaceDevice.current().play(task.isDone ? .click : .success)
                } label: {
                    HStack {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isDone ? Color(red: 0.18, green: 0.62, blue: 0.37) : .secondary)
                        VStack(alignment: .leading) {
                            Text(task.title).strikethrough(task.isDone).lineLimit(2)
                            if let time = task.time {
                                Text(time, format: .dateTime.hour().minute()).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Задачи")
    }
}
