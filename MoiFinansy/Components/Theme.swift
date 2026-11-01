import SwiftUI
import UIKit

/// Дизайн-система Khalid Finance: системные фоны, белые карточки и зелёный акцент.
enum Theme {
    /// Фон экранов — системный (светло-серый днём, чёрный ночью).
    static let background = Color(.systemGroupedBackground)
    /// Фон карточек — белый днём, тёмно-серый ночью.
    static let surface = Color(.secondarySystemGroupedBackground)
    static let fill = Color(.secondarySystemBackground)
    static let hairline = Color(.separator)
    /// Акцент — зелёный (AccentColor).
    static let accent = Color.accentColor

    static let positive = Color.financeGreen
    static let caution = Color.orange
    static let negative = Color.red

    static let cornerRadius: CGFloat = 24
}

/// Фон экранов — системный.
struct AmbientBackground: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

extension View {
    /// Фон списков и форм — системный, без изменений.
    func themedBackground() -> some View {
        self
    }

    /// Строка списка — системная.
    func glassRow() -> some View {
        self
    }

    /// Крупная сумма — округлый шрифт.
    func displayFont(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        font(.system(size: size, weight: weight, design: .rounded))
    }
}

/// Оформление: системное, светлое или тёмное.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Как в системе"
        case .light: "Светлое"
        case .dark: "Тёмное"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach([("background", Theme.background), ("surface", Theme.surface), ("fill", Theme.fill), ("accent", Theme.accent), ("positive", Theme.positive), ("caution", Theme.caution), ("negative", Theme.negative)], id: \.0) { name, color in
            HStack {
                RoundedRectangle(cornerRadius: 8).fill(color).frame(width: 44, height: 32)
                Text(name)
            }
        }
    }
    .padding()
}
