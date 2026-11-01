import SwiftUI
import WidgetKit

/// Цели накопления.
struct GoalsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GoalsWidget", provider: FinanceProvider()) { entry in
            GoalsWidgetView(snapshot: entry.snapshot).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Цели накопления")
        .description("Сколько накоплено на каждую цель.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GoalsWidgetView: View {
    var snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Цели", systemImage: "target").font(.caption.weight(.semibold)).foregroundStyle(.orange)
            if snapshot.goals.isEmpty {
                Spacer()
                Text("Добавьте цель в «Накоплениях»").font(.footnote).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(snapshot.goals.prefix(family == .systemSmall ? 2 : 3)) { goal in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Image(systemName: goal.symbol).foregroundStyle(Color(hex: goal.colorHex))
                            Text(goal.name).lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(Int(goal.fraction * 100))%").fontWeight(.semibold)
                        }
                        .font(.caption)
                        ProgressView(value: goal.fraction).tint(Color(hex: goal.colorHex))
                        if family != .systemSmall {
                            Text("\(Money.format(goal.saved, currency: snapshot.currency)) из \(Money.format(goal.target, currency: snapshot.currency))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Долги.
struct DebtsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DebtsWidget", provider: FinanceProvider()) { entry in
            DebtsWidgetView(snapshot: entry.snapshot).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Долги")
        .description("Сколько должны вам и сколько должны вы.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct DebtsWidgetView: View {
    var snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryRectangular {
            VStack(alignment: .leading) {
                Text("Долги").font(.caption2.weight(.semibold)).widgetAccentable()
                Text("Мне: \(Money.compact(snapshot.owedToMe))").font(.caption)
                Text("Я: \(Money.compact(snapshot.iOwe))").font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Долги", systemImage: "person.2.fill").font(.caption.weight(.semibold)).foregroundStyle(.purple)
                Spacer(minLength: 0)
                Text("Мне должны").font(.caption2).foregroundStyle(Color.financeGreen)
                Text(Money.format(snapshot.owedToMe.rounded(0), currency: snapshot.currency))
                    .font(.system(.headline, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                Text("Я должен").font(.caption2).foregroundStyle(.red)
                Text(Money.format(snapshot.iOwe.rounded(0), currency: snapshot.currency))
                    .font(.system(.headline, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
            }
        }
    }
}

/// Ближайшие подписки и обязательные платежи.
struct SubscriptionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SubscriptionsWidget", provider: FinanceProvider()) { entry in
            SubscriptionsWidgetView(snapshot: entry.snapshot).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ближайшие платежи")
        .description("Подписки и обязательные платежи на ближайшие дни.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SubscriptionsWidgetView: View {
    var snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Платежи", systemImage: "repeat.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(.indigo)
            if snapshot.subscriptions.isEmpty {
                Spacer()
                Text("Нет запланированных платежей").font(.footnote).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(snapshot.subscriptions.prefix(family == .systemSmall ? 3 : 4)) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.symbol).foregroundStyle(Color(hex: item.colorHex)).frame(width: 16)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.title).lineLimit(1)
                            Text(item.date.dayTitle).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 2)
                        Text(Money.compact(item.amount)).fontWeight(.semibold).monospacedDigit()
                    }
                    .font(.caption)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Капитал.
struct NetWorthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NetWorthWidget", provider: FinanceProvider()) { entry in
            NetWorthWidgetView(snapshot: entry.snapshot).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Капитал")
        .description("Счета + копилки + долги вам − ваши долги.")
        .supportedFamilies([.systemSmall, .accessoryInline])
    }
}

struct NetWorthWidgetView: View {
    var snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryInline {
            Label("Капитал \(Money.compact(snapshot.netWorth))", systemImage: "chart.line.uptrend.xyaxis")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Капитал", systemImage: "chart.line.uptrend.xyaxis").font(.caption.weight(.semibold)).foregroundStyle(Color.financeGreen)
                Spacer(minLength: 0)
                Text(Money.formatNumber(snapshot.netWorth.rounded(0)))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text(snapshot.currency).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("счета \(Money.compact(snapshot.accountsTotal)) · копилки \(Money.compact(snapshot.savingsTotal))")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}

#Preview(as: .systemMedium) { GoalsWidget() } timeline: { FinanceEntry(date: .now, snapshot: .placeholder) }
#Preview(as: .systemSmall) { DebtsWidget() } timeline: { FinanceEntry(date: .now, snapshot: .placeholder) }
#Preview(as: .systemMedium) { SubscriptionsWidget() } timeline: { FinanceEntry(date: .now, snapshot: .placeholder) }
#Preview(as: .systemSmall) { NetWorthWidget() } timeline: { FinanceEntry(date: .now, snapshot: .placeholder) }
