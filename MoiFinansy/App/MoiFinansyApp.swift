import SwiftData
import SwiftUI

@main
struct MoiFinansyApp: App {
    @State private var settings = AppSettings.shared
    @State private var router = AppRouter.shared
    @State private var toasts = ToastCenter.shared
    @State private var ayah = AyahModel.shared

    init() {
        let context = DataStore.shared.mainContext
        DefaultData.seedIfNeeded(in: context)
        QuranStore.installIntoAppGroupIfNeeded()
        DefaultData.seedSMSIfNeeded(in: context)
        SMSKindDefaults.seedIfNeeded(in: context)
        SMSKindDefaults.seedTransfersOutIfNeeded(in: context)
        SMSBalanceSync.alignOnceIfNeeded(in: context)
        NotificationRouter.shared.install()
        InboxNotifications.registerCategories(in: context)
        WatchSync.shared.start()
        LiveActivityService.start()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoData") {
            DemoData.populate(context)
            AppSettings.shared.hasOnboarded = true
        }
        // Для скриншотов: -tab reports | planner | transactions | search, -quickAdd.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-tab"), index + 1 < arguments.count {
            let tabs: [String: AppRouter.AppTab] = ["transactions": .transactions, "reports": .reports, "planner": .planner, "search": .search]
            AppRouter.shared.selectedTab = tabs[arguments[index + 1]] ?? .dashboard
        }
        if arguments.contains("-quickAdd") { AppRouter.shared.isQuickAddPresented = true }
        if arguments.contains("-inbox") { AppRouter.shared.isInboxPresented = true }
        if let index = arguments.firstIndex(of: "-screen"), index + 1 < arguments.count {
            AppRouter.shared.debugScreen = DebugScreen(rawValue: arguments[index + 1])
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(router)
                .environment(toasts)
                .environment(ayah)
                .onOpenURL { url in AppRouter.shared.open(url) }
        }
        .modelContainer(DataStore.shared)
    }
}
