import SwiftData
import SwiftUI

struct TransactionFilterSheet: View {
    @Binding var filter: TransactionFilter
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Account.order) private var accounts: [Account]

    var body: some View {
        NavigationStack {
            Form {
                Section("Период") {
                    Picker("Период", selection: $filter.period) {
                        ForEach(TransactionFilter.Period.allCases) { Text($0.title).tag($0) }
                    }
                    if filter.period == .custom {
                        DatePicker("С", selection: $filter.customStart, displayedComponents: .date)
                        DatePicker("По", selection: $filter.customEnd, displayedComponents: .date)
                    }
                }
                Section("Тип") {
                    Picker("Тип", selection: $filter.type) {
                        Text("Все").tag(TransactionType?.none)
                        ForEach(TransactionType.userCases) { Text($0.title).tag(Optional($0)) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Категория и счёт") {
                    Picker("Категория", selection: $filter.categoryID) {
                        Text("Все").tag(UUID?.none)
                        ForEach(categories.filter { !$0.archived }) { category in
                            Label(category.name, systemImage: category.symbol).tag(Optional(category.id))
                        }
                    }
                    Picker("Счёт", selection: $filter.accountID) {
                        Text("Все").tag(UUID?.none)
                        ForEach(accounts) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                if filter.isActive {
                    Button("Сбросить фильтры", role: .destructive) { filter = TransactionFilter() }
                }
            }
            .themedBackground()
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    @Previewable @State var filter = TransactionFilter()
    TransactionFilterSheet(filter: $filter)
        .modelContainer(DemoData.previewContainer)
}
