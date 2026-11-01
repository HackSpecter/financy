import SwiftUI

/// Оформление аята: шрифт, размер, начертание, выравнивание и заголовок.
nonisolated struct AyahStyle: Codable, Sendable, Hashable {
    enum TitlePosition: String, Codable, Sendable, CaseIterable { case top, bottom, hidden }
    enum Alignment: String, Codable, Sendable, CaseIterable { case leading, center }
    enum Size: Int, Codable, Sendable, CaseIterable, Comparable {
        case small, medium, large, extraLarge
        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

        var title: String {
            switch self {
            case .small: "Мелкий"
            case .medium: "Средний"
            case .large: "Крупный"
            case .extraLarge: "Очень крупный"
            }
        }

        /// Кегль на экране блокировки.
        var lockPointSize: CGFloat {
            switch self {
            case .small: 12
            case .medium: 13.5
            case .large: 15
            case .extraLarge: 17
            }
        }

        /// Кегль на главном экране.
        var homePointSize: CGFloat { lockPointSize + 4 }
    }

    var font: AyahFont = .newYork
    var size: Size = .medium
    var bold = false
    var alignment: Alignment = .leading
    var titlePosition: TitlePosition = .top
    /// Дополнительный межстрочный интервал, pt.
    var lineSpacing: CGFloat = 1
    /// Перед заголовком внизу ставится тире: «— АШ-ШАРХ 94:5».
    var titleDash = false

    var textAlignment: TextAlignment { alignment == .center ? .center : .leading }
    var horizontalAlignment: HorizontalAlignment { alignment == .center ? .center : .leading }
    var frameAlignment: SwiftUI.Alignment { alignment == .center ? .center : .leading }

    // MARK: Три варианта на выбор

    /// «Классика»: New York, по левому краю, заголовок сверху капителью.
    static let classic = AyahStyle(font: .newYork, size: .medium, bold: false, alignment: .leading, titlePosition: .top, lineSpacing: 1)
    /// «Книга»: Cormorant Garamond, по левому краю, подпись снизу через тире.
    static let book = AyahStyle(font: .cormorant, size: .medium, bold: false, alignment: .leading, titlePosition: .bottom, lineSpacing: 0.5, titleDash: true)
    /// «Современный»: SF Pro Rounded, полужирный, по левому краю, заголовок сверху.
    static let modern = AyahStyle(font: .sfRounded, size: .medium, bold: true, alignment: .leading, titlePosition: .top, lineSpacing: 1)
}

/// Заголовок суры: мелкий, капс, разрядка, тоньше основного текста.
struct AyahTitleView: View {
    var title: String
    var style: AyahStyle
    var size: CGFloat = 9.5

    var body: some View {
        Text(style.titleDash && style.titlePosition == .bottom ? "—\u{00A0}" + title : title)
            .font(.system(size: size, weight: .regular, design: style.font == .sfRounded ? .rounded : .default))
            .tracking(size * 0.16)
            .lineLimit(1)
            .opacity(0.72)
    }
}

/// Текст аята на экране блокировки (accessoryRectangular): только перевод и заголовок.
/// Шрифт подбирается сам: от выбранного размера (максимум) до 11 pt; «…» — только при настоящей обрезке.
struct AyahLockView: View {
    var text: String
    var title: String
    var style: AyahStyle
    /// Не используется на экране блокировки — размер подбирает `ViewThatFits`.
    var fontScale: CGFloat = 1

    var body: some View {
        VStack(alignment: style.horizontalAlignment, spacing: AyahLayout.lockSpacing) {
            if style.titlePosition == .top { AyahTitleView(title: title, style: style, size: AyahLayout.lockTitleSize) }
            AyahFittingText(text: AyahTypography.russian(text), style: style)
            if style.titlePosition == .bottom { AyahTitleView(title: title, style: style, size: AyahLayout.lockTitleSize) }
        }
        // Вся площадь виджета, прижато к верху — заголовки соседних виджетов на одной линии.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.alignment == .center ? .top : .topLeading)
        .accessibilityElement(children: .combine)
    }
}

/// Перебор размеров шрифта: первый, при котором текст помещается целиком.
struct AyahFittingText: View {
    var text: String
    var style: AyahStyle

    var body: some View {
        let spacing = AyahLayout.lockLineSpacing(style)
        let sizes = AyahLayout.lockPointSizes(style)
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { size in
                line(size, spacing: spacing).fixedSize(horizontal: false, vertical: true)
            }
            // Последняя страховка: 4 строки и уменьшение — система поставит «…», только если обрежет.
            line(AyahLayout.lockMinimumPointSize, spacing: spacing)
                .lineLimit(AyahLayout.lockMaxLines)
                .minimumScaleFactor(0.85)
        }
        .contentTransition(.opacity)
    }

    private func line(_ size: CGFloat, spacing: CGFloat) -> some View {
        Text(text)
            .font(style.font.font(size: size, bold: style.bold))
            .lineSpacing(spacing)
            .multilineTextAlignment(style.textAlignment)
    }
}

/// Карточка аята для главного экрана: стекло поверх бордово-белого градиента.
struct AyahHomeCard: View {
    var text: String
    var title: String
    var arabic: String?
    var style: AyahStyle
    var arabicFont: ArabicFont = .amiriQuran
    var fontScale: CGFloat = 1

    var body: some View {
        VStack(alignment: style.horizontalAlignment, spacing: 8) {
            if style.titlePosition == .top { AyahTitleView(title: title, style: style, size: 11) }
            if let arabic, !arabic.isEmpty {
                Text(arabic)
                    .font(arabicFont.font(size: style.size.homePointSize + 4))
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity)
            }
            Text(AyahTypography.russian(text))
                .font(style.font.font(size: style.size.homePointSize * fontScale, bold: style.bold))
                .lineSpacing(style.lineSpacing + 1)
                .multilineTextAlignment(style.textAlignment)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
            if style.titlePosition == .bottom { AyahTitleView(title: title, style: style, size: 11) }
        }
        .foregroundStyle(.primary)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.frameAlignment)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
    }
}

/// Фон виджета главного экрана: бургунди → белый (светлая тема) / бургунди → чёрный (тёмная).
struct AyahHomeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.36, green: 0.08, blue: 0.15), Color(red: 0.07, green: 0.03, blue: 0.05)]
                : [Color(red: 0.55, green: 0.14, blue: 0.24), Color(red: 0.98, green: 0.95, blue: 0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
