import SwiftUI

/// Горизонтальная полоска-календарь на неделю со свайпом между неделями.
struct WeekStrip: View {
    @Binding var selectedDay: Date
    var markedDays: Set<Date>
    @Namespace private var selection

    var body: some View {
        let calendar = AppCalendar.calendar
        let days = PlannerLogic.week(containing: selectedDay, calendar: calendar)
        VStack(spacing: 8) {
            HStack {
                Text(selectedDay.appFormatted("LLLLyyyy").capitalizedFirst)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Предыдущая неделя", systemImage: "chevron.left") { shift(-7) }
                    .labelStyle(.iconOnly)
                Button("Следующая неделя", systemImage: "chevron.right") { shift(7) }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 4)

            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    dayCell(day, calendar: calendar)
                }
            }
        }
        .padding(.vertical, 8)
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                shift(value.translation.width < 0 ? 7 : -7)
            }
        )
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    private func dayCell(_ day: Date, calendar: Calendar) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        return Button {
            withAnimation(.snappy) { selectedDay = day }
        } label: {
            VStack(spacing: 4) {
                Text(day.appFormatted("EEEEEE").capitalizedFirst)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text("\(calendar.component(.day, from: day))")
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundStyle(isSelected ? .white : isToday ? Color.accentColor : .primary)
                Circle()
                    .fill(markedDays.contains(day) ? (isSelected ? Color.white : Color.accentColor) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.gradient)
                        .matchedGeometryEffect(id: "selected", in: selection)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.dayTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func shift(_ days: Int) {
        withAnimation(.snappy) {
            selectedDay = AppCalendar.calendar.date(byAdding: .day, value: days, to: selectedDay) ?? selectedDay
        }
    }
}

#Preview {
    @Previewable @State var day = Date.now
    WeekStrip(selectedDay: $day, markedDays: [])
        .padding()
}
