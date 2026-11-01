import Combine
import SwiftData
import SwiftUI

/// Главная: «Можно потратить сегодня», баланс, прогноз, топ категорий, задачи.
struct DashboardView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var rules: [RecurringRule]
    @Query(sort: \Account.order) private var accounts: [Account]
    @Query(filter: #Predicate<Transaction> { $0.needsReview }) private var inbox: [Transaction]

    @State private var now = Date.now
    @State private var showsSettings = false
    @State private var showsBudgets = false

    var body: some View {
        let allowance = self.allowance
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !inbox.isEmpty {
                        InboxBanner(count: inbox.count) { router.isInboxPresented = true }
                    }
                    AyahDashboardCard()
                    BalanceCard(accounts: accounts, monthIncome: monthIncome, monthExpense: monthExpense)
                    if let allowance {
                        MonthProgressCard(result: allowance)
                        ForecastCard(forecast: allowance.forecast, now: now)
                    }
                    SavingsCard()
                    DebtsCard()
                    TodayTasksCard(now: now)
                    TopCategoriesCard(transactions: monthTransactions)
                    RecentTransactionsCard(transactions: Array(transactions.prefix(5))) {
                        router.selectedTab = .transactions
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
            .background { AmbientBackground() }
            .themedBackground()
            .navigationTitle("Главная")
            .toolbar {
                if settings.privacyEnabled {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(settings.amountsHidden ? "Показать суммы" : "Скрыть суммы", systemImage: settings.amountsHidden ? "eye.slash" : "eye") {
                            if settings.amountsHidden { settings.revealAmounts() } else { settings.hideAmounts() }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Бюджеты", systemImage: "gauge.with.dots.needle.67percent") { showsBudgets = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Настройки", systemImage: "gearshape") { showsSettings = true }
                }
            }
            .sheet(isPresented: $showsSettings) { SettingsView() }
            .sheet(isPresented: $showsBudgets) { NavigationStack { BudgetsView() } }
            .floatingAddButton { router.openQuickAdd() }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in now = .now }
            #if DEBUG
            .onAppear {
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("-settings") { showsSettings = true }
                if arguments.contains("-budgets") { showsBudgets = true }
            }
            #endif
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in now = .now }
        }
    }

    private var calendar: Calendar { AppCalendar.calendar }

    private var monthTransactions: [Transaction] {
        let month = calendar.monthInterval(for: now)
        return transactions.filter { month.contains($0.date) }
    }

    private var monthIncome: Decimal { monthTransactions.filter { $0.type == .income }.sum(\.amount) }
    private var monthExpense: Decimal { monthTransactions.filter { $0.type == .expense }.sum(\.amount) }

    private var allowance: BudgetCalculator.Result? {
        FinanceService.allowance(transactions: monthTransactions, budgets: budgets, rules: rules, now: now, calendar: calendar)
    }
}

#Preview {
    DashboardView()
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
        .environment(AppRouter.shared)
        .environment(ToastCenter.shared)
}
