import SwiftUI

/// Итоговая карточка периода — показывается в приложении и экспортируется в PDF.
struct MonthReportCard: View {
    var data: ReportData
    var title: String
    var currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(AppInfo.name) · отчёт").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                Text(title).font(.largeTitle.bold()).foregroundStyle(.white)
            }
            HStack(spacing: 24) {
                metric("Итого доход", Money.format(data.summary.income, currency: currency))
                metric("Итого расход", Money.format(data.summary.expense, currency: currency))
            }
            HStack(spacing: 24) {
                metric("Чистый итог", Money.format(data.summary.balance, currency: currency, showsPlus: true))
                metric("Сбережения", data.summary.savingsRate.map(Money.percent) ?? "—")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Куда ушли деньги").font(.headline).foregroundStyle(.white)
                ForEach(data.categories.prefix(6)) { item in
                    let info = data.info(item.categoryID)
                    HStack {
                        Circle().fill(Color(hex: info.colorHex)).frame(width: 10, height: 10)
                        Text(info.name)
                        Spacer()
                        Text(Money.percent(item.share)).opacity(0.7)
                        Text(Money.format(item.amount, currency: currency)).bold()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                }
            }
            if !data.insights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(data.insights.prefix(3)) { insight in
                        Label(insight.text, systemImage: insight.symbol)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: "#0F9D74"), Color(hex: "#0A5C5A")], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 28, style: .continuous)
        )
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.title3.bold()).fontDesign(.rounded).monospacedDigit().foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    MonthReportCard(data: .preview, title: "Октябрь 2026", currency: "TJS").cardPreview()
}
