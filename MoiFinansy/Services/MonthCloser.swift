import Foundation
import SwiftData

/// Итоги месяца — снимок для архива и PDF.
nonisolated struct MonthSummary: Codable, Sendable, Equatable {
    struct Item: Codable, Sendable, Equatable, Identifiable {
        var name: String
        var symbol: String
        var colorHex: String
        var amount: Decimal
        var share: Decimal
        var id: String { name }
    }

    struct Change: Codable, Sendable, Equatable, Identifiable {
        var name: String
        var delta: Decimal
        var change: Decimal?
        var id: String { name }
    }

    var month: Date
    var income: Decimal
    var expense: Decimal
    var saved: Decimal
    var previousExpense: Decimal
    var topCategories: [Item]
    /// Где потратили меньше, чем в прошлом месяце.
    var best: [Change]
    /// Где потратили больше.
    var worst: [Change]
    var insights: [String]

    var balance: Decimal { income - expense }
    var savingsRate: Decimal? { income > 0 ? (income - expense) / income : nil }
    var expenseChange: Decimal? { previousExpense > 0 ? (expense - previousExpense) / previousExpense : nil }
}

nonisolated enum MonthCloser {
    static func summary(
        entries: [MoneyEntry],
        categories: [UUID: CategoryInfo],
        saved: Decimal,
        month: Date,
        now: Date,
        calendar: Calendar
    ) -> MonthSummary {
        let interval = calendar.monthInterval(for: month)
        let previous = calendar.monthInterval(for: calendar.date(byAdding: .month, value: -1, to: month) ?? month)
        let current = ReportCalculator.byCategory(entries, in: interval)
        let before = ReportCalculator.byCategory(entries, in: previous)
        let comparisons = ReportCalculator.compare(current: current, previous: before)
        let summary = ReportCalculator.summary(entries, in: interval, now: min(now, interval.end.addingTimeInterval(-1)), calendar: calendar)

        func info(_ id: UUID?) -> CategoryInfo {
            id.flatMap { categories[$0] } ?? CategoryInfo(id: UUID(), name: "Без категории", symbol: "questionmark", colorHex: "#8E8E93")
        }
        let changes = comparisons.filter { $0.previous > 0 || $0.current > 0 }.map {
            MonthSummary.Change(name: info($0.categoryID).name, delta: $0.delta, change: $0.change)
        }
        return MonthSummary(
            month: interval.start,
            income: summary.income,
            expense: summary.expense,
            saved: saved,
            previousExpense: before.sum(\.amount),
            topCategories: current.prefix(5).map {
                let category = info($0.categoryID)
                return .init(name: category.name, symbol: category.symbol, colorHex: category.colorHex, amount: $0.amount, share: $0.share)
            },
            best: Array(changes.filter { $0.delta < 0 }.sorted { $0.delta < $1.delta }.prefix(3)),
            worst: Array(changes.filter { $0.delta > 0 }.sorted { $0.delta > $1.delta }.prefix(3)),
            insights: InsightsEngine.make(comparisons: comparisons, currentTotals: current, summary: summary, categories: categories, periodName: "в этом месяце").map(\.text)
        )
    }
}

/// Закрытие месяцев: архив, напоминание в последний день.
enum MonthCloseService {
    /// Создаёт итог прошлого месяца, если его ещё нет.
    static func closePastMonthIfNeeded(in context: ModelContext, now: Date = .now) {
        let calendar = AppCalendar.calendar
        guard let previous = calendar.date(byAdding: .month, value: -1, to: calendar.startOfMonth(for: now)) else { return }
        let closures = (try? context.fetch(FetchDescriptor<MonthClosure>())) ?? []
        guard !closures.contains(where: { calendar.isDate($0.month, equalTo: previous, toGranularity: .month) }) else { return }
        let interval = calendar.monthInterval(for: previous)
        let start = interval.start
        let end = interval.end
        let count = (try? context.fetchCount(FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? 0
        guard count > 0 else { return }
        close(month: previous, in: context, now: now)
    }

    @discardableResult
    static func close(month: Date, in context: ModelContext, now: Date = .now) -> MonthClosure {
        let calendar = AppCalendar.calendar
        let summary = summary(for: month, in: context, now: now)
        let closures = (try? context.fetch(FetchDescriptor<MonthClosure>())) ?? []
        for old in closures where calendar.isDate(old.month, equalTo: month, toGranularity: .month) {
            context.delete(old)
        }
        let closure = MonthClosure(summary: summary)
        context.insert(closure)
        try? context.save()
        return closure
    }

    static func summary(for month: Date, in context: ModelContext, now: Date = .now) -> MonthSummary {
        let calendar = AppCalendar.calendar
        let interval = calendar.monthInterval(for: month)
        let from = calendar.date(byAdding: .month, value: -1, to: interval.start) ?? interval.start
        let end = interval.end
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.date >= from && $0.date < end }))) ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let saved = transactions
            .filter { interval.contains($0.date) && $0.type == .transfer && $0.toAccount?.isSavings == true && $0.account?.isSavings != true }
            .sum { CurrencyService.toBase($0.amount, from: $0.currencyCode) }
        return MonthCloser.summary(
            entries: transactions.map(\.entry),
            categories: Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.info) }),
            saved: saved,
            month: month,
            now: now,
            calendar: calendar
        )
    }

    /// Напоминание в последний день месяца в 20:00.
    static func scheduleLastDayReminder(now: Date = .now) {
        let calendar = AppCalendar.calendar
        let lastDay = calendar.date(byAdding: .day, value: -1, to: calendar.endOfMonth(for: now)) ?? now
        guard let date = calendar.date(byAdding: .hour, value: 20, to: calendar.startOfDay(for: lastDay)) else { return }
        let id = "month-close-\(now.appFormatted("yyyyMM"))"
        Task { await NotificationService.schedule(id: id, title: "Месяц закрыт", body: "Посмотрите итоги: сколько потрачено, отложено и где получилось сэкономить", at: date) }
    }
}
