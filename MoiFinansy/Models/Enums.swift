import Foundation

nonisolated enum TransactionType: String, Codable, CaseIterable, Identifiable, Sendable {
    /// `adjustment` — корректировка баланса: меняет остаток счёта, но не попадает в отчёты.
    case expense, income, transfer, adjustment

    var id: String { rawValue }

    /// Типы, которые пользователь выбирает вручную.
    static let userCases: [TransactionType] = [.expense, .income, .transfer]

    var title: String {
        switch self {
        case .expense: "Расход"
        case .income: "Доход"
        case .transfer: "Перевод"
        case .adjustment: "Корректировка"
        }
    }

    var symbol: String {
        switch self {
        case .expense: "arrow.down.circle.fill"
        case .income: "arrow.up.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        case .adjustment: "plusminus.circle.fill"
        }
    }
}

nonisolated enum CategoryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense, income

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: "Расходы"
        case .income: "Доходы"
        }
    }
}

nonisolated enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily, weekly, monthly, yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Каждый день"
        case .weekly: "Каждую неделю"
        case .monthly: "Каждый месяц"
        case .yearly: "Каждый год"
        }
    }
}

nonisolated enum PlannerItemType: String, Codable, CaseIterable, Identifiable, Sendable {
    case task, meeting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task: "Задача"
        case .meeting: "Встреча"
        }
    }

    var symbol: String {
        switch self {
        case .task: "checklist"
        case .meeting: "person.2.fill"
        }
    }
}

nonisolated enum PlannerPriority: Int, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case none = 0, low, medium, high

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "Без приоритета"
        case .low: "Низкий"
        case .medium: "Средний"
        case .high: "Высокий"
        }
    }

    var marks: String {
        String(repeating: "!", count: rawValue)
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Откуда пришла операция.
nonisolated enum TransactionSource: String, Codable, CaseIterable, Sendable {
    case manual, recurring, sms, share, receipt, statement

    var title: String {
        switch self {
        case .manual: "Вручную"
        case .recurring: "Регулярная"
        case .sms: "SMS банка"
        case .share: "Скриншот / текст"
        case .receipt: "Чек"
        case .statement: "Выписка"
        }
    }

    var symbol: String {
        switch self {
        case .manual: "hand.tap"
        case .recurring: "repeat"
        case .sms: "message.fill"
        case .share: "square.and.arrow.down"
        case .receipt: "doc.text.viewfinder"
        case .statement: "tablecells"
        }
    }
}
