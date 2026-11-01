import SwiftUI

/// Главный экран часов: можно потратить сегодня и задачи.
struct WatchHomeView: View {
    @Environment(WatchStore.self) private var store
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            TabView {
                AllowancePage { isAdding = true }
                WatchTasksView()
            }
            .tabViewStyle(.verticalPage)
            .navigationTitle("Финансы")
            .sheet(isPresented: $isAdding) { WatchAddExpenseView() }
        }
    }
}

private struct AllowancePage: View {
    var onAdd: () -> Void
    @Environment(WatchStore.self) private var store

    var body: some View {
        let snapshot = store.snapshot
        let color = WatchFormat.statusColor(snapshot.statusRaw)
        let progress = snapshot.dailyLimit > 0 ? min(max(NSDecimalNumber(decimal: snapshot.spentToday / snapshot.dailyLimit).doubleValue, 0), 1) : 1
        VStack(spacing: 6) {
            if snapshot.hasBudget {
                Gauge(value: 1 - progress) {
                    Text("Сегодня")
                } currentValueLabel: {
                    Text(WatchFormat.number(max(snapshot.leftToday, 0)))
                        .font(.system(.title3, design: .rounded).bold())
                        .minimumScaleFactor(0.5)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(color)
                .scaleEffect(1.3)
                .padding(.vertical, 8)
                Text("можно потратить, \(snapshot.currency)").font(.caption2).foregroundStyle(.secondary)
                Text("потрачено \(WatchFormat.number(snapshot.spentToday)) из \(WatchFormat.number(snapshot.dailyLimit))")
                    .font(.caption2)
                    .foregroundStyle(color)
            } else {
                Text("Откройте Khalid Finance на iPhone, чтобы задать бюджет").font(.footnote).multilineTextAlignment(.center)
            }
            Button(action: onAdd) {
                Label("Расход", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.18, green: 0.62, blue: 0.37))
        }
    }
}

#Preview {
    WatchHomeView().environment(WatchStore.shared)
}
