import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity и Dynamic Island: остаток на сегодня.
struct HisobLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HisobActivityAttributes.self) { context in
            LiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            let state = context.state
            let color = (BudgetCalculator.Status(rawValue: state.statusRaw) ?? .good).color
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Сегодня", systemImage: "gauge.with.dots.needle.67percent")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("норма \(Money.compact(state.dailyLimit))").font(.caption).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(Money.format(max(state.leftToday, 0).rounded(0), currency: state.currency))
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: state.progress).tint(color)
                }
            } compactLeading: {
                Image(systemName: "creditcard.fill").foregroundStyle(color)
            } compactTrailing: {
                Text(Money.compact(max(state.leftToday, 0))).font(.caption.weight(.semibold)).foregroundStyle(color)
            } minimal: {
                Text(Money.compact(max(state.leftToday, 0))).font(.caption2.weight(.bold)).foregroundStyle(color)
            }
        }
    }
}

struct LiveActivityLockScreenView: View {
    var state: HisobActivityAttributes.ContentState

    var body: some View {
        let color = (BudgetCalculator.Status(rawValue: state.statusRaw) ?? .good).color
        HStack(spacing: 14) {
            Gauge(value: 1 - state.progress) {
                Image(systemName: "creditcard.fill")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Можно потратить сегодня").font(.caption).foregroundStyle(.secondary)
                Text(Money.format(max(state.leftToday, 0).rounded(0), currency: state.currency))
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(color)
                Text("потрачено \(Money.format(state.spentToday, currency: state.currency)) из \(Money.format(state.dailyLimit.rounded(0), currency: state.currency))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}

#Preview("Экран блокировки", as: .content, using: HisobActivityAttributes()) {
    HisobLiveActivity()
} contentStates: {
    HisobActivityAttributes.ContentState(leftToday: 420, dailyLimit: 560, spentToday: 140, statusRaw: "good", currency: "TJS")
    HisobActivityAttributes.ContentState(leftToday: 40, dailyLimit: 560, spentToday: 520, statusRaw: "warning", currency: "TJS")
}
