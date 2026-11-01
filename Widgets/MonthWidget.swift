import AppIntents
import SwiftUI
import WidgetKit

/// Средний виджет: расход месяца + интерактивные кнопки быстрого добавления.
struct MonthWidget: Widget {
    let kind = "MonthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinanceProvider()) { entry in
            MonthWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Месяц и быстрые траты")
        .description("Расход месяца и кнопки шаблонов: один тап — расход записан.")
        .supportedFamilies([.systemMedium])
    }
}

struct MonthWidgetView: View {
    var snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Расход месяца").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(Money.format(snapshot.spentMonth.rounded(0), currency: snapshot.currency))
                    .font(.system(.title2, design: .rounded).bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                if snapshot.monthBudget > 0 {
                    ProgressView(value: snapshot.monthProgress).tint(snapshot.monthProgress >= 1 ? .red : Color.financeGreen)
                    Text("из \(Money.format(snapshot.monthBudget, currency: snapshot.currency)) · день \(snapshot.dayOfMonth)/\(snapshot.daysInMonth)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if snapshot.hasBudget {
                    HStack(spacing: 4) {
                        Circle().fill(snapshot.status.color).frame(width: 8, height: 8)
                        Text("Сегодня можно \(Money.format(max(snapshot.leftToday, 0).rounded(0), currency: snapshot.currency))")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                ForEach(snapshot.templates) { template in
                    Button(intent: AddTemplateIntent(templateID: template.id)) {
                        HStack(spacing: 6) {
                            Image(systemName: template.symbol).foregroundStyle(Color(hex: template.colorHex))
                            Text(template.title).lineLimit(1)
                            Spacer(minLength: 2)
                            Text(Money.formatNumber(template.amount)).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                    }
                    .tint(.secondary)
                }
                Button(intent: OpenQuickAddIntent()) {
                    Label("Другой расход", systemImage: "plus").font(.caption.weight(.semibold)).frame(maxWidth: .infinity)
                }
                .tint(Color.financeGreen)
            }
            .buttonStyle(.bordered)
            .frame(width: 140)
        }
    }
}

#Preview(as: .systemMedium) {
    MonthWidget()
} timeline: {
    FinanceEntry(date: .now, snapshot: .placeholder)
}
