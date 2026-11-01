import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Данные часов: снимок с iPhone + отправка новых расходов и отметок задач.
@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    static let shared = WatchStore()
    static let appGroup = "group.tj.khalid.hisob"

    var snapshot: WatchSnapshot
    private let defaults = UserDefaults(suiteName: WatchStore.appGroup) ?? .standard

    override init() {
        if let data = defaults.data(forKey: WatchSnapshot.storageKey), let saved = try? JSONDecoder().decode(WatchSnapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = .empty
        }
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func addExpense(_ amount: Decimal, category: WatchSnapshot.CategoryItem) {
        let command = WatchCommand.expense(id: UUID(), amount: amount, categoryID: category.id, date: .now)
        WCSession.default.transferUserInfo(command.userInfo)
        // Сразу показываем результат, не дожидаясь iPhone.
        snapshot.spentToday += amount
        snapshot.leftToday -= amount
        if snapshot.leftToday <= 0 { snapshot.statusRaw = "over" }
        save()
    }

    func toggle(_ task: WatchSnapshot.TaskItem) {
        WCSession.default.transferUserInfo(WatchCommand.toggleTask(id: task.id).userInfo)
        if let index = snapshot.tasks.firstIndex(where: { $0.id == task.id }) {
            snapshot.tasks[index].isDone.toggle()
        }
        save()
    }

    func apply(_ data: Data?) {
        guard let data, let received = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        snapshot = received
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: WatchSnapshot.storageKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext[WatchSnapshot.storageKey] as? Data
        Task { @MainActor in WatchStore.shared.apply(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext[WatchSnapshot.storageKey] as? Data
        Task { @MainActor in WatchStore.shared.apply(data) }
    }
}
