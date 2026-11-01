import Foundation
import SwiftData

/// Месячный лимит. `category == nil` — общий лимит на месяц.
@Model
final class Budget {
    var id: UUID = UUID()
    var limit: Decimal = 0
    var category: Category?
    var createdAt: Date = Date.now

    init(limit: Decimal, category: Category? = nil) {
        self.limit = limit
        self.category = category
        self.createdAt = .now
    }

    var isTotal: Bool { category == nil }
}
