import SwiftUI

/// Текст SMS с подсветкой найденных полей.
struct HighlightedSMSText: View {
    var text: String
    var highlights: [BankSMSParser.Field: NSRange]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(attributed)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !highlights.isEmpty {
                FlowLegend(fields: BankSMSParser.Field.allCases.filter { highlights[$0] != nil })
            }
        }
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        for (field, range) in highlights {
            guard let swiftRange = Range(range, in: text),
                  let lower = AttributedString.Index(swiftRange.lowerBound, within: result),
                  let upper = AttributedString.Index(swiftRange.upperBound, within: result) else { continue }
            result[lower..<upper].backgroundColor = field.color.opacity(0.3)
            result[lower..<upper].foregroundColor = field.color
            result[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }
}

private struct FlowLegend: View {
    var fields: [BankSMSParser.Field]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(fields, id: \.self) { field in
                    Label(field.title, systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(field.color)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

extension BankSMSParser.Field {
    var color: Color {
        switch self {
        case .amount: Theme.positive
        case .balance: .blue
        case .card: Theme.caution
        case .merchant: .purple
        case .date: .teal
        case .type: .pink
        }
    }
}

/// Карточка результата разбора.
struct ParseOutcomeView: View {
    var text: String
    var outcome: BankSMSParser.Outcome
    @Environment(AppSettings.self) private var settings

    var body: some View {
        switch outcome {
        case .transaction(let parsed):
            VStack(alignment: .leading, spacing: 12) {
                HighlightedSMSText(text: text, highlights: parsed.highlights)
                Divider()
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    row("Тип", parsed.kind.title)
                    row("Сумма", Money.format(parsed.amount, currency: parsed.currency))
                    row("Карта", parsed.cardLast4.map { "•\($0)" } ?? "—")
                    row("Магазин", parsed.merchant ?? "—")
                    row("Дата", parsed.date.map { $0.appFormatted("dMMMyyyyHHmm") } ?? "время получения")
                    row("Остаток", parsed.balance.map { Money.format($0, currency: parsed.currency) } ?? "—")
                    row("Правило", parsed.ruleName)
                }
                .font(.subheadline)
            }
        case .ignored(let reason):
            Label(reason, systemImage: "minus.circle.fill").foregroundStyle(.secondary)
        case .unrecognized(let reason):
            Label(reason, systemImage: "questionmark.circle.fill").foregroundStyle(Theme.caution)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).fontWeight(.medium)
        }
    }
}

#Preview {
    let text = "22.10.2026 20:52:50\nСписание со счета\nКарта 4*4242\nСумма 263.00 TJS\nОстаток 129.50 TJS"
    ScrollView {
        ParseOutcomeView(text: text, outcome: BankSMSParser.parse(text)).card()
    }
    .padding()
    .environment(AppSettings.shared)
}
