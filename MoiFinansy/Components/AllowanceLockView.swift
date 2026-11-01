import SwiftUI
import WidgetKit

/// «Сегодня можно» для экрана блокировки — та же сетка, что у «Аята»:
/// мелкий заголовок капсом сверху, ниже сумма крупно и тонкая полоска дневного лимита.
struct AllowanceLockView: View {
    var left: Decimal
    var dailyLimit: Decimal
    var spent: Decimal
    var currency: String
    var hasBudget = true

    var body: some View {
        VStack(alignment: .leading, spacing: AyahLayout.lockSpacing) {
            Text("СЕГОДНЯ МОЖНО")
                .font(.system(size: AyahLayout.lockTitleSize, weight: .regular))
                .tracking(AyahLayout.lockTitleSize * 0.16)
                .lineLimit(1)
                .opacity(0.72)
            if hasBudget {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Money.formatNumber(max(left, 0).rounded(0), maxFraction: 0))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                    Text(currency)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .opacity(0.72)
                }
                .lineLimit(1)
                // Тонкая полоска цветом текста виджета — читается в любом режиме экрана блокировки.
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.tertiary)
                        Capsule().fill(.primary).frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 3)
                .widgetAccentable()
                Text("потрачено \(Money.formatNumber(spent.rounded(0), maxFraction: 0)) из \(Money.formatNumber(dailyLimit.rounded(0), maxFraction: 0))")
                    .font(.system(size: AyahLayout.lockTitleSize + 1))
                    .monospacedDigit()
                    .opacity(0.72)
                    .lineLimit(1)
                    .padding(.top, 1)
            } else {
                Text("Задайте бюджет в приложении")
                    .font(.system(size: 12))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    /// Доля оставшегося лимита.
    private var progress: Double {
        guard dailyLimit > 0 else { return 0 }
        return min(max(((dailyLimit - spent) / dailyLimit).chartValue, 0), 1)
    }
}

#Preview {
    AllowanceLockView(left: 532, dailyLimit: 795, spent: 263, currency: "TJS")
        .frame(width: 172, height: 76)
        .padding()
        .background(.black)
        .foregroundStyle(.white)
}
