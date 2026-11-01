import SwiftUI

/// Строка задачи с анимированной галочкой.
struct PlannerCheckRow: View {
    var item: PlannerItem
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isDone ? AnyShapeStyle(Theme.positive) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: item.isDone)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: item.isDone) { _, done in done }
            .accessibilityLabel(item.isDone ? "Отметить невыполненной" : "Отметить выполненной")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                if item.time != nil || item.priority != .none || item.type == .meeting {
                    HStack(spacing: 6) {
                        if item.type == .meeting { Image(systemName: item.type.symbol) }
                        if let time = item.time { Text(time.timeText) }
                        if item.priority != .none {
                            Text(item.priority.marks).foregroundStyle(Theme.caution).bold()
                        }
                        if item.reminder != nil { Image(systemName: "bell.fill") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(item.isDone ? .isSelected : [])
    }
}

#Preview {
    let item = PlannerItem(title: "Встреча с клиентом", type: .meeting, date: .now, time: .now, priority: .high)
    return List { PlannerCheckRow(item: item) { item.isDone.toggle() } }
}
