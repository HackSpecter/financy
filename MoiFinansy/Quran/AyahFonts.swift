import SwiftUI
import UIKit

/// Шрифты перевода. Встроенные — SIL Open Font License (лицензии в Resources/Fonts/Licenses).
nonisolated enum AyahFont: String, CaseIterable, Codable, Sendable, Identifiable {
    case newYork, sfRounded, cormorant, lora, ptSerif, playfair

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newYork: "New York"
        case .sfRounded: "SF Pro Rounded"
        case .cormorant: "Cormorant Garamond"
        case .lora: "Lora"
        case .ptSerif: "PT Serif"
        case .playfair: "Playfair Display"
        }
    }

    /// PostScript-имя встроенного шрифта (nil — системный).
    var postScriptName: String? {
        switch self {
        case .newYork, .sfRounded: nil
        case .cormorant: "CormorantGaramond-Regular"
        case .lora: "Lora-Regular"
        case .ptSerif: "PTSerif-Regular"
        case .playfair: "PlayfairDisplay-Regular"
        }
    }

    /// Cormorant мельче других при том же кегле — выравниваем визуальный размер.
    var sizeFactor: CGFloat { self == .cormorant ? 1.18 : 1 }

    func font(size: CGFloat, bold: Bool) -> Font {
        let size = size * sizeFactor
        let weight: Font.Weight = bold ? .semibold : .regular
        switch self {
        case .newYork: return .system(size: size, weight: weight, design: .serif)
        case .sfRounded: return .system(size: size, weight: bold ? .semibold : .medium, design: .rounded)
        case .ptSerif: return .custom(bold ? "PTSerif-Bold" : "PTSerif-Regular", fixedSize: size)
        default: return .custom(postScriptName ?? "", fixedSize: size).weight(weight)
        }
    }

    /// UIFont для измерения высоты текста.
    func uiFont(size: CGFloat, bold: Bool) -> UIFont {
        let size = size * sizeFactor
        let weight: UIFont.Weight = bold ? .semibold : .regular
        switch self {
        case .newYork:
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            return UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: size)
        case .sfRounded:
            let base = UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .medium)
            return UIFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size)
        case .ptSerif:
            return UIFont(name: bold ? "PTSerif-Bold" : "PTSerif-Regular", size: size) ?? .systemFont(ofSize: size)
        default:
            guard let font = UIFont(name: postScriptName ?? "", size: size) else { return .systemFont(ofSize: size) }
            let descriptor = font.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
            return UIFont(descriptor: descriptor, size: size)
        }
    }
}

/// Шрифты арабского текста (только приложение и большой виджет главного экрана).
nonisolated enum ArabicFont: String, CaseIterable, Codable, Sendable, Identifiable {
    case amiriQuran, scheherazade, notoNaskh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .amiriQuran: "Amiri Quran"
        case .scheherazade: "Scheherazade New"
        case .notoNaskh: "Noto Naskh Arabic"
        }
    }

    var postScriptName: String {
        switch self {
        case .amiriQuran: "AmiriQuran-Regular"
        case .scheherazade: "ScheherazadeNew-Regular"
        case .notoNaskh: "NotoNaskhArabic-Regular"
        }
    }

    func font(size: CGFloat) -> Font { .custom(postScriptName, fixedSize: size) }
}
