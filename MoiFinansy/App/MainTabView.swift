import SwiftData
import SwiftUI
import UIKit

/// Системный TabView с панелью Liquid Glass и отдельной вкладкой поиска.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Query(filter: #Predicate<Transaction> { $0.needsReview }) private var inbox: [Transaction]

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab(value: AppRouter.AppTab.dashboard) {
                DashboardView()
            } label: {
                TabIcon(title: "Главная", symbol: "house.fill")
            }
            Tab(value: AppRouter.AppTab.transactions) {
                TransactionsListView()
            } label: {
                TabIcon(title: "Операции", symbol: "list.bullet.rectangle.portrait.fill")
            }
            .badge(inbox.count)
            Tab(value: AppRouter.AppTab.reports) {
                ReportsView()
            } label: {
                TabIcon(title: "Отчёты", symbol: "chart.pie.fill")
            }
            Tab(value: AppRouter.AppTab.planner) {
                PlannerView()
            } label: {
                TabIcon(title: "Планы", symbol: "checklist")
            }
            // Поиск — отдельно от остальных вкладок: в iOS 27 это делает роль `.prominent`.
            Tab("Поиск", systemImage: "magnifyingglass", value: AppRouter.AppTab.search, role: Self.searchRole) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Theme.accent)
        .sheet(isPresented: $router.isQuickAddPresented) {
            QuickAddSheet(type: router.quickAddType)
        }
        .sheet(item: $router.presentedAyah) { link in
            NavigationStack {
                AyahDetailView(index: link.index)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Закрыть", systemImage: "xmark") { router.presentedAyah = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $router.isInboxPresented) {
            InboxView()
        }
        .sheet(item: $router.presentedTool) { tool in
            NavigationStack {
                Group {
                    switch tool {
                    case .envelopes: EnvelopesView()
                    case .monthClose: MonthSummaryDetailView(summary: MonthCloseService.summary(for: .now, in: DataStore.shared.mainContext), isCurrent: true)
                    case .weeklyReview: WeeklyReviewView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть", systemImage: "xmark") { router.presentedTool = nil }
                    }
                }
            }
        }
        #if DEBUG
        .sheet(item: $router.debugScreen) { screen in
            NavigationStack { screen.view }
        }
        #endif
        .undoToast(toasts)
    }
}

extension MainTabView {
    static var searchRole: TabRole {
        if #available(iOS 27.0, *) { .prominent } else { .search }
    }
}

/// Иконка вкладки чуть меньше системной.
private struct TabIcon: View {
    var title: String
    var symbol: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: Self.image(symbol))
        }
    }

    static func image(_ name: String) -> UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        return UIImage(systemName: name, withConfiguration: configuration) ?? UIImage()
    }
}

#Preview {
    MainTabView()
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
        .environment(AppRouter.shared)
        .environment(ToastCenter.shared)
}
