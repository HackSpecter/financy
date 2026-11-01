import Foundation
import SwiftData

nonisolated enum DebtDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Мне должны (я дал в долг).
    case theyOwe
    /// Я должен (я взял в долг).
    case iOwe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theyOwe: "Мне должны"
        case .iOwe: "Я должен"
        }
    }
}

@Model
final class Debt {
    var id: UUID = UUID()
    var personName: String = ""
    var contactIdentifier: String = ""
    var directionRaw: String = DebtDirection.theyOwe.rawValue
    var amount: Decimal = 0
    var currencyCode: String = "TJS"
    var date: Date = Date.now
    var dueDate: Date?
    var note: String = ""
    var isClosed: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \DebtPayment.debt)
    var payments: [DebtPayment]? = []

    init(personName: String, direction: DebtDirection, amount: Decimal, currencyCode: String, date: Date = .now, dueDate: Date? = nil, note: String = "") {
        self.personName = personName
        self.directionRaw = direction.rawValue
        self.amount = amount
        self.currencyCode = currencyCode
        self.date = date
        self.dueDate = dueDate
        self.note = note
        self.createdAt = .now
    }

    var direction: DebtDirection {
        get { DebtDirection(rawValue: directionRaw) ?? .theyOwe }
        set { directionRaw = newValue.rawValue }
    }

    var paid: Decimal { (payments ?? []).sum(\.amount) }
    var remaining: Decimal { max(amount - paid, 0) }

    var snapshot: DebtSnapshot {
        DebtSnapshot(id: id, direction: direction, remaining: remaining, currencyCode: currencyCode, dueDate: dueDate, isClosed: isClosed)
    }
}

@Model
final class DebtPayment {
    var id: UUID = UUID()
    var amount: Decimal = 0
    var date: Date = Date.now
    var note: String = ""
    var debt: Debt?
    var transaction: Transaction?

    init(amount: Decimal, date: Date = .now, note: String = "", debt: Debt?) {
        self.amount = amount
        self.date = date
        self.note = note
        self.debt = debt
    }
}

nonisolated struct DebtSnapshot: Sendable, Hashable {
    var id: UUID
    var direction: DebtDirection
    var remaining: Decimal
    var currencyCode: String
    var dueDate: Date?
    var isClosed: Bool
}
