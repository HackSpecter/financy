import UIKit

/// Измеряет реальную высоту текста в выбранном шрифте и ширине — чтобы аят помещался целиком.
nonisolated enum AyahFitter {
    /// Высота заголовка суры с отступом до текста.
    static func titleHeight(size: CGFloat, spacing: CGFloat) -> CGFloat {
        ceil(UIFont.systemFont(ofSize: size, weight: .regular).lineHeight) + spacing
    }

    static func textHeight(_ text: String, font: UIFont, lineSpacing: CGFloat, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        let string = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph])
        let rect = string.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(rect.height)
    }

    /// Помещается ли аят на экране блокировки (только перевод и заголовок).
    static func fitsLock(_ text: String, style: AyahStyle, box: CGSize, scale: CGFloat = 1) -> Bool {
        fitsLock(text, style: style, box: box, pointSize: style.size.lockPointSize * scale)
    }

    /// Помещается при кегле `pointSize`: по высоте и не больше `AyahLayout.lockMaxLines` строк.
    static func fitsLock(_ text: String, style: AyahStyle, box: CGSize, pointSize: CGFloat) -> Bool {
        let title = style.titlePosition == .hidden ? 0 : titleHeight(size: AyahLayout.lockTitleSize, spacing: AyahLayout.lockSpacing)
        let font = style.font.uiFont(size: pointSize, bold: style.bold)
        let spacing = AyahLayout.lockLineSpacing(style)
        let height = textHeight(AyahTypography.russian(text), font: font, lineSpacing: spacing, width: box.width)
        let maxLines = ceil(font.lineHeight * CGFloat(AyahLayout.lockMaxLines) + spacing * CGFloat(AyahLayout.lockMaxLines - 1))
        return height <= maxLines && height + title + AyahLayout.safetyMargin <= box.height
    }

    /// Помещается ли аят в карточку главного экрана (с арабским — если включено).
    static func fitsHome(_ text: String, arabic: String?, style: AyahStyle, arabicFont: ArabicFont, box: CGSize, scale: CGFloat = 1) -> Bool {
        let width = box.width - AyahLayout.homeInset * 2
        var height = AyahLayout.homeInset * 2
        if style.titlePosition != .hidden { height += titleHeight(size: AyahLayout.homeTitleSize, spacing: AyahLayout.homeSpacing) }
        let font = style.font.uiFont(size: style.size.homePointSize * scale, bold: style.bold)
        height += textHeight(AyahTypography.russian(text), font: font, lineSpacing: style.lineSpacing + 1, width: width)
        if let arabic, !arabic.isEmpty {
            let size = style.size.homePointSize + 4
            let arabicUIFont = UIFont(name: arabicFont.postScriptName, size: size) ?? .systemFont(ofSize: size)
            height += textHeight(arabic, font: arabicUIFont, lineSpacing: 0, width: width) + AyahLayout.homeSpacing
        }
        return height + AyahLayout.safetyMargin <= box.height
    }
}

/// Размеры вёрстки — общие для замера и отрисовки.
nonisolated enum AyahLayout {
    static let lockTitleSize: CGFloat = 9
    static let lockMaxLines = 4
    /// Минимальный читаемый кегль на экране блокировки.
    static let lockMinimumPointSize: CGFloat = 11
    /// Плотный, но не слипшийся интервал: чем мельче шрифт, тем меньше.
    static func lockLineSpacing(_ style: AyahStyle) -> CGFloat { min(style.lineSpacing, 1) }

    /// Размеры от выбранного (максимум) до минимального, шаг 0,5 pt.
    static func lockPointSizes(_ style: AyahStyle) -> [CGFloat] {
        stride(from: style.size.lockPointSize, through: lockMinimumPointSize, by: -0.5).map { $0 }
    }
    /// Заголовок вплотную к тексту.
    static let lockSpacing: CGFloat = 1
    static let homeTitleSize: CGFloat = 11
    static let homeSpacing: CGFloat = 8
    /// Внутренний отступ стеклянной карточки + внешний отступ от края виджета.
    static let homeInset: CGFloat = 22
    static let safetyMargin: CGFloat = 2
    /// Размер прямоугольного виджета экрана блокировки на больших iPhone.
    static let lockBox = CGSize(width: 172, height: 76)

    /// Реальный размер с устройства (сохраняет виджет «Аят»; им же считает «Сура»).
    static var storedLockBox: CGSize {
        get {
            let width = SharedDefaults.store.double(forKey: "ayah.lockBox.w")
            let height = SharedDefaults.store.double(forKey: "ayah.lockBox.h")
            return width > 0 && height > 0 ? CGSize(width: width, height: height) : lockBox
        }
        set {
            SharedDefaults.store.set(Double(newValue.width), forKey: "ayah.lockBox.w")
            SharedDefaults.store.set(Double(newValue.height), forKey: "ayah.lockBox.h")
        }
    }
}
