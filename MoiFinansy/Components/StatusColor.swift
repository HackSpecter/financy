import SwiftUI
import UIKit

extension Color {
    /// Цвет, разный для светлой и тёмной темы.
    /// `nonisolated`: iOS вычисляет такие цвета и вне главного потока — привязка к MainActor роняла приложение.
    nonisolated static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { @Sendable traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    /// Спокойный зелёный приложения: темнее системного, без «неона».
    static let financeGreen = Color.dynamic(light: 0x1E8C4E, dark: 0x2E9E5E)
}

extension BudgetCalculator.Status {
    var color: Color {
        switch self {
        case .good: .financeGreen
        case .warning: .orange
        case .over: .red
        }
    }
}
