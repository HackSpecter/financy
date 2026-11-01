import Foundation
import SwiftData

/// Цель накопления: «Телефон», «Отпуск».
@Model
final class SavingsGoal {
    var id: UUID = UUID()
    var name: String = ""
    var targetAmount: Decimal = 0
    var deadline: Date?
    var symbol: String = "star.fill"
    var colorHex: String = "#34C759"
    var createdAt: Date = Date.now
    var isArchived: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \GoalContribution.goal)
    var contributions: [GoalContribution]? = []

    init(name: String, targetAmount: Decimal, deadline: Date?, symbol: String, colorHex: String) {
        self.name = name
        self.targetAmount = targetAmount
        self.deadline = deadline
        self.symbol = symbol
        self.colorHex = colorHex
        self.createdAt = .now
    }

    var saved: Decimal { (contributions ?? []).sum(\.amount) }

    var progress: GoalCalculator.Progress {
        GoalCalculator.progress(
            target: targetAmount,
            contributions: (contributions ?? []).map { ($0.amount, $0.date) },
            createdAt: createdAt,
            deadline: deadline,
            now: .now,
            calendar: AppCalendar.calendar
        )
    }
}

@Model
final class GoalContribution {
    var id: UUID = UUID()
    var amount: Decimal = 0
    var date: Date = Date.now
    var note: String = ""
    var goal: SavingsGoal?

    init(amount: Decimal, date: Date = .now, note: String = "", goal: SavingsGoal?) {
        self.amount = amount
        self.date = date
        self.note = note
        self.goal = goal
    }
}
