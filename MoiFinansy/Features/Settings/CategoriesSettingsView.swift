import SwiftData
import SwiftUI

struct CategoriesSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var kind: CategoryKind = .expense
    @State private var editing: Category?
    @State private var isAdding = false

    var body: some View {
        let visible = categories.filter { $0.kind == kind }
        List {
            Section {
                Picker("Тип", selection: $kind) {
                    ForEach(CategoryKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                ForEach(visible) { category in
                    Button { editing = category } label: {
                        HStack(spacing: 12) {
                            CategoryIcon(category: category, size: 34)
                            Text(category.name)
                            Spacer()
                            if category.archived {
                                Image(systemName: "archivebox").foregroundStyle(.secondary)
                            }
                        }
                        .opacity(category.archived ? 0.5 : 1)
                    }
                    .buttonStyle(.plain)
                }
                .onMove { from, to in
                    var reordered = visible
                    reordered.move(fromOffsets: from, toOffset: to)
                    for (index, category) in reordered.enumerated() { category.order = index }
                    try? context.save()
                }
            } footer: {
                Text("Перетащите, чтобы изменить порядок в сетке быстрого добавления. Архивные категории скрыты.")
            }
        }
        .themedBackground()
        .navigationTitle("Категории")
        .toolbar {
            EditButton()
            Button("Добавить", systemImage: "plus") { isAdding = true }
        }
        .sheet(item: $editing) { CategoryEditor(category: $0, kind: $0.kind) }
        .sheet(isPresented: $isAdding) { CategoryEditor(category: nil, kind: kind) }
    }
}

struct CategoryEditor: View {
    var category: Category?
    var kind: CategoryKind
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]

    @State private var name = ""
    @State private var symbol = "star.fill"
    @State private var colorHex = "#007AFF"
    @State private var keywords = ""
    @State private var archived = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        CategoryIcon(symbol: symbol, colorHex: colorHex, size: 44)
                        TextField("Название", text: $name).font(.title3)
                    }
                }
                Section("Оформление") { SymbolColorPicker(symbol: $symbol, colorHex: $colorHex) }
                Section {
                    TextField("такси, яндекс, uber", text: $keywords, axis: .vertical)
                } header: {
                    Text("Ключевые слова")
                } footer: {
                    Text("По этим словам в заметке приложение само подскажет категорию.")
                }
                if category != nil {
                    Toggle("В архиве", isOn: $archived)
                }
            }
            .themedBackground()
            .navigationTitle(category == nil ? "Новая категория" : "Категория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let category else { return }
                name = category.name
                symbol = category.symbol
                colorHex = category.colorHex
                keywords = category.keywords
                archived = category.archived
            }
        }
    }

    private func save() {
        if let category {
            category.name = name
            category.symbol = symbol
            category.colorHex = colorHex
            category.keywords = keywords
            category.archived = archived
        } else {
            let order = (categories.filter { $0.kind == kind }.map(\.order).max() ?? -1) + 1
            context.insert(Category(name: name, symbol: symbol, colorHex: colorHex, kind: kind, order: order, keywords: keywords))
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    NavigationStack { CategoriesSettingsView() }
        .modelContainer(DemoData.previewContainer)
}
