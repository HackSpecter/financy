import Foundation
import SwiftData
import WatchConnectivity

/// Синхронизация с Apple Watch: снимок → часы, расходы и задачи ← часы.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()
    private var pendingPush: Task<Void, Never>?

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        NotificationCenter.default.addObserver(forName: WidgetRefresher.dataChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { WatchSync.shared.schedulePush() }
        }
    }

    /// Отправка с задержкой, чтобы не слать по снимку на каждое сохранение.
    func schedulePush() {
        pendingPush?.cancel()
        pendingPush = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            push()
        }
    }

    func push() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated, WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        guard let data = try? JSONEncoder().encode(Self.snapshot(in: DataStore.shared.mainContext)) else { return }
        try? WCSession.default.updateApplicationContext([WatchSnapshot.storageKey: data])
    }

    static func snapshot(in context: ModelContext, now: Date = .now) -> WatchSnapshot {
        let allowance = FinanceService.allowance(in: context, now: now)
        let categories = ((try? context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.order)]))) ?? [])
            .filter { $0.kind == .expense && !$0.archived }
            .sorted { ($0.transactions?.count ?? 0) > ($1.transactions?.count ?? 0) }
            .prefix(8)
        return WatchSnapshot(
            leftToday: allowance?.leftToday ?? 0,
            dailyLimit: allowance?.dailyLimit ?? 0,
            spentToday: allowance?.spentToday ?? 0,
            statusRaw: allowance?.status.rawValue ?? "good",
            currency: SharedDefaults.currencyCode,
            hasBudget: allowance != nil,
            categories: categories.map { .init(id: $0.id, name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex) },
            tasks: PlannerService.todayItems(in: context, now: now).map { .init(id: $0.id, title: $0.title, isDone: $0.isDone, time: $0.time) },
            updatedAt: now
        )
    }

    static func handle(_ command: WatchCommand) {
        let context = DataStore.shared.mainContext
        switch command {
        case let .expense(_, amount, categoryID, date):
            let category = try? context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.id == categoryID })).first
            TransactionService.add(type: .expense, amount: amount, category: category, account: TransactionService.lastAccount(in: context), date: date, note: "С часов", in: context)
        case let .toggleTask(id):
            if let item = try? context.fetch(FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.id == id })).first {
                PlannerService.toggle(item, in: context)
            }
        }
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in WatchSync.shared.push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let command = WatchCommand(userInfo: userInfo) else { return }
        Task { @MainActor in WatchSync.handle(command) }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in WatchSync.shared.push() }
    }
}
