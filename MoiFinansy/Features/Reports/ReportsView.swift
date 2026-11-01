import SwiftData
import SwiftUI

/// Вкладка «Отчёты».
struct ReportsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.order) private var categories: [Category]
    @Query private var budgets: [Budget]

    @State private var period = ReportPeriod()
    @State private var selectedCategory: CategoryInfo?
    @State private var showsExport = false

    var body: some View {
        let data = ReportData.make(transactions: transactions, categories: categories, budgets: budgets, period: period)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PeriodHeader(period: $period)
                    if data.summary.expense == 0, data.summary.income == 0 {
                        EmptyStateView(
                            title: "Нет данных за период",
                            symbol: "chart.pie",
                            message: "Добавьте операции или выберите другой период."
                        )
                        .frame(minHeight: 300)
                    } else {
                        ReportStatsGrid(summary: data.summary)
                        if !data.insights.isEmpty { InsightsCard(insights: data.insights) }
                        if !data.categories.isEmpty {
                            CategoryDonutCard(data: data) { selectedCategory = $0 }
                        }
                        if !data.daily.isEmpty {
                            DailySpendingChart(days: data.daily, dailyLimit: data.dailyLimit)
                        }
                        if !data.comparisons.isEmpty {
                            CategoryComparisonCard(data: data) { selectedCategory = $0 }
                        }
                        IncomeExpenseChart(months: data.monthly)
                        LargestExpensesCard(data: data)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background { AmbientBackground() }
            .themedBackground()
            .navigationTitle("Отчёты")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        NavigationLink { NetWorthView() } label: { Label("Капитал", systemImage: "chart.line.uptrend.xyaxis") }
                        NavigationLink { CashFlowCalendarView() } label: { Label("Денежный поток", systemImage: "calendar") }
                        NavigationLink { SubscriptionsView() } label: { Label("Подписки", systemImage: "repeat.circle") }
                        NavigationLink { EnvelopesView() } label: { Label("Конверты", systemImage: "envelope") }
                        NavigationLink { MonthClosuresView() } label: { Label("Итоги месяцев", systemImage: "archivebox") }
                        NavigationLink { BudgetsView() } label: { Label("Бюджеты", systemImage: "gauge.with.dots.needle.67percent") }
                        NavigationLink { WeeklyReviewView() } label: { Label("Недельный разбор", systemImage: "calendar.badge.checkmark") }
                        if AssistantAvailability.isAvailable {
                            NavigationLink { AskHisobView() } label: { Label("Спросить помощника", systemImage: "sparkles") }
                        }
                    } label: {
                        Label("Инструменты", systemImage: "square.grid.2x2")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Экспорт", systemImage: "square.and.arrow.up") { showsExport = true }
                        .disabled(data.entries.isEmpty)
                }
            }
            .navigationDestination(item: $selectedCategory) { category in
                CategoryDetailView(category: category, period: period)
            }
            .sheet(isPresented: $showsExport) {
                ReportExportSheet(data: data, title: period.title(), transactions: transactions.filter { data.interval.contains($0.date) })
            }
            .simultaneousGesture(swipeGesture)
            .animation(.snappy, value: period)
        }
    }

    /// Свайп влево-вправо — следующий/предыдущий период.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard period.kind != .custom, abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                if value.translation.width > 0 {
                    period.offset -= 1
                } else if period.canGoForward {
                    period.offset += 1
                }
            }
    }
}

private struct PeriodHeader: View {
    @Binding var period: ReportPeriod

    var body: some View {
        VStack(spacing: 12) {
            Picker("Период", selection: $period.kind) {
                ForEach(ReportPeriod.Kind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: period.kind) { period.offset = 0 }

            if period.kind == .custom {
                HStack {
                    DatePicker("С", selection: $period.customStart, displayedComponents: .date)
                    DatePicker("По", selection: $period.customEnd, displayedComponents: .date)
                }
                .labelsHidden()
            } else {
                GlassEffectContainer {
                    HStack {
                        Button("Назад", systemImage: "chevron.left") { period.offset -= 1 }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.glass)
                        Spacer()
                        Text(period.title())
                            .font(.headline)
                            .contentTransition(.numericText())
                        Spacer()
                        Button("Вперёд", systemImage: "chevron.right") { period.offset += 1 }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.glass)
                            .disabled(!period.canGoForward)
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

#Preview {
    ReportsView()
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
