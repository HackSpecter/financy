import SwiftData
import SwiftUI

/// Журнал импорта: все полученные SMS и что из них получилось.
struct ImportLogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SMSImportLog.receivedAt, order: .reverse) private var logs: [SMSImportLog]
    @State private var status: SMSImportStatus?

    var body: some View {
        List {
            if logs.isEmpty {
                EmptyStateView(title: "Журнал пуст", symbol: "tray", message: "Здесь появятся SMS, которые прислала автоматизация «Команд».")
                    .listRowBackground(Color.clear)
            }
            ForEach(filtered) { log in
                NavigationLink {
                    ImportLogDetailView(log: log)
                } label: {
                    ImportLogRow(log: log)
                }
            }
            .onDelete { offsets in
                offsets.map { filtered[$0] }.forEach(context.delete)
                try? context.save()
            }
        }
        .themedBackground()
        .navigationTitle("Журнал импорта")
        .toolbar {
            Menu {
                Picker("Статус", selection: $status) {
                    Text("Все").tag(SMSImportStatus?.none)
                    ForEach(SMSImportStatus.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag(Optional($0)) }
                }
            } label: {
                Image(systemName: status == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }

    private var filtered: [SMSImportLog] {
        guard let status else { return logs }
        return logs.filter { $0.status == status }
    }
}

struct ImportLogRow: View {
    var log: SMSImportLog

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: log.status.symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(log.summary.isEmpty ? log.status.title : log.summary)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(log.text.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: TransactionSource(rawValue: log.sourceRaw)?.symbol ?? "message")
                    Text(log.receivedAt.appFormatted("dMMMHHmm"))
                    if log.hasBalanceMismatch {
                        Label("остаток не совпал", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.caution)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var color: Color {
        switch log.status {
        case .imported, .merged: Theme.positive
        case .needsReview: .blue
        case .duplicate, .ignored: .secondary
        case .unknownCard, .unrecognized: Theme.caution
        }
    }
}

struct ImportLogDetailView: View {
    @Bindable var log: SMSImportLog
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var editing: Transaction?
    @State private var addsCard = false

    var body: some View {
        List {
            Section("SMS") {
                ParseOutcomeView(text: log.text, outcome: SMSImportService.preview(log.text, sender: log.sender, in: context))
                if !log.sender.isEmpty { LabeledContent("Отправитель", value: log.sender) }
                LabeledContent("Получено", value: log.receivedAt.appFormatted("dMMMMyyyyHHmmss"))
            }

            Section("Результат") {
                Label(log.summary.isEmpty ? log.status.title : log.summary, systemImage: log.status.symbol)
                if let transaction = log.transaction {
                    Button { editing = transaction } label: {
                        TransactionRow(transaction: transaction, showsDate: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            if log.hasBalanceMismatch, let difference = log.balanceDifference {
                Section {
                    Label {
                        Text("В банке остаток \(Money.format(log.balance ?? 0, currency: settings.currencyCode)), в приложении на \(Money.format(abs(difference), currency: settings.currencyCode)) \(difference > 0 ? "меньше" : "больше").")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.caution)
                    }
                    Button("Скорректировать баланс", systemImage: "plusminus.circle.fill") {
                        SMSImportService.adjustBalance(for: log, in: context)
                    }
                } header: {
                    Text("Сверка баланса")
                } footer: {
                    Text("Создаст операцию-корректировку: баланс совпадёт с банком, отчёты не изменятся.")
                }
            }

            Section {
                if log.status == .unknownCard {
                    Button("Добавить карту •\(log.cardLast4)", systemImage: "creditcard.fill") { addsCard = true }
                }
                if log.transaction == nil, [.unknownCard, .unrecognized, .duplicate, .ignored].contains(log.status) {
                    Button("Разобрать ещё раз", systemImage: "arrow.clockwise") { reprocess() }
                }
                Button("Удалить запись\(log.transaction != nil ? " и операцию" : "")", systemImage: "trash", role: .destructive) {
                    if let transaction = log.transaction { TransactionService.delete(transaction, in: context) }
                    context.delete(log)
                    try? context.save()
                    dismiss()
                }
            }
        }
        .themedBackground()
        .navigationTitle(log.status.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { TransactionEditView(transaction: $0) }
        .sheet(isPresented: $addsCard, onDismiss: reprocess) {
            BankCardEditor(card: nil, suggestedLast4: log.cardLast4)
        }
    }

    private func reprocess() {
        let text = log.text
        let sender = log.sender
        let received = log.receivedAt
        context.delete(log)
        try? context.save()
        SMSImportService.process(text: text, sender: sender.isEmpty ? nil : sender, receivedAt: received, in: context)
        dismiss()
    }
}

#Preview {
    NavigationStack { ImportLogView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
