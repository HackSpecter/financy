import Foundation
import Observation

/// Навигация приложения и действия, пришедшие из интентов, виджетов и Control Center.
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum AppTab: Hashable {
        case dashboard, transactions, reports, planner, search
    }

    var selectedTab: AppTab = .dashboard
    var isQuickAddPresented = false
    var isInboxPresented = false
    /// Аят, открытый из виджета или уведомления (сквозной номер).
    var presentedAyah: AyahLink?

    struct AyahLink: Identifiable, Hashable {
        var index: Int
        var id: Int { index }
    }
    /// Экран, открытый из уведомления (конверты, итоги месяца, недельный разбор).
    var presentedTool: Tool?
    #if DEBUG && !APP_EXTENSION
    /// Экран для скриншотов (`-screen savings`).
    var debugScreen: DebugScreen?
    #endif

    enum Tool: String, Identifiable {
        case envelopes, monthClose, weeklyReview
        var id: String { rawValue }
    }
    var quickAddType: TransactionType = .expense

    /// financy://ayah?i=6098 — из виджета «Аят».
    func open(_ url: URL) {
        guard url.scheme == "financy", url.host() == "ayah",
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "i" })?.value,
              let index = Int(value) else { return }
        presentedAyah = AyahLink(index: index)
    }

    func openQuickAdd(type: TransactionType = .expense) {
        SharedDefaults.pendingQuickAdd = false
        quickAddType = type
        isQuickAddPresented = true
    }

    /// Забирает отложенное действие, записанное интентом в общий App Group.
    func consumePendingActions() {
        if SharedDefaults.pendingQuickAdd {
            SharedDefaults.pendingQuickAdd = false
            openQuickAdd()
        }
    }
}
