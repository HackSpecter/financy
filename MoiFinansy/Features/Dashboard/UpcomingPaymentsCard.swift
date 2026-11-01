import SwiftUI

struct UpcomingPaymentsCard: View {
    var payments: [ScheduledPayment]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        if !payments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(title: "Ближайшие регулярные", symbol: "repeat.circle.fill", tint: .indigo)
                ForEach(payments) { payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(payment.title).font(.subheadline.weight(.medium))
                            Text(payment.date.dayTitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text((payment.type == .income ? "+" : "−") + Money.format(payment.amount, currency: settings.currencyCode))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(payment.type == .income ? Theme.positive : .primary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .card()
        }
    }
}

#Preview {
    UpcomingPaymentsCard(payments: [
        ScheduledPayment(title: "Аренда", amount: 3500, date: .now.addingTimeInterval(86_400 * 3), type: .expense, isMandatory: true),
        ScheduledPayment(title: "Зарплата", amount: 25_000, date: .now.addingTimeInterval(86_400 * 10), type: .income, isMandatory: false),
    ]).cardPreview()
}
