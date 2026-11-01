import AppIntents
import SwiftData

/// Действие для автоматизации «Команд»: «Сообщение получено» → «Обработать SMS банка».
/// Работает в фоне, приложение не открывается.
struct ProcessBankSMSIntent: AppIntent {
    static let title: LocalizedStringResource = "Обработать SMS банка"
    static let description = IntentDescription("Разбирает SMS банка и записывает операцию в Khalid Finance.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Текст сообщения", inputConnectionBehavior: .connectToPreviousIntentResult)
    var text: String

    @Parameter(title: "Отправитель")
    var sender: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Обработать SMS \(\.$text)") {
            \.$sender
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let context = DataStore.shared.mainContext
        let result = SMSImportService.process(text: text, sender: sender, in: context)
        return .result(value: result.message, dialog: IntentDialog(stringLiteral: result.message))
    }
}

/// Показывает действие Khalid Finance в приложении «Команды» сразу после установки.
struct HisobShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ProcessBankSMSIntent(),
            phrases: ["Обработать SMS в \(.applicationName)"],
            shortTitle: "Обработать SMS банка",
            systemImageName: "message.badge.filled.fill"
        )
    }
}
