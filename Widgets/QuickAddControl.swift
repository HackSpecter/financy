import AppIntents
import SwiftUI
import WidgetKit

/// Кнопка в Пункте управления: мгновенно открывает добавление расхода.
struct QuickAddControl: ControlWidget {
    static let kind = "tj.khalid.hisob.quickadd"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenQuickAddIntent()) {
                Label("Расход", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Добавить расход")
        .description("Открывает быстрое добавление расхода в Khalid Finance.")
    }
}
