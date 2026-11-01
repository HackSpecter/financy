import ActivityKit
import Foundation
import SwiftData

/// Live Activity «Можно потратить сегодня» (включается в настройках).
enum LiveActivityService {
    static var isEnabled: Bool {
        get { SharedDefaults.store.bool(forKey: "liveActivity.enabled") }
        set { SharedDefaults.store.set(newValue, forKey: "liveActivity.enabled") }
    }

    static func start() {
        NotificationCenter.default.addObserver(forName: WidgetRefresher.dataChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { LiveActivityService.refresh() }
        }
    }

    /// Запускает, обновляет или завершает активность по настройке.
    static func refresh() {
        guard isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled,
              let allowance = FinanceService.allowance(in: DataStore.shared.mainContext) else {
            endAll()
            return
        }
        let state = HisobActivityAttributes.ContentState(
            leftToday: allowance.leftToday,
            dailyLimit: allowance.dailyLimit,
            spentToday: allowance.spentToday,
            statusRaw: allowance.status.rawValue,
            currency: SharedDefaults.currencyCode
        )
        let endOfDay = AppCalendar.calendar.dayInterval(for: .now).end
        let content = ActivityContent(state: state, staleDate: endOfDay)
        if Activity<HisobActivityAttributes>.activities.isEmpty {
            _ = try? Activity.request(attributes: HisobActivityAttributes(), content: content)
        } else {
            Task { await update(content) }
        }
    }

    static func endAll() {
        Task { await endActivities() }
    }

    /// Активности берутся и обновляются в одном контексте — объект `Activity` не передаётся между потоками.
    nonisolated private static func update(_ content: ActivityContent<HisobActivityAttributes.ContentState>) async {
        for activity in Activity<HisobActivityAttributes>.activities {
            await activity.update(content)
        }
    }

    nonisolated private static func endActivities() async {
        for activity in Activity<HisobActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
