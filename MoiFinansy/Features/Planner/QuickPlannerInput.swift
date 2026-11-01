import SwiftData
import SwiftUI

/// Быстрое добавление одной строкой на стеклянной панели.
struct QuickPlannerInput: View {
    var day: Date
    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var addedCount = 0
    @FocusState private var focused: Bool
    @Namespace private var glass

    var body: some View {
        let parsed = PlannerQuickParse(text)
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: parsed.type.symbol)
                        .foregroundStyle(.secondary)
                        .contentTransition(.symbolEffect(.replace))
                    TextField("Задача или «встреча 15:30»", text: $text)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID("field", in: glass)

                if !parsed.title.isEmpty {
                    Button(action: add) {
                        Image(systemName: "arrow.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
                    .glassEffectID("send", in: glass)
                    .accessibilityLabel("Добавить")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .sensoryFeedback(.success, trigger: addedCount)
        .animation(.spring(duration: 0.35), value: parsed.title.isEmpty)
    }

    private func add() {
        let parsed = PlannerQuickParse(text)
        guard !parsed.title.isEmpty else { return }
        let calendar = AppCalendar.calendar
        let date = calendar.date(byAdding: .day, value: parsed.dayOffset, to: day) ?? day
        var time: Date?
        if let hour = parsed.hour {
            time = calendar.date(byAdding: .minute, value: hour * 60 + (parsed.minute ?? 0), to: calendar.startOfDay(for: date))
        }
        let item = PlannerItem(title: parsed.title, type: parsed.type, date: date, time: time, priority: parsed.priority)
        if let time { item.reminder = time.addingTimeInterval(-15 * 60) }
        withAnimation(.spring) { context.insert(item) }
        try? context.save()
        if item.reminder != nil {
            Task {
                await NotificationService.requestAuthorization()
                PlannerService.scheduleReminder(for: item)
            }
        }
        WidgetRefresher.reload()
        text = ""
        addedCount += 1
    }
}

#Preview {
    VStack {
        Spacer()
        QuickPlannerInput(day: .now)
    }
    .modelContainer(DataStore.makeContainer(inMemory: true))
}
