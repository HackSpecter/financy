import SwiftUI

/// Сумма с округлым шрифтом, моноширинными цифрами и анимацией смены числа.
struct MoneyText: View {
    var amount: Decimal
    var type: TransactionType? = nil
    /// nil — базовая валюта из настроек.
    var currency: String? = nil
    var font: Font = .body
    var weight: Font.Weight = .semibold
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let hidden = settings.amountsHidden
        Text(text(masked: false))
            .blur(radius: hidden ? 8 : 0)
            .onTapGesture { if hidden { settings.revealAmounts() } }
            .accessibilityLabel(hidden ? "Сумма скрыта" : text(masked: false))
            .font(font)
            .fontWeight(weight)
            .fontDesign(.rounded)
            .monospacedDigit()
            .contentTransition(.numericText(value: amount.chartValue))
            .foregroundStyle(color)
            .animation(.snappy, value: amount)
    }

    private func text(masked: Bool) -> String {
        let formatted = Money.format(abs(amount), currency: currency ?? settings.currencyCode, ignoresPrivacy: !masked)
        switch type {
        case .expense: return "−" + formatted
        case .income: return "+" + formatted
        case .adjustment: return (amount < 0 ? "−" : "+") + formatted
        default: return amount < 0 ? "−" + formatted : formatted
        }
    }

    private var color: Color {
        type == .income ? Theme.positive : .primary
    }
}

#Preview {
    VStack(spacing: 12) {
        MoneyText(amount: Decimal(string: "1250.5")!, font: .largeTitle)
        MoneyText(amount: 45, type: .expense)
        MoneyText(amount: 25_000, type: .income)
    }
    .environment(AppSettings.shared)
}
