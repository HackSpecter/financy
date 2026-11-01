import SwiftData
import SwiftUI

/// Центр настроек автоимпорта SMS.
struct SMSSettingsView: View {
    @Query(sort: \BankCard.createdAt) private var cards: [BankCard]
    @Query(sort: \SMSImportLog.receivedAt, order: .reverse) private var logs: [SMSImportLog]
    @State private var onlyKnownCards = SMSImportService.onlyKnownCards
    @State private var autoReconcile = SMSImportService.autoReconcile
    @State private var keepDays = SharedDefaults.store.object(forKey: "sms.keepDays") as? Int ?? 30

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    SMSSetupGuideView()
                } label: {
                    Label("Подключить SMS банка", systemImage: "wand.and.stars")
                }
            } footer: {
                Text("Автоматизация «Команд» передаёт каждое SMS банка в \(AppInfo.name) — операция записывается сама.")
            }

            Section {
                NavigationLink {
                    BankCardsView()
                } label: {
                    LabeledContent {
                        Text(cards.filter(\.isActive).map { "•\($0.last4)" }.joined(separator: ", "))
                    } label: {
                        Label("Мои карты", systemImage: "creditcard.fill")
                    }
                }
                Toggle("Читать только мои карты", isOn: $onlyKnownCards)
                Toggle("Баланс карты — как в банке", isOn: $autoReconcile)
            } footer: {
                Text("SMS по другим картам пропускаются. «Баланс карты — как в банке»: после каждого SMS баланс счёта выравнивается по «Остатку» из SMS.")
            }

            Section {
                ForEach(SMSKindDefaults.configurableKinds, id: \.self) { kind in
                    SMSKindCategoryPicker(kind: kind)
                }
            } header: {
                Text("Категория по умолчанию")
            } footer: {
                Text("Если в SMS нет названия магазина, операция получит эту категорию. «Во «Входящие»» — выбрать вручную.")
            }

            Section("Распознавание") {
                NavigationLink { BankRulesView() } label: { Label("Правила банков", systemImage: "text.badge.checkmark") }
                NavigationLink { ParserTrainerView() } label: { Label("Обучить парсер", systemImage: "graduationcap.fill") }
                NavigationLink { MerchantRulesView() } label: { Label("Магазин → категория", systemImage: "storefront.fill") }
            }

            Section {
                NavigationLink {
                    ImportLogView()
                } label: {
                    LabeledContent {
                        Text("\(logs.count)")
                    } label: {
                        Label("Журнал импорта", systemImage: "list.bullet.rectangle")
                    }
                }
                Picker("Хранить тексты SMS", selection: $keepDays) {
                    Text("7 дней").tag(7)
                    Text("30 дней").tag(30)
                    Text("90 дней").tag(90)
                    Text("Всегда").tag(0)
                }
            } footer: {
                Text("Тексты SMS хранятся только на устройстве, в журнале импорта, и удаляются автоматически.")
            }
        }
        .themedBackground()
        .navigationTitle("SMS банков")
        .onChange(of: onlyKnownCards) { SMSImportService.onlyKnownCards = onlyKnownCards }
        .onChange(of: autoReconcile) { SMSImportService.autoReconcile = autoReconcile }
        .onChange(of: keepDays) { SharedDefaults.store.set(keepDays, forKey: "sms.keepDays") }
    }
}

/// Выбор категории для типа SMS.
private struct SMSKindCategoryPicker: View {
    var kind: BankSMSParser.Kind
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var selection: UUID?

    var body: some View {
        Picker(kind.title, selection: $selection) {
            Text("Во «Входящие»").tag(UUID?.none)
            ForEach(categories.filter { $0.kind == (kind.isOutgoing ? .expense : .income) && !$0.archived }) { category in
                Label(category.name, systemImage: category.symbol).tag(Optional(category.id))
            }
        }
        .onAppear { selection = SMSKindDefaults.categoryID(for: kind) }
        .onChange(of: selection) { SMSKindDefaults.setCategoryID(selection, for: kind) }
    }
}

#Preview {
    NavigationStack { SMSSettingsView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
