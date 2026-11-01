import Foundation

/// Форматирование и разбор денежных сумм. Только Decimal.
nonisolated enum Money {
    static let locale = Locale(identifier: "ru_RU")

    /// `1 250,50 TJS`; целые суммы без копеек: `25 000 TJS`.
    /// В режиме приватности цифры скрываются: `••• TJS`.
    static func format(_ value: Decimal, currency: String = SharedDefaults.currencyCode, showsPlus: Bool = false, ignoresPrivacy: Bool = false) -> String {
        if !ignoresPrivacy, Privacy.isMasked { return "••• \(currency)" }
        let number = formatNumber(value)
        let sign = showsPlus && value > 0 ? "+" : ""
        return "\(sign)\(number) \(currency)"
    }

    /// Компактный вид для графиков и виджетов: `3,2 тыс.`
    static func compact(_ value: Decimal) -> String {
        if Privacy.isMasked { return "•••" }
        let absolute = abs(value)
        if absolute >= 1_000_000 {
            return formatNumber((value / 1_000_000).rounded(1), maxFraction: 1) + " млн"
        }
        if absolute >= 10_000 {
            return formatNumber((value / 1000).rounded(0), maxFraction: 0) + " тыс."
        }
        if absolute >= 1000 {
            return formatNumber((value / 1000).rounded(1), maxFraction: 1) + " тыс."
        }
        return formatNumber(value.rounded(0), maxFraction: 0)
    }

    static func formatNumber(_ value: Decimal, maxFraction: Int = 2) -> String {
        let rounded = value.rounded(maxFraction)
        let fraction = rounded.isWhole ? 0 : maxFraction
        return rounded.formatted(
            .number
                .locale(locale)
                .grouping(.automatic)
                .precision(.fractionLength(fraction))
        )
    }

    /// Разбор ввода пользователя: «1250,5», «1 250.50».
    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func percent(_ value: Decimal) -> String {
        "\(NSDecimalNumber(decimal: (value * 100).rounded(0)).intValue)%"
    }
}

nonisolated extension Decimal {
    func rounded(_ scale: Int, _ mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }

    var isWhole: Bool { self == rounded(0, .down) }

    var intValue: Int { NSDecimalNumber(decimal: rounded(0)).intValue }

    /// Только для отрисовки графиков (Swift Charts требует Plottable-числа).
    var chartValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}

nonisolated extension Sequence {
    func sum(_ value: (Element) -> Decimal) -> Decimal {
        reduce(Decimal.zero) { $0 + value($1) }
    }
}
