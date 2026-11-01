import WidgetKit

import Foundation

nonisolated enum WidgetRefresher {
    static let dataChanged = Notification.Name("HisobDataChanged")

    /// Обновляет виджеты и сообщает приложению (часы, Live Activity), что данные изменились.
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: dataChanged, object: nil)
    }
}
