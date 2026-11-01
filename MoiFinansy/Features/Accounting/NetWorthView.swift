import Charts
import SwiftData
import SwiftUI

/// Капитал (net worth) и его динамика по месяцам.
struct NetWorthView: View {
    @Query(sort: \Account.order) private var accounts: [Account]
    @Query private var debts: [Debt]
    @Query private var transactions: [Transaction]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let breakdown = self.breakdown
        let history = self.history(current: breakdown.total)
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Капитал").font(.subheadline).foregroundStyle(.secondary)
                    MoneyText(amount: breakdown.total, font: .largeTitle.bold())
                    if let first = history.first, history.count > 1 {
                        let delta = breakdown.total - first.value
                        Text("\(Money.format(delta, currency: settings.currencyCode, showsPlus: true)) за \(history.count - 1) мес.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(delta >= 0 ? Theme.positive : Theme.negative)
                    }
                }
                .padding(.vertical, 4)
                Chart(history) { point in
                    AreaMark(x: .value("Месяц", point.month, unit: .month), y: .value("Капитал", point.value.chartValue))
                        .foregroundStyle(LinearGradient(colors: [Theme.positive.opacity(0.35), Theme.positive.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Месяц", point.month, unit: .month), y: .value("Капитал", point.value.chartValue))
                        .foregroundStyle(Theme.positive)
                        .interpolationMethod(.catmullRom)
                        .symbol(.circle)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel { if let amount = value.as(Double.self) { Text(Money.compact(Decimal(amount))) } }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { AxisValueLabel(format: .dateTime.month(.abbreviated)) }
                }
                .environment(\.locale, AppCalendar.locale)
                .frame(height: 200)
            }
            Section("Из чего складывается") {
                row("Счета", breakdown.accounts, "wallet.bifold.fill", .blue)
                row("Копилки", breakdown.savings, "building.columns.fill", Theme.caution)
                row("Мне должны", breakdown.owedToMe, "arrow.down.left.circle.fill", Theme.positive)
                row("Я должен", -breakdown.iOwe, "arrow.up.right.circle.fill", Theme.negative)
            }
            Section("Счета") {
                ForEach(accounts.filter { !$0.archived }) { account in
                    HStack {
                        Label(account.name, systemImage: account.symbol)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(Money.format(account.balance, currency: account.currencyCode)).monospacedDigit()
                            if account.currencyCode != settings.currencyCode {
                                Text("≈ \(Money.format(account.balanceInBase, currency: settings.currencyCode))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle("Капитал")
    }

    private var breakdown: NetWorthCalculator.Breakdown {
        let active = accounts.filter { !$0.archived }
        let totals = DebtCalculator.totals(debts.map(\.snapshot)) { CurrencyService.toBase($0, from: $1) }
        return NetWorthCalculator.Breakdown(
            accounts: active.filter { !$0.isSavings }.sum(\.balanceInBase),
            savings: active.filter(\.isSavings).sum(\.balanceInBase),
            owedToMe: totals.owedToMe,
            iOwe: totals.iOwe
        )
    }

    /// Движения капитала: операции по счетам и изменения долгов.
    private func history(current: Decimal) -> [NetWorthCalculator.Point] {
        var movements: [NetWorthCalculator.Movement] = []
        for transaction in transactions {
            let base = CurrencyService.toBase(transaction.amount, from: transaction.currencyCode)
            switch transaction.type {
            case .income, .adjustment: movements.append(.init(date: transaction.date, delta: base))
            case .expense: movements.append(.init(date: transaction.date, delta: -base))
            case .transfer: break
            }
        }
        for debt in debts {
            let sign: Decimal = debt.direction == .theyOwe ? 1 : -1
            let amount = CurrencyService.toBase(debt.amount, from: debt.currencyCode)
            movements.append(.init(date: debt.date, delta: sign * amount))
            for payment in debt.payments ?? [] {
                movements.append(.init(date: payment.date, delta: -sign * CurrencyService.toBase(payment.amount, from: debt.currencyCode)))
            }
        }
        let start = current - movements.sum(\.delta)
        return NetWorthCalculator.history(start: start, movements: movements, months: 12, now: .now, calendar: AppCalendar.calendar)
    }

    private func row(_ title: String, _ amount: Decimal, _ symbol: String, _ color: Color) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(color)
            Spacer()
            Text(Money.format(amount, currency: settings.currencyCode)).monospacedDigit().foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack { NetWorthView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
