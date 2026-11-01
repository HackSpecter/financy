import SwiftUI

struct InsightsCard: View {
    var insights: [InsightsEngine.Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Выводы", symbol: "sparkles", tint: .purple)
            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.symbol)
                        .foregroundStyle(color(insight.tone))
                        .frame(width: 24)
                    Text(insight.text)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card()
    }

    private func color(_ tone: InsightsEngine.Insight.Tone) -> Color {
        switch tone {
        case .positive: Theme.positive
        case .negative: Theme.caution
        case .neutral: .blue
        }
    }
}

#Preview {
    InsightsCard(insights: ReportData.preview.insights).cardPreview()
}
