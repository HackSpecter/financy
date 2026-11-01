import Foundation
import SwiftUI

/// Форматирование сумм на часах: `1 250 TJS`.
nonisolated enum WatchFormat {
    static let locale = Locale(identifier: "ru_RU")
    static let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Financy"

    static func amount(_ value: Decimal, currency: String) -> String {
        "\(number(value)) \(currency)"
    }

    static func number(_ value: Decimal) -> String {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return rounded.formatted(.number.locale(locale).grouping(.automatic).precision(.fractionLength(0)))
    }

    static func statusColor(_ raw: String) -> Color {
        switch raw {
        case "over": .red
        case "warning": .orange
        default: Color(red: 0.18, green: 0.62, blue: 0.37)
        }
    }
}
