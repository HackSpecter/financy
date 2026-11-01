import Foundation
import SwiftData
import WidgetKit

/// Снимок данных для всех виджетов.
nonisolated struct WidgetSnapshot: Sendable {
    struct TemplateItem: Sendable, Identifiable {
        var id: UUID
        var title: String
        var amount: Decimal
        var symbol: String
        var colorHex: String
    }

    struct TaskItem: Sendable, Identifiable {
        var id: UUID
        var title: String
        var isDone: Bool
        var time: Date?
        var isMeeting: Bool
    }

    struct GoalItem: Sendable, Identifiable {
        var id: UUID
        var name: String
        var saved: Decimal
        var target: Decimal
        var symbol: String
        var colorHex: String
        var fraction: Double { target > 0 ? min((saved / target).chartValue, 1) : 0 }
    }

    struct SubscriptionItem: Sendable, Identifiable {
        var id: UUID
        var title: String
        var amount: Decimal
        var date: Date
        var symbol: String
        var colorHex: String
    }

    var hasBudget: Bool
    var leftToday: Decimal
    var dailyLimit: Decimal
    var spentToday: Decimal
    var spentMonth: Decimal
    var monthBudget: Decimal
    var status: BudgetCalculator.Status
    var dayOfMonth: Int
    var daysInMonth: Int
    var currency: String
    var templates: [TemplateItem]
    var tasks: [TaskItem]
    var goals: [GoalItem] = []
    var owedToMe: Decimal = 0
    var iOwe: Decimal = 0
    var subscriptions: [SubscriptionItem] = []
    var netWorth: Decimal = 0
    var accountsTotal: Decimal = 0
    var savingsTotal: Decimal = 0

    var todayProgress: Double {
        guard dailyLimit > 0 else { return 1 }
        return min(max((spentToday / dailyLimit).chartValue, 0), 1)
    }

    var monthProgress: Double {
        guard monthBudget > 0 else { return 0 }
        return min((spentMonth / monthBudget).chartValue, 1)
    }

    static let placeholder = WidgetSnapshot(
        hasBudget: true, leftToday: 420, dailyLimit: 560, spentToday: 140, spentMonth: 12_400, monthBudget: 25_000,
        status: .good, dayOfMonth: 14, daysInMonth: 31, currency: "TJS",
        templates: [
            .init(id: UUID(), title: "Такси", amount: 20, symbol: "car.fill", colorHex: "#FFCC00"),
            .init(id: UUID(), title: "Обед", amount: 45, symbol: "fork.knife", colorHex: "#FF9500"),
            .init(id: UUID(), title: "Хлеб", amount: 5, symbol: "cart.fill", colorHex: "#34C759"),
        ],
        tasks: [
            .init(id: UUID(), title: "Позвонить маме", isDone: false, time: nil, isMeeting: false),
            .init(id: UUID(), title: "Встреча с клиентом", isDone: false, time: .now, isMeeting: true),
            .init(id: UUID(), title: "Купить продукты", isDone: true, time: nil, isMeeting: false),
        ],
        goals: [
            .init(id: UUID(), name: "Телефон", saved: 3200, target: 6000, symbol: "iphone", colorHex: "#007AFF"),
            .init(id: UUID(), name: "Отпуск", saved: 1500, target: 10_000, symbol: "airplane", colorHex: "#FF9500"),
        ],
        owedToMe: 1500,
        iOwe: 400,
        subscriptions: [
            .init(id: UUID(), title: "Интернет", amount: 200, date: .now.addingTimeInterval(172_800), symbol: "wifi", colorHex: "#32ADE6"),
            .init(id: UUID(), title: "Netflix", amount: 120, date: .now.addingTimeInterval(518_400), symbol: "film.fill", colorHex: "#AF52DE"),
        ],
        netWorth: 58_300,
        accountsTotal: 51_054,
        savingsTotal: 6_146
    )
}

enum WidgetDataLoader {
    static func load(now: Date = .now) -> WidgetSnapshot {
        let context = DataStore.shared.mainContext
        RecurringService.processDue(in: context, now: now)
        let allowance = FinanceService.allowance(in: context, now: now)
        let calendar = AppCalendar.calendar
        let templates = (try? context.fetch(FetchDescriptor<Template>(sortBy: [SortDescriptor(\.order)]))) ?? []
        let tasks = PlannerService.todayItems(in: context, now: now)
        let accounts = ((try? context.fetch(FetchDescriptor<Account>())) ?? []).filter { !$0.archived }
        let debts = (try? context.fetch(FetchDescriptor<Debt>())) ?? []
        let debtTotals = DebtCalculator.totals(debts.map(\.snapshot)) { CurrencyService.toBase($0, from: $1) }
        let goals = ((try? context.fetch(FetchDescriptor<SavingsGoal>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []).filter { !$0.isArchived }
        let rules = ((try? context.fetch(FetchDescriptor<RecurringRule>(sortBy: [SortDescriptor(\.nextDate)]))) ?? [])
            .filter { $0.isActive && $0.type == .expense && ($0.isSubscription || $0.isMandatory) }
        let accountsTotal = accounts.filter { !$0.isSavings }.sum(\.balanceInBase)
        let savingsTotal = accounts.filter(\.isSavings).sum(\.balanceInBase)

        return WidgetSnapshot(
            hasBudget: allowance != nil,
            leftToday: allowance?.leftToday ?? 0,
            dailyLimit: allowance?.dailyLimit ?? 0,
            spentToday: allowance?.spentToday ?? FinanceService.expenses(in: calendar.dayInterval(for: now), context: context),
            spentMonth: allowance?.spentMonth ?? FinanceService.expenses(in: calendar.monthInterval(for: now), context: context),
            monthBudget: allowance?.monthBudget ?? 0,
            status: allowance?.status ?? .good,
            dayOfMonth: calendar.component(.day, from: now),
            daysInMonth: calendar.numberOfDays(inMonthOf: now),
            currency: SharedDefaults.currencyCode,
            templates: templates.filter { $0.type == .expense }.prefix(3).map {
                .init(id: $0.id, title: $0.title, amount: $0.amount, symbol: $0.category?.symbol ?? "bolt.fill", colorHex: $0.category?.colorHex ?? "#8E8E93")
            },
            tasks: tasks.map {
                .init(id: $0.id, title: $0.title, isDone: $0.isDone, time: $0.time, isMeeting: $0.type == .meeting)
            },
            goals: goals.prefix(3).map { .init(id: $0.id, name: $0.name, saved: $0.saved, target: $0.targetAmount, symbol: $0.symbol, colorHex: $0.colorHex) },
            owedToMe: debtTotals.owedToMe,
            iOwe: debtTotals.iOwe,
            subscriptions: rules.prefix(4).map { .init(id: $0.id, title: $0.title, amount: $0.amount, date: $0.nextDate, symbol: $0.category?.symbol ?? "repeat", colorHex: $0.category?.colorHex ?? "#5856D6") },
            netWorth: accountsTotal + savingsTotal + debtTotals.net,
            accountsTotal: accountsTotal,
            savingsTotal: savingsTotal
        )
    }
}

nonisolated struct FinanceEntry: TimelineEntry, Sendable {
    var date: Date
    var snapshot: WidgetSnapshot
}

/// Общий провайдер: обновление каждые 30 минут и ровно в полночь (новый дневной лимит).
nonisolated struct FinanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> FinanceEntry {
        FinanceEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (FinanceEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { @MainActor in
            completion(FinanceEntry(date: .now, snapshot: WidgetDataLoader.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<FinanceEntry>) -> Void) {
        Task { @MainActor in
            let now = Date.now
            let entry = FinanceEntry(date: now, snapshot: WidgetDataLoader.load(now: now))
            let midnight = AppCalendar.calendar.dayInterval(for: now).end
            let refresh = min(now.addingTimeInterval(30 * 60), midnight)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }
}
