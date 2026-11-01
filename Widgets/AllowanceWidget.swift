import SwiftUI
import WidgetKit

/// Малый виджет и виджеты экрана блокировки: «Можно потратить сегодня».
struct AllowanceWidget: Widget {
    let kind = "AllowanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinanceProvider()) { entry in
            AllowanceWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Можно потратить")
        .description("Сколько можно потратить сегодня, чтобы денег хватило до конца месяца.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct AllowanceWidgetView: View {
    var snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    private var amountText: String {
        Money.compact(max(snapshot.leftToday, 0))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Сегодня", systemImage: "gauge.with.dots.needle.67percent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if snapshot.hasBudget {
                Text("Можно потратить")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Money.formatNumber(max(snapshot.leftToday, 0).rounded(0)))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(snapshot.status.color.gradient)
                    .contentTransition(.numericText())
                Text(snapshot.currency).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ProgressView(value: snapshot.todayProgress)
                    .tint(snapshot.status.color)
            } else {
                Text("Задайте бюджет в приложении")
                    .font(.footnote.weight(.medium))
            }
        }
        .widgetAccentable()
    }

    private var circular: some View {
        Gauge(value: 1 - snapshot.todayProgress) {
            Image(systemName: "creditcard")
        } currentValueLabel: {
            Text(amountText).font(.system(.caption, design: .rounded).bold()).minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }

    private var rectangular: some View {
        AllowanceLockView(left: snapshot.leftToday, dailyLimit: snapshot.dailyLimit, spent: snapshot.spentToday, currency: snapshot.currency, hasBudget: snapshot.hasBudget)
    }

    private var inline: some View {
        Label("Можно: \(Money.format(max(snapshot.leftToday, 0).rounded(0), currency: snapshot.currency))", systemImage: "creditcard")
    }
}

#Preview(as: .systemSmall) {
    AllowanceWidget()
} timeline: {
    FinanceEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .accessoryRectangular) {
    AllowanceWidget()
} timeline: {
    FinanceEntry(date: .now, snapshot: .placeholder)
}
