import SwiftUI

struct LargestExpensesCard: View {
    var data: ReportData
    @Environment(AppSettings.self) private var settings

    var body: some View {
        if !data.largest.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(title: "Крупнейшие траты", symbol: "arrow.up.forward.app.fill", tint: Theme.negative)
                ForEach(data.largest) { entry in
                    let info = data.info(entry.categoryID)
                    HStack(spacing: 10) {
                        CategoryIcon(symbol: info.symbol, colorHex: info.colorHex, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.note.isEmpty ? info.name : entry.note).font(.subheadline).lineLimit(1)
                            Text(entry.date.appFormatted("dMMMM")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.format(entry.amount, currency: settings.currencyCode))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .card()
        }
    }
}

#Preview {
    LargestExpensesCard(data: .preview).cardPreview()
}
