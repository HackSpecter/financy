#if DEBUG
import Foundation
import SwiftData

/// Тестовые данные за 3 месяца — только для DEBUG и превью.
enum DemoData {
    /// Детерминированный генератор, чтобы превью и отчёты были стабильными.
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    static func populate(_ context: ModelContext, now: Date = .now) {
        let calendar = AppCalendar.calendar
        DefaultData.seedIfNeeded(in: context)
        // Не дублируем: демо-данные загружаются только в пустую базу.
        guard ((try? context.fetchCount(FetchDescriptor<Transaction>())) ?? 0) == 0 else { return }
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))) ?? []
        func expense(_ name: String) -> Category? { categories.first { $0.name == name && $0.kind == .expense } }
        func income(_ name: String) -> Category? { categories.first { $0.name == name && $0.kind == .income } }
        let cash = accounts.first
        let card = accounts.dropFirst().first ?? cash
        cash?.initialBalance = 1500
        card?.initialBalance = 4000

        var rng = SeededGenerator(state: 2026)
        let firstMonth = calendar.date(byAdding: .month, value: -2, to: calendar.startOfMonth(for: now)) ?? now
        var day = firstMonth
        let today = calendar.startOfDay(for: now)

        func add(_ type: TransactionType, _ amount: Int, _ category: Category?, _ account: Account?, hour: Int, note: String = "", recurring: Bool = false) {
            let date = calendar.date(byAdding: .minute, value: hour * 60 + Int.random(in: 0..<60, using: &rng), to: day) ?? day
            guard date <= now else { return }
            context.insert(Transaction(type: type, amount: Decimal(amount), category: category, account: account, date: date, note: note, isRecurring: recurring))
        }

        while day <= today {
            let dayOfMonth = calendar.component(.day, from: day)
            let weekend = calendar.isWeekend(day)

            if dayOfMonth == 5 { add(.income, 25_000, income("Зарплата"), card, hour: 9, note: "Зарплата", recurring: true) }
            if dayOfMonth == 6, let card, let cash {
                let date = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
                if date <= now { context.insert(Transaction(type: .transfer, amount: 6000, account: card, toAccount: cash, date: date, note: "Снял наличные")) }
            }
            if dayOfMonth == 1 { add(.expense, 3_500, expense("Аренда/Коммуналка"), card, hour: 10, note: "Аренда", recurring: true) }
            if dayOfMonth == 10 { add(.expense, 200, expense("Связь и интернет"), card, hour: 9, note: "Интернет", recurring: true) }
            if dayOfMonth == 20, Bool.random(using: &rng) { add(.income, Int.random(in: 1500...3000, using: &rng), income("Подработка"), cash, hour: 18, note: "Заказ") }

            add(.expense, Int.random(in: 25...160, using: &rng), expense("Продукты"), cash, hour: 19, note: "Магазин")
            if Int.random(in: 0..<10, using: &rng) < 6 { add(.expense, Int.random(in: 30...95, using: &rng), expense("Кафе и рестораны"), card, hour: 13, note: "Обед") }
            if Int.random(in: 0..<10, using: &rng) < (weekend ? 8 : 4) { add(.expense, Int.random(in: 15...45, using: &rng), expense("Такси"), cash, hour: 8) }
            if !weekend { add(.expense, Int.random(in: 3...6, using: &rng), expense("Транспорт"), cash, hour: 8, note: "Маршрутка") }
            if weekend, Bool.random(using: &rng) { add(.expense, Int.random(in: 60...260, using: &rng), expense("Развлечения"), card, hour: 20, note: "Кино") }
            if weekend, Int.random(in: 0..<4, using: &rng) == 0 { add(.expense, Int.random(in: 120...400, using: &rng), expense("Семья"), cash, hour: 16) }
            if Int.random(in: 0..<25, using: &rng) == 0 { add(.expense, Int.random(in: 300...900, using: &rng), expense("Одежда"), card, hour: 17) }
            if Int.random(in: 0..<20, using: &rng) == 0 { add(.expense, Int.random(in: 40...250, using: &rng), expense("Здоровье"), cash, hour: 11, note: "Аптека") }
            if Int.random(in: 0..<30, using: &rng) == 0 { add(.expense, Int.random(in: 150...500, using: &rng), expense("Подарки"), card, hour: 18, note: "Подарок") }

            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        let rules = [
            RecurringRule(title: "Зарплата", type: .income, amount: 25_000, category: income("Зарплата"), account: card, frequency: .monthly, dayOfMonth: 5, startDate: firstMonth),
            RecurringRule(title: "Аренда", type: .expense, amount: 3_500, category: expense("Аренда/Коммуналка"), account: card, frequency: .monthly, dayOfMonth: 1, startDate: firstMonth),
            RecurringRule(title: "Интернет", type: .expense, amount: 200, category: expense("Связь и интернет"), account: card, frequency: .monthly, dayOfMonth: 10, startDate: firstMonth),
        ]
        for rule in rules {
            rule.nextDate = rule.recurrence.firstOccurrence(onOrAfter: calendar.date(byAdding: .day, value: 1, to: today) ?? today, calendar: calendar)
            context.insert(rule)
        }

        context.insert(Budget(limit: 25_000))
        context.insert(Budget(limit: 2_500, category: expense("Кафе и рестораны")))
        context.insert(Budget(limit: 900, category: expense("Такси")))
        context.insert(Budget(limit: 3_000, category: expense("Продукты")))

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        context.insert(PlannerItem(title: "Оплатить интернет", date: yesterday, priority: .high))
        context.insert(PlannerItem(title: "Позвонить маме", date: today, priority: .medium))
        context.insert(PlannerItem(title: "Встреча с клиентом", type: .meeting, date: today, time: calendar.date(byAdding: .hour, value: 18, to: today)))
        let done = PlannerItem(title: "Купить продукты", date: today)
        done.isDone = true
        done.doneAt = now
        context.insert(done)
        context.insert(PlannerItem(title: "Спортзал", date: tomorrow, time: calendar.date(byAdding: .hour, value: 19, to: tomorrow)))

        // SMS: карта, импортированная операция без категории и журнал.
        if (try? context.fetchCount(FetchDescriptor<BankCard>())) == 0 {
            context.insert(BankCard(last4: "4242", name: "Основная", account: card))
        }
        try? context.save()
        let sms = "\(now.appFormatted("ddMMyyyy").replacingOccurrences(of: "/", with: ".")) 12:10:05\nСписание со счета\nКарта 4*4242\nСумма 263.00 TJS\nОстаток 129.50 TJS"
        SMSImportService.process(text: sms, receivedAt: now, in: context)
        try? context.save()
    }

    /// Контейнер в памяти с демо-данными для #Preview. Один на процесс и всегда удерживается —
    /// иначе `previewContainer.mainContext` указывал бы на уже освобождённый контейнер.
    static let previewContainer: ModelContainer = {
        let container = DataStore.makeContainer(inMemory: true)
        populate(container.mainContext)
        return container
    }()
}
#endif
