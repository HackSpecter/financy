import SwiftUI
import Testing
import UIKit
@testable import MoiFinansy

/// iOS может вычислять динамические цвета вне главного потока (анимации, отрисовка списков).
/// Провайдер цвета не должен быть привязан к MainActor — иначе приложение падает.
struct ColorThreadingTests {
    @Test func dynamicColorResolvesOffMainThread() async {
        let color = UIColor(Color.dynamic(light: 0x1E8C4E, dark: 0x2E9E5E))
        let resolved = await Task.detached {
            color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        }.value
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(abs(green - 0x9E / 255.0) < 0.01)
    }
}
