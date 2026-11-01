#if DEBUG
import SwiftData
import SwiftUI

extension ReportData {
    /// Отчёт за текущий месяц по демо-данным — для превью карточек.
    static var preview: ReportData {
        let context = DemoData.previewContainer.mainContext
        return make(
            transactions: (try? context.fetch(FetchDescriptor<Transaction>())) ?? [],
            categories: (try? context.fetch(FetchDescriptor<Category>())) ?? [],
            budgets: (try? context.fetch(FetchDescriptor<Budget>())) ?? [],
            period: ReportPeriod()
        )
    }
}

extension View {
    /// Фон и окружение для превью карточек.
    func cardPreview() -> some View {
        ScrollView { self.padding() }
            .background { AmbientBackground() }
            .environment(AppSettings.shared)
    }
}
#endif
