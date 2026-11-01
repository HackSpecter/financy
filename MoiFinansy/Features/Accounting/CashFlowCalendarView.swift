import SwiftData
import SwiftUI

/// Календарь денежного потока: факт по дням, запланированные платежи и прогноз баланса.
struct CashFlowCalendarView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var rules: [RecurringRule]
    @Query private var budgets: [Budget]
    @Query(sort: \Account.order) private var accounts: [Account]
    @Environment(AppSettings.self) private var settings
    @State private var monthOffset = 0
    @State private var selected: CashFlowCalculator.Day?

    var body: some View {
        let calendar = AppCalendar.calendar
        let month = calendar.date(byAdding: .month, value: monthOffset, to: .now) ?? .now
        let days = self.days(for: month)
        ScrollView {
            VStack(spacing: 16) {
                header(month)
                weekdayRow
                grid(days, month: month)
                if let last = days.last(where: { $0.balance != nil }), let balance = last.balance {
                    HStack {
                        Label("Прогноз на конец месяца", systemImage: "chart.line.uptrend.xyaxis")
                        Spacer()
                        Text(Money.format(balance.rounded(0), currency: settings.currencyCode))
                            .fontWeight(.semibold)
                            .foregroundStyle(balance < 0 ? Theme.negative : .primary)
                    }
                    .font(.subheadline)
                    .card()
                }
                legend
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background { AmbientBackground() }
        .themedBackground()
        .navigationTitle("Денежный поток")
        .sheet(item: $selected) { day in CashFlowDayView(day: day, transactions: transactions) }
    }

    private func days(for month: Date) -> [CashFlowCalculator.Day] {
        let calendar = AppCalendar.calendar
        let now = Date.now
        let interval = calendar.monthInterval(for: month)
        let allowance = FinanceService.allowance(transactions: transactions, budgets: budgets, rules: rules, now: now, calendar: calendar)
        let monthEntries = transactions.filter { calendar.monthInterval(for: now).contains($0.date) }.map(\.entry)
        let discretionary = monthEntries.filter { $0.type == .expense && !$0.isRecurring }.sum(\.amount)
        let dailySpend = (discretionary / Decimal(max(calendar.component(.day, from: now), 1))).rounded(0)
        return CashFlowCalculator.month(
            of: month,
            entries: transactions.filter { interval.contains($0.date) }.map(\.entry),
            scheduled: FinanceService.upcoming(rules: rules, from: now, to: interval.end, calendar: calendar),
            balanceNow: accounts.filter { !$0.archived && !$0.isSavings }.sum(\.balanceInBase),
            dailySpend: dailySpend,
            spentToday: allowance?.spentToday ?? 0,
            now: now,
            calendar: calendar
        )
    }

    private func header(_ month: Date) -> some View {
        GlassEffectContainer {
            HStack {
                Button("Назад", systemImage: "chevron.left") { monthOffset -= 1 }.labelStyle(.iconOnly).buttonStyle(.glass)
                Spacer()
                Text(month.appFormatted("LLLLyyyy").capitalizedFirst).font(.headline)
                Spacer()
                Button("Вперёд", systemImage: "chevron.right") { monthOffset += 1 }.labelStyle(.iconOnly).buttonStyle(.glass)
                    .disabled(monthOffset >= 0)
            }
        }
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(PlannerLogic.week(containing: .now, calendar: AppCalendar.calendar), id: \.self) { day in
                Text(day.appFormatted("EEEEEE").capitalizedFirst)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(_ days: [CashFlowCalculator.Day], month: Date) -> some View {
        let calendar = AppCalendar.calendar
        let first = days.first?.date ?? month
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 64) }
            ForEach(days) { day in
                Button { selected = day } label: { CashFlowDayCell(day: day) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            Label("расход", systemImage: "circle.fill").foregroundStyle(Theme.negative)
            Label("доход", systemImage: "circle.fill").foregroundStyle(Theme.positive)
            Label("платёж", systemImage: "circle.fill").foregroundStyle(.indigo)
            Label("прогноз", systemImage: "circle.dashed").foregroundStyle(.secondary)
        }
        .font(.caption2)
    }
}

private struct CashFlowDayCell: View {
    var day: CashFlowCalculator.Day

    var body: some View {
        let isToday = AppCalendar.calendar.isDateInToday(day.date)
        VStack(spacing: 2) {
            Text("\(AppCalendar.calendar.component(.day, from: day.date))")
                .font(.caption.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? Color.accentColor : .primary)
            if day.expense > 0 {
                Text(Money.compact(day.expense)).font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.negative)
            }
            if day.income > 0 {
                Text(Money.compact(day.income)).font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.positive)
            }
            if !day.scheduled.isEmpty {
                Circle().fill(.indigo).frame(width: 5, height: 5)
            }
            Spacer(minLength: 0)
            if let balance = day.balance, day.isForecast {
                Text(Money.compact(balance)).font(.system(size: 8)).foregroundStyle(balance < 0 ? Theme.negative : .secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(day.isForecast ? Color.clear : Color(.secondarySystemGroupedBackground))
            if day.isForecast {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CashFlowDayView: View {
    var day: CashFlowCalculator.Day
    var transactions: [Transaction]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            List {
                if let balance = day.balance {
                    LabeledContent(day.isForecast ? "Прогноз баланса" : "Баланс на конец дня", value: Money.format(balance.rounded(0), currency: settings.currencyCode))
                }
                if !day.scheduled.isEmpty {
                    Section("Запланировано") {
                        ForEach(day.scheduled) { payment in
                            HStack {
                                Text(payment.title)
                                Spacer()
                                Text((payment.type == .income ? "+" : "−") + Money.format(payment.amount, currency: settings.currencyCode)).monospacedDigit()
                            }
                        }
                    }
                }
                let items = transactions.filter { AppCalendar.calendar.isDate($0.date, inSameDayAs: day.date) }
                if !items.isEmpty {
                    Section("Операции") {
                        ForEach(items) { TransactionRow(transaction: $0) }
                    }
                }
            }
            .themedBackground()
            .navigationTitle(day.date.dayTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack { CashFlowCalendarView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
