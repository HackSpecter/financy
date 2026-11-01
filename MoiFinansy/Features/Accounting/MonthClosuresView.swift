import SwiftData
import SwiftUI

/// «Месяц закрыт»: архив итогов и текущий месяц.
struct MonthClosuresView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MonthClosure.month, order: .reverse) private var closures: [MonthClosure]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        List {
            Section {
                NavigationLink {
                    MonthSummaryDetailView(summary: MonthCloseService.summary(for: .now, in: context), isCurrent: true)
                } label: {
                    Label("Текущий месяц — \(Date.now.appFormatted("LLLL"))", systemImage: "calendar.badge.clock")
                }
            }
            Section("Архив") {
                if closures.isEmpty {
                    Text("Итоги появятся после первого закрытого месяца.").foregroundStyle(.secondary)
                }
                ForEach(closures) { closure in
                    if let summary = closure.summary {
                        NavigationLink {
                            MonthSummaryDetailView(summary: summary, isCurrent: false)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(closure.month.appFormatted("LLLLyyyy").capitalizedFirst).font(.body.weight(.medium))
                                    Text("отложено \(Money.format(closure.saved, currency: settings.currencyCode))").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("−" + Money.format(closure.expense, currency: settings.currencyCode)).monospacedDigit()
                                    Text("+" + Money.format(closure.income, currency: settings.currencyCode)).font(.caption).foregroundStyle(Theme.positive).monospacedDigit()
                                }
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { closures[$0] }.forEach(context.delete)
                    try? context.save()
                }
            }
        }
        .themedBackground()
        .navigationTitle("Итоги месяцев")
    }
}

struct MonthSummaryDetailView: View {
    var summary: MonthSummary
    var isCurrent: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var pdfURL: URL?
    @State private var closed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MonthSummaryCard(summary: summary, currency: settings.currencyCode)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        if let pdfURL {
                            ShareLink(item: pdfURL) {
                                Label("PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                        }
                        if isCurrent {
                            Button {
                                MonthCloseService.close(month: summary.month, in: context)
                                closed = true
                            } label: {
                                Label(closed ? "Сохранено" : "Закрыть месяц", systemImage: closed ? "checkmark" : "archivebox").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                            .disabled(closed)
                        }
                    }
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .background { AmbientBackground() }
        .themedBackground()
        .navigationTitle(summary.month.appFormatted("LLLLyyyy").capitalizedFirst)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: closed)
        .task {
            pdfURL = try? PDFRenderer.render(
                MonthSummaryCard(summary: summary, currency: settings.currencyCode),
                fileName: "Итоги \(summary.month.appFormatted("LLLLyyyy"))"
            )
        }
    }
}

/// Карточка итогов месяца (экран и PDF).
struct MonthSummaryCard: View {
    var summary: MonthSummary
    var currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Khalid Finance · месяц закрыт").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                Text(summary.month.appFormatted("LLLLyyyy").capitalizedFirst).font(.largeTitle.bold()).foregroundStyle(.white)
            }
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    metric("Доходы", Money.format(summary.income, currency: currency))
                    metric("Расходы", Money.format(summary.expense, currency: currency))
                }
                GridRow {
                    metric("Отложено", Money.format(summary.saved, currency: currency))
                    metric("Сбережения", summary.savingsRate.map(Money.percent) ?? "—")
                }
            }
            if let change = summary.expenseChange {
                Label("Расходы \(change > 0 ? "выросли" : "снизились") на \(Money.percent(abs(change))) к прошлому месяцу",
                      systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            section("Куда ушли деньги") {
                ForEach(summary.topCategories) { item in
                    HStack {
                        Circle().fill(Color(hex: item.colorHex)).frame(width: 10, height: 10)
                        Text(item.name)
                        Spacer()
                        Text(Money.percent(item.share)).opacity(0.7)
                        Text(Money.format(item.amount, currency: currency)).bold()
                    }
                }
            }
            if !summary.best.isEmpty {
                section("Лучше, чем в прошлом месяце") {
                    ForEach(summary.best) { change in
                        HStack { Text(change.name); Spacer(); Text(Money.format(change.delta, currency: currency)).bold() }
                    }
                }
            }
            if !summary.worst.isEmpty {
                section("Хуже, чем в прошлом месяце") {
                    ForEach(summary.worst) { change in
                        HStack { Text(change.name); Spacer(); Text(Money.format(change.delta, currency: currency, showsPlus: true)).bold() }
                    }
                }
            }
            if !summary.insights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(summary.insights.prefix(3), id: \.self) { Label($0, systemImage: "sparkles").font(.footnote) }
                }
                .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: "#5856D6"), Color(hex: "#2A2880")], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 28, style: .continuous)
        )
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.title3.bold()).fontDesign(.rounded).monospacedDigit().foregroundStyle(.white)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(.white)
            content().font(.subheadline).foregroundStyle(.white).monospacedDigit()
        }
    }
}

/// Рендер любой карточки в одностраничный PDF.
enum PDFRenderer {
    static func render(_ view: some View, fileName: String, width: CGFloat = 595) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(fileName).pdf")
        let renderer = ImageRenderer(content: view.frame(width: width).padding(24).environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(width: width + 48, height: nil)
        var failed = false
        renderer.render { size, render in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL), let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else {
                failed = true
                return
            }
            pdf.beginPDFPage(nil)
            render(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        if failed { throw CocoaError(.fileWriteUnknown) }
        return url
    }
}

#Preview {
    NavigationStack { MonthClosuresView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
