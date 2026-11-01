import SwiftData
import SwiftUI

struct TransactionRow: View {
    var transaction: Transaction
    var showsDate = false

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(transaction: transaction, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            MoneyText(amount: transaction.amount, type: transaction.type, currency: transaction.currencyCode, font: .body)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !transaction.note.isEmpty, transaction.note != transaction.category?.name, transaction.note != transaction.displayTitle { parts.append(transaction.note) }
        if transaction.type != .transfer, let account = transaction.account { parts.append(account.name) }
        if transaction.isRecurring { parts.append("регулярная") }
        if !transaction.tags.isEmpty { parts.append(transaction.tags.map { "#\($0)" }.joined(separator: " ")) }
        if transaction.source == .sms { parts.append(transaction.cardLast4.isEmpty ? "SMS" : "SMS •\(transaction.cardLast4)") }
        parts.append(showsDate ? transaction.date.appFormatted("dMMMHHmm") : transaction.date.timeText)
        return parts.joined(separator: " · ")
    }
}

#Preview {
    let container = DemoData.previewContainer
    let items = try! container.mainContext.fetch(FetchDescriptor<Transaction>())
    return List(items.prefix(6)) { TransactionRow(transaction: $0) }
        .environment(AppSettings.shared)
}
