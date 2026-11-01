import SwiftData
import SwiftUI

/// Ряд умных подсказок: шаблоны и частые траты — один тап = сохранено.
struct SuggestionsRow: View {
    var suggestions: [QuickSuggestion]
    var onSelect: (QuickSuggestion) -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            onSelect(suggestion)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: suggestion.category?.symbol ?? "bolt.fill")
                                    .foregroundStyle(Color(hex: suggestion.category?.colorHex ?? "#8E8E93"))
                                Text(suggestion.title)
                                    .foregroundStyle(.primary)
                                Text(Money.formatNumber(suggestion.amount))
                                    .fontDesign(.rounded)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Сохранить \(suggestion.title), \(Money.format(suggestion.amount, currency: settings.currencyCode))")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    let container = DemoData.previewContainer
    let context = container.mainContext
    let suggestions = QuickSuggestion.build(
        templates: (try? context.fetch(FetchDescriptor<Template>())) ?? [],
        transactions: (try? context.fetch(FetchDescriptor<Transaction>())) ?? [],
        type: .expense
    )
    return SuggestionsRow(suggestions: suggestions) { _ in }
        .padding()
        .environment(AppSettings.shared)
}
