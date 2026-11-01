import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Импорт выписки CSV / Excel / PDF: сопоставление колонок, предпросмотр, пропуск дублей.
struct StatementImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts
    @Query(sort: \Account.order) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var existing: [Transaction]

    @State private var showsPicker = false
    @State private var fileName = ""
    @State private var table: [[String]] = []
    @State private var mapping = StatementImporter.Mapping()
    @State private var account: Account?
    @State private var error: String?

    private static let xlsx = UTType(filenameExtension: "xlsx") ?? .data

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(table.isEmpty ? "Выбрать файл" : "Выбрать другой файл", systemImage: "doc.badge.plus") { showsPicker = true }
                    if !fileName.isEmpty { LabeledContent("Файл", value: fileName) }
                    if let error { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.caution) }
                } footer: {
                    Text("Поддерживаются CSV, Excel (.xlsx) и PDF-выписки банков.")
                }

                if !table.isEmpty {
                    Section("Колонки") {
                        Toggle("Первая строка — заголовки", isOn: $mapping.hasHeader)
                        columnPicker("Дата", $mapping.dateColumn)
                        columnPicker("Сумма", $mapping.amountColumn)
                        columnPicker("Расход (отдельно)", $mapping.debitColumn)
                        columnPicker("Приход (отдельно)", $mapping.creditColumn)
                        columnPicker("Описание", $mapping.descriptionColumn)
                        Toggle("Суммы без знака — расходы", isOn: $mapping.unsignedAreExpenses)
                        Picker("На счёт", selection: $account) {
                            ForEach(accounts.filter { !$0.archived }) { Text($0.name).tag(Optional($0)) }
                        }
                    }

                    Section {
                        ForEach(preview.prefix(30)) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.row.description.isEmpty ? "—" : item.row.description).font(.subheadline).lineLimit(1)
                                    Text(item.row.date.appFormatted("dMMMyyyy")).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Money.format(item.row.amount, currency: account?.currencyCode ?? "TJS", showsPlus: true))
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(item.row.amount > 0 ? Theme.positive : .primary)
                                    if item.isDuplicate {
                                        Text("уже есть").font(.caption2).foregroundStyle(Theme.caution)
                                    }
                                }
                            }
                            .opacity(item.isDuplicate ? 0.5 : 1)
                        }
                    } header: {
                        Text("Предпросмотр: \(preview.count) строк, новых \(newRows.count)")
                    }
                }
            }
            .themedBackground()
            .navigationTitle("Импорт выписки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Импорт \(newRows.count)", action: importRows)
                        .disabled(newRows.isEmpty || account == nil)
                }
            }
            .fileImporter(isPresented: $showsPicker, allowedContentTypes: [.commaSeparatedText, .plainText, Self.xlsx, .pdf]) { result in
                load(result)
            }
            .onAppear { account = account ?? TransactionService.lastAccount(in: context) }
        }
    }

    // MARK: Data

    private struct PreviewRow: Identifiable {
        var row: StatementImporter.Row
        var isDuplicate: Bool
        var id: Int { row.id }
    }

    private var preview: [PreviewRow] {
        StatementImporter.rows(table, mapping: mapping).map { PreviewRow(row: $0, isDuplicate: isDuplicate($0)) }
    }

    private var newRows: [StatementImporter.Row] { preview.filter { !$0.isDuplicate }.map(\.row) }

    /// Дубль: тот же день, сумма и счёт.
    private func isDuplicate(_ row: StatementImporter.Row) -> Bool {
        let calendar = AppCalendar.calendar
        return existing.contains { transaction in
            transaction.account?.id == account?.id
                && transaction.amount == abs(row.amount)
                && calendar.isDate(transaction.date, inSameDayAs: row.date)
                && (transaction.type == .income) == (row.amount > 0)
        }
    }

    private var columns: [(index: Int, title: String)] {
        let count = table.map(\.count).max() ?? 0
        return (0..<count).map { index in
            let header = mapping.hasHeader ? (table.first?[safe: index] ?? "") : ""
            let sample = table.dropFirst(mapping.hasHeader ? 1 : 0).first?[safe: index] ?? ""
            return (index, header.isEmpty ? "Колонка \(index + 1): \(sample)" : header)
        }
    }

    private func columnPicker(_ title: String, _ binding: Binding<Int?>) -> some View {
        Picker(title, selection: binding) {
            Text("—").tag(Int?.none)
            ForEach(columns, id: \.index) { Text($0.title).lineLimit(1).tag(Optional($0.index)) }
        }
    }

    // MARK: Actions

    private func load(_ result: Result<URL, Error>) {
        error = nil
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            fileName = url.lastPathComponent
            let data = try Data(contentsOf: url)
            switch url.pathExtension.lowercased() {
            case "xlsx":
                table = try XLSXReader.rows(from: data)
            case "pdf":
                let text = PDFDocument(data: data)?.string ?? ""
                table = StatementImporter.table(fromText: text)
            default:
                let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) ?? ""
                table = CSVParser.parse(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
            }
            mapping = StatementImporter.guessMapping(table)
            if table.isEmpty { error = "Не нашёл операций в файле" }
        } catch {
            self.error = "Не удалось прочитать файл"
            table = []
        }
    }

    private func importRows() {
        guard let account else { return }
        for row in newRows {
            let type: TransactionType = row.amount > 0 ? .income : .expense
            let category = row.description.isEmpty ? nil : MerchantRuleService.category(for: row.description, type: type, in: context)
            let transaction = Transaction(type: type, amount: abs(row.amount), category: category, account: account, date: row.date, note: row.description)
            transaction.merchant = row.description
            transaction.source = .statement
            transaction.needsReview = category == nil
            context.insert(transaction)
        }
        try? context.save()
        WidgetRefresher.reload()
        toasts.show("Импортировано операций: \(newRows.count)")
        dismiss()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

#Preview {
    StatementImportView()
        .modelContainer(DemoData.previewContainer)
        .environment(ToastCenter.shared)
}
