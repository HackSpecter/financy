import FoundationModels
import SwiftUI

/// Доступность помощника: Apple Intelligence включена и поддерживает язык.
enum AssistantAvailability {
    static var isAvailable: Bool {
        let model = SystemLanguageModel.default
        return model.availability == .available
    }
}

// MARK: - Инструменты: только агрегированные данные

struct MonthSummaryTool: Tool {
    let name = "monthSummary"
    let description = "Итоги месяца: доходы, расходы, норма сбережений и расходы по категориям."

    @Generable
    struct Arguments {
        @Guide(description: "Номер месяца от 1 до 12")
        var month: Int
        @Guide(description: "Год, например 2026")
        var year: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { AssistantData.monthSummary(month: arguments.month, year: arguments.year) }
    }
}

struct TopExpensesTool: Tool {
    let name = "topExpenses"
    let description = "Самые крупные траты за месяц."

    @Generable
    struct Arguments {
        @Guide(description: "Номер месяца от 1 до 12")
        var month: Int
        @Guide(description: "Год, например 2026")
        var year: Int
        @Guide(description: "Сколько трат показать, от 1 до 10")
        var limit: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { AssistantData.topExpenses(month: arguments.month, year: arguments.year, limit: arguments.limit) }
    }
}

struct CompareMonthsTool: Tool {
    let name = "compareMonths"
    let description = "Сравнение расходов по категориям между двумя месяцами."

    @Generable
    struct Arguments {
        @Guide(description: "Первый (более ранний) месяц, 1–12")
        var month1: Int
        @Guide(description: "Год первого месяца")
        var year1: Int
        @Guide(description: "Второй месяц, 1–12")
        var month2: Int
        @Guide(description: "Год второго месяца")
        var year2: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { AssistantData.compare(month1: arguments.month1, year1: arguments.year1, month2: arguments.month2, year2: arguments.year2) }
    }
}

struct CurrentStatusTool: Tool {
    let name = "currentStatus"
    let description = "Текущее состояние: дневной лимит, траты месяца, баланс, долги и цели."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { AssistantData.currentStatus() }
    }
}

// MARK: - Экран

struct AskHisobView: View {
    struct Message: Identifiable {
        let id = UUID()
        var text: String
        var isUser: Bool
    }

    @State private var session = Self.makeSession()
    @State private var messages: [Message] = []
    @State private var question = ""
    @State private var isThinking = false
    @FocusState private var focused: Bool

    private let suggestions = [
        "Куда я больше всего тратил в сентябре?",
        "Сколько можно потратить сегодня?",
        "Сравни прошлый и этот месяц",
        "Какие были самые крупные траты в этом месяце?",
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Спросите о своих финансах", systemImage: "sparkles").font(.headline)
                            Text("Работает на устройстве. Khalid Finance передаёт модели только итоги — суммы по месяцам и категориям.")
                                .font(.footnote).foregroundStyle(.secondary)
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) { ask(suggestion) }
                                    .buttonStyle(.glass)
                            }
                        }
                        .padding(.top, 8)
                    }
                    ForEach(messages) { message in
                        Text(message.text)
                            .padding(12)
                            .background(message.isUser ? AnyShapeStyle(Color.accentColor.opacity(0.18)) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)), in: .rect(cornerRadius: 16, style: .continuous))
                            .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
                            .id(message.id)
                    }
                    if isThinking {
                        ProgressView().padding(.leading, 12).id("thinking")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .onChange(of: messages.count) {
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
        }
        .background { AmbientBackground() }
        .safeAreaInset(edge: .bottom) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Ваш вопрос…", text: $question, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    Button {
                        ask(question)
                    } label: {
                        Image(systemName: "arrow.up").font(.headline).foregroundStyle(.white).frame(width: 46, height: 46)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
                    .accessibilityLabel("Спросить")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .themedBackground()
        .navigationTitle("Спросить помощника")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func makeSession() -> LanguageModelSession {
        LanguageModelSession(
            tools: [MonthSummaryTool(), TopExpensesTool(), CompareMonthsTool(), CurrentStatusTool()],
            instructions: """
            Ты — Khalid Finance, помощник по личным финансам. Отвечай по-русски, кратко и по делу, с конкретными суммами.
            Валюта — сомони (TJS). Сегодня \(Date.now.appFormatted("dMMMMyyyy")).
            Для любых цифр используй инструменты; не выдумывай данные. Если данных нет, так и скажи.
            """
        )
    }

    private func ask(_ text: String) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isThinking else { return }
        messages.append(Message(text: prompt, isUser: true))
        question = ""
        isThinking = true
        Task {
            do {
                let response = try await session.respond(to: prompt)
                messages.append(Message(text: response.content, isUser: false))
            } catch {
                messages.append(Message(text: "Не получилось ответить. Попробуйте переформулировать вопрос.", isUser: false))
                session = Self.makeSession()
            }
            isThinking = false
        }
    }
}

#Preview {
    NavigationStack { AskHisobView() }
}
