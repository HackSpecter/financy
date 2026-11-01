import AppIntents
import SwiftData

/// Открывает приложение сразу на шторке быстрого добавления (Пункт управления, Action Button, виджет).
/// Доступно в приложении «Команды» — так его назначают на Action Button.
struct OpenQuickAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Быстрый расход"
    static let description = IntentDescription("Открывает шторку добавления расхода.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        SharedDefaults.pendingQuickAdd = true
        #if !WIDGET_EXTENSION
        AppRouter.shared.openQuickAdd()
        #endif
        return .result()
    }
}

/// Кнопка шаблона в интерактивном виджете: один тап = операция сохранена.
struct AddTemplateIntent: AppIntent {
    static let title: LocalizedStringResource = "Добавить по шаблону"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Шаблон")
    var templateID: String

    init() {}

    init(templateID: UUID) {
        self.templateID = templateID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = DataStore.shared.mainContext
        guard let id = UUID(uuidString: templateID),
              let template = try context.fetch(FetchDescriptor<Template>(predicate: #Predicate { $0.id == id })).first else {
            return .result()
        }
        TransactionService.add(template: template, in: context)
        return .result()
    }
}

/// Галочка задачи в виджете «Сегодня».
struct ToggleTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Отметить задачу"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Задача")
    var itemID: String

    init() {}

    init(itemID: UUID) {
        self.itemID = itemID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = DataStore.shared.mainContext
        guard let id = UUID(uuidString: itemID),
              let item = try context.fetch(FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.id == id })).first else {
            return .result()
        }
        PlannerService.toggle(item, in: context)
        return .result()
    }
}
