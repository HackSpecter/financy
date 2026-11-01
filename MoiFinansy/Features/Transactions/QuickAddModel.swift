import Foundation
import Observation
import SwiftData

/// Состояние шторки быстрого добавления.
@Observable
final class QuickAddModel {
    var type: TransactionType
    var input = AmountInput()
    var note = ""
    var date = Date.now
    var account: Account?
    var toAccount: Account?
    var suggestedCategoryID: UUID?
    /// Счётчик для хаптика «нужно ввести сумму».
    var missingAmountAttempts = 0

    init(type: TransactionType = .expense) {
        self.type = type
    }

    var amount: Decimal? { input.decimal }

    func prepare(accounts: [Account]) {
        let active = accounts.filter { !$0.archived }
        if let id = SharedDefaults.lastAccountID, let last = active.first(where: { $0.id == id }) {
            account = last
        } else {
            account = active.first
        }
        toAccount = active.first { $0.id != account?.id }
    }

    func updateSuggestion(categories: [Category], history: [Transaction]) {
        let candidates = categories
            .filter { $0.kind == (type == .income ? .income : .expense) && !$0.archived }
            .map { CategorySuggester.Candidate(id: $0.id, name: $0.name, keywords: $0.keywords) }
        let allowed = Set(candidates.map(\.id))
        let past = history.prefix(300).compactMap { transaction -> (note: String, categoryID: UUID)? in
            guard !transaction.note.isEmpty, let id = transaction.category?.id, allowed.contains(id) else { return nil }
            return (transaction.note, id)
        }
        suggestedCategoryID = CategorySuggester.suggest(note: note, history: past, categories: candidates)
    }

    /// Сохраняет операцию; nil — если не введена сумма.
    func save(category: Category?, in context: ModelContext) -> Transaction? {
        guard let amount else {
            missingAmountAttempts += 1
            return nil
        }
        if type == .transfer, account == nil || toAccount == nil || account?.id == toAccount?.id {
            missingAmountAttempts += 1
            return nil
        }
        return TransactionService.add(
            type: type,
            amount: amount,
            category: category,
            account: account,
            toAccount: toAccount,
            date: date,
            note: note,
            in: context
        )
    }
}

/// Умная подсказка: шаблон или частая пара «категория + сумма».
struct QuickSuggestion: Identifiable, Hashable {
    enum Source: Hashable { case template(PersistentIdentifier), recent }

    var id: String
    var title: String
    var amount: Decimal
    var category: Category?
    var source: Source

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Шаблоны + самые частые комбинации за последние 60 дней.
    static func build(templates: [Template], transactions: [Transaction], type: TransactionType, now: Date = .now, limit: Int = 8) -> [QuickSuggestion] {
        let fromTemplates = templates
            .filter { $0.type == type }
            .sorted { ($0.useCount, -$0.order) > ($1.useCount, -$1.order) }
            .map {
                QuickSuggestion(id: "t-\($0.id)", title: $0.title, amount: $0.amount, category: $0.category, source: .template($0.persistentModelID))
            }

        let since = AppCalendar.calendar.date(byAdding: .day, value: -60, to: now) ?? now
        let recent = transactions.filter { $0.type == type && $0.date >= since && !$0.isRecurring && $0.category != nil }
        let grouped = Dictionary(grouping: recent) { "\($0.category!.id)-\($0.amount)" }
        let templateKeys = Set(fromTemplates.map { "\($0.category?.id.uuidString ?? "")-\($0.amount)" })
        let frequent = grouped
            .filter { $0.value.count >= 2 && !templateKeys.contains($0.key) }
            .sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .compactMap { key, items -> QuickSuggestion? in
                guard let first = items.first else { return nil }
                return QuickSuggestion(id: "r-\(key)", title: first.category?.name ?? "", amount: first.amount, category: first.category, source: .recent)
            }
        return Array((fromTemplates + frequent).prefix(limit))
    }
}
