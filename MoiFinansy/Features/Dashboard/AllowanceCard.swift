import SwiftUI

/// Главная цифра: сколько можно потратить сегодня.
struct AllowanceCard: View {
    var result: BudgetCalculator.Result?
    var onSetBudget: () -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Можно потратить сегодня")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let result {
                Text(Money.format(max(result.leftToday, 0), currency: settings.currencyCode, ignoresPrivacy: true))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: result.leftToday.chartValue))
                    .foregroundStyle(result.status.color.gradient)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .blur(radius: settings.amountsHidden ? 12 : 0)
                    .onTapGesture { if settings.amountsHidden { settings.revealAmounts() } }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .animation(.spring, value: result.leftToday)
                HStack(spacing: 6) {
                    Image(systemName: statusSymbol(result.status))
                    Text(statusText(result))
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(result.status.color)
            } else {
                Text("Задайте бюджет месяца")
                    .font(.title2.bold())
                Text("Укажите зарплату или общий лимит — и приложение посчитает дневную норму.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Задать бюджет", action: onSetBudget)
                    .buttonStyle(.glassProminent)
            }
        }
        .card(padding: 20)
        .accessibilityElement(children: .combine)
    }

    private func statusSymbol(_ status: BudgetCalculator.Status) -> String {
        switch status {
        case .good: "checkmark.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .over: "xmark.octagon.fill"
        }
    }

    private func statusText(_ result: BudgetCalculator.Result) -> String {
        let code = settings.currencyCode
        if result.leftToday < 0 {
            return "Перерасход \(Money.format(-result.leftToday, currency: code)) · норма \(Money.format(result.dailyLimit, currency: code))"
        }
        return "Потрачено \(Money.format(result.spentToday, currency: code)) из \(Money.format(result.dailyLimit, currency: code))"
    }
}

#Preview {
    VStack {
        AllowanceCard(result: nil) {}
    }
    .padding()
    .background { AmbientBackground() }
    .environment(AppSettings.shared)
}
