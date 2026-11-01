import SwiftData
import SwiftUI

/// Пошаговая настройка автоматизации «Команд» для SMS банка.
struct SMSSetupGuideView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var testText = "22.10.2026 20:52:50\nСписание со счета\nКарта 4*4242\nСумма 263.00 TJS\nОстаток 129.50 TJS"

    private let steps: [(symbol: String, title: String, text: String)] = [
        ("square.stack.3d.up.fill", "Откройте «Команды»", "Вкладка «Автоматизация» → «+» → «Создать автоматизацию для себя»."),
        ("message.fill", "Триггер «Сообщение»", "«Отправитель» — выберите номер или имя банка (как он подписан в SMS). Можно добавить несколько банков."),
        ("bolt.fill", "Запускать сразу", "Включите «Выполнять сразу» и выключите «Уведомлять при запуске» — тогда всё работает без нажатий."),
        ("plus.rectangle.on.rectangle", "Действие Khalid Finance", "Новая пустая автоматизация → найдите «Khalid Finance» → «Обработать SMS банка»."),
        ("text.bubble.fill", "Передайте текст", "В поле «Текст сообщения» выберите переменную «Входные данные команды» (содержимое сообщения)."),
        ("checkmark.seal.fill", "Готово", "Каждое SMS банка будет записываться само. Без категории — во «Входящих» с уведомлением."),
    ]

    var body: some View {
        List {
            Section {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: step.symbol)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(Color.accentColor.gradient, in: .rect(cornerRadius: 12, style: .continuous))
                            Text("\(index + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(.black.opacity(0.7), in: .circle)
                                .offset(x: 6, y: -6)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title).font(.headline)
                            Text(step.text).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Схема: SMS → «Команды» → Khalid Finance")
            }

            Section {
                Button {
                    if let url = URL(string: "shortcuts://") { openURL(url) }
                } label: {
                    Label("Открыть «Команды»", systemImage: "arrow.up.forward.app.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Тестовое SMS", text: $testText, axis: .vertical)
                    .lineLimit(3...8)
                    .font(.callout.monospaced())
                ParseOutcomeView(text: testText, outcome: SMSImportService.preview(testText, in: context))
            } header: {
                Text("Проверить")
            } footer: {
                Text("Пробный разбор — операция не записывается.")
            }
        }
        .themedBackground()
        .navigationTitle("Подключить SMS")
    }
}

#Preview {
    NavigationStack { SMSSetupGuideView() }
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
