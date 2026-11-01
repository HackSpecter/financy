import SwiftData
import SwiftUI

struct BalanceCard: View {
    var accounts: [Account]
    var monthIncome: Decimal
    var monthExpense: Decimal
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let spending = accounts.filter { !$0.archived && $0.countsInBalance }
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Баланс сейчас", symbol: "wallet.bifold.fill") {
                NavigationLink("Капитал") { NetWorthView() }.font(.subheadline)
            }
            MoneyText(amount: spending.sum(\.balanceInBase), font: .title.bold())
            HStack(spacing: 12) {
                ForEach(spending.prefix(3)) { account in
                    Label {
                        Text(Money.format(account.balance, currency: account.currencyCode))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: account.symbol).foregroundStyle(Color(hex: account.colorHex))
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            Divider()
            HStack {
                stat(title: "Доход за месяц", amount: monthIncome, color: Theme.positive, symbol: "arrow.up")
                Spacer()
                stat(title: "Расход за месяц", amount: monthExpense, color: Theme.negative, symbol: "arrow.down")
            }
        }
        .card()
    }

    private func stat(title: String, amount: Decimal, color: Color, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(color)
            MoneyText(amount: amount, font: .headline)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let context = DemoData.previewContainer.mainContext
    let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
    return BalanceCard(accounts: accounts, monthIncome: 25_000, monthExpense: 9_320).cardPreview()
}
