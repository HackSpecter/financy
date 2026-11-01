import SwiftUI
import WidgetKit

/// Комплекшн с лимитом дня. Читает снимок, который сохранило приложение часов.
@main
struct HisobComplicationBundle: WidgetBundle {
    var body: some Widget {
        AllowanceComplication()
    }
}

nonisolated struct ComplicationEntry: TimelineEntry, Sendable {
    var date: Date
    var snapshot: WatchSnapshot
}

nonisolated struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        var sample = WatchSnapshot.empty
        sample.leftToday = 420
        sample.dailyLimit = 560
        sample.spentToday = 140
        sample.hasBudget = true
        return ComplicationEntry(date: .now, snapshot: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ComplicationEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : ComplicationEntry(date: .now, snapshot: load()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: .now, snapshot: load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }

    private func load() -> WatchSnapshot {
        let defaults = UserDefaults(suiteName: "group.tj.khalid.hisob") ?? .standard
        guard let data = defaults.data(forKey: WatchSnapshot.storageKey), let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}

struct AllowanceComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AllowanceComplication", provider: ComplicationProvider()) { entry in
            AllowanceComplicationView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Можно потратить")
        .description("Остаток дневного лимита.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct AllowanceComplicationView: View {
    var snapshot: WatchSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let left = WatchFormat.number(max(snapshot.leftToday, 0))
        let progress = snapshot.dailyLimit > 0 ? min(max(NSDecimalNumber(decimal: snapshot.spentToday / snapshot.dailyLimit).doubleValue, 0), 1) : 1
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("Можно сегодня").font(.caption2).widgetAccentable()
                Text("\(left) \(snapshot.currency)").font(.system(.title3, design: .rounded).bold())
                Gauge(value: 1 - progress) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
            }
        case .accessoryInline:
            Text("Можно: \(left) \(snapshot.currency)")
        case .accessoryCorner:
            Text(left)
                .font(.system(.title3, design: .rounded).bold())
                .widgetLabel { Gauge(value: 1 - progress) { Text("Khalid Finance") }.tint(WatchFormat.statusColor(snapshot.statusRaw)) }
        default:
            Gauge(value: 1 - progress) {
                Image(systemName: "creditcard")
            } currentValueLabel: {
                Text(left).font(.system(.caption, design: .rounded).bold()).minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(WatchFormat.statusColor(snapshot.statusRaw))
        }
    }
}
