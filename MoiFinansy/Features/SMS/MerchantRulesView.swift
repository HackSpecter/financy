import SwiftData
import SwiftUI

/// Правила «магазин → категория».
struct MerchantRulesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MerchantRule.pattern) private var rules: [MerchantRule]
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var newPattern = ""
    @State private var newCategory: Category?
    @State private var query = ""

    var body: some View {
        List {
            Section {
                TextField("Магазин, напр. «yandex go»", text: $newPattern)
                    .textInputAutocapitalization(.never)
                Picker("Категория", selection: $newCategory) {
                    Text("Выберите").tag(Category?.none)
                    ForEach(categories.filter { !$0.archived }) { Label($0.name, systemImage: $0.symbol).tag(Optional($0)) }
                }
                Button("Добавить правило", systemImage: "plus.circle.fill") {
                    guard let newCategory else { return }
                    MerchantRuleService.learn(merchant: newPattern, category: newCategory, in: context)
                    newPattern = ""
                }
                .disabled(MerchantRuleService.normalize(newPattern).count < 2 || newCategory == nil)
            } footer: {
                Text("Когда вы выбираете категорию во «Входящих», правило запоминается само.")
            }

            Section("Правила") {
                ForEach(filtered) { rule in
                    HStack(spacing: 12) {
                        CategoryIcon(category: rule.category, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rule.pattern).font(.body.monospaced())
                            Text("\(rule.category?.name ?? "—")\(rule.isUserDefined ? " · ваше" : "")\(rule.useCount > 0 ? " · сработало \(rule.useCount)" : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            ForEach(categories.filter { !$0.archived && $0.kind == rule.category?.kind }) { category in
                                Button(category.name) {
                                    rule.category = category
                                    rule.isUserDefined = true
                                    try? context.save()
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.swap")
                        }
                        .accessibilityLabel("Сменить категорию")
                    }
                }
                .onDelete { offsets in
                    offsets.map { filtered[$0] }.forEach(context.delete)
                    try? context.save()
                }
            }
        }
        .themedBackground()
        .navigationTitle("Магазин → категория")
        .searchable(text: $query, prompt: "Поиск правила")
    }

    private var filtered: [MerchantRule] {
        query.isEmpty ? rules : rules.filter { $0.pattern.localizedCaseInsensitiveContains(query) || ($0.category?.name.localizedCaseInsensitiveContains(query) ?? false) }
    }
}

#Preview {
    NavigationStack { MerchantRulesView() }
        .modelContainer(DemoData.previewContainer)
}
