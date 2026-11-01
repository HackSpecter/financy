import SwiftUI

/// Экспорт отчёта в CSV и PDF во временные файлы для ShareLink.
enum ReportExporter {
    /// Итоги таблицы в базовой валюте: переводы между своими счетами и корректировки не считаются.
    struct Totals: Equatable {
        var income: Decimal
        var expense: Decimal
        var net: Decimal { income - expense }
    }

    static func totals(_ transactions: [Transaction]) -> Totals {
        let base: (Transaction) -> Decimal = { CurrencyService.toBase($0.amount, from: $0.currencyCode) }
        return Totals(
            income: transactions.filter { $0.type == .income }.sum(base),
            expense: transactions.filter { $0.type == .expense }.sum(base)
        )
    }

    /// «1250,5» / «-45» — число для Excel (запятая — десятичный разделитель).
    static func number(_ value: Decimal) -> String {
        "\(value.rounded(2))".replacingOccurrences(of: ".", with: ",")
    }

    static func csv(_ transactions: [Transaction], fileName: String) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(fileName).csv")
        // BOM — чтобы Excel правильно открыл кириллицу.
        try Data(("\u{FEFF}" + csvText(transactions)).utf8).write(to: url)
        return url
    }

    /// Таблица операций и итоги внизу: доход, расход и чистый итог.
    static func csvText(_ transactions: [Transaction]) -> String {
        var lines = ["Дата;Тип;Категория;Счёт;Сумма;Валюта;Заметка"]
        let currency = SharedDefaults.currencyCode
        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            // Расход — с минусом, чтобы столбец «Сумма» складывался в Excel.
            let signed = transaction.type == .expense ? -transaction.amount : transaction.amount
            let amount = number(signed)
            let fields = [
                transaction.date.appFormatted("ddMMyyyyHHmm"),
                transaction.type.title,
                transaction.type == .transfer ? "Перевод" : (transaction.category?.name ?? ""),
                transaction.account?.name ?? "",
                amount,
                transaction.currencyCode,
                transaction.note,
            ]
            lines.append(fields.map(escape).joined(separator: ";"))
        }
        let totals = totals(transactions)
        lines.append("")
        lines.append(";;;Итого доход;\(number(totals.income));\(currency);")
        lines.append(";;;Итого расход;\(number(-totals.expense));\(currency);")
        lines.append(";;;Чистый итог;\(number(totals.net));\(currency);\(totals.net >= 0 ? "прибыль" : "убыток")")
        lines.append(";;;;;;Переводы между своими счетами и корректировки баланса в итоги не входят")
        return lines.joined(separator: "\n")
    }

    static func pdf(data: ReportData, title: String, fileName: String) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(fileName).pdf")
        let renderer = ImageRenderer(
            content: MonthReportCard(data: data, title: title, currency: SharedDefaults.currencyCode)
                .frame(width: 595)
                .padding(24)
                .environment(\.colorScheme, .light)
        )
        renderer.proposedSize = ProposedViewSize(width: 643, height: nil)
        var thrown: Error?
        renderer.render { size, render in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else {
                thrown = CocoaError(.fileWriteUnknown)
                return
            }
            pdf.beginPDFPage(nil)
            render(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        if let thrown { throw thrown }
        return url
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(";") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// Шторка с итоговой карточкой и кнопками экспорта.
struct ReportExportSheet: View {
    var data: ReportData
    var title: String
    var transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var pdfURL: URL?
    @State private var csvURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MonthReportCard(data: data, title: title, currency: settings.currencyCode)
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            if let pdfURL {
                                ShareLink(item: pdfURL) {
                                    Label("PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glassProminent)
                            }
                            if let csvURL {
                                ShareLink(item: csvURL) {
                                    Label("CSV", systemImage: "tablecells").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glass)
                            }
                        }
                        .controlSize(.large)
                    }
                }
                .padding()
            }
            .themedBackground()
            .navigationTitle("Итоги")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", systemImage: "checkmark") { dismiss() }
                }
            }
            .task {
                let name = "Отчёт \(title)"
                pdfURL = try? ReportExporter.pdf(data: data, title: title, fileName: name)
                csvURL = try? ReportExporter.csv(transactions, fileName: name)
            }
        }
    }
}

#Preview {
    ReportExportSheet(data: .preview, title: "Октябрь 2026", transactions: [])
        .environment(AppSettings.shared)
}
