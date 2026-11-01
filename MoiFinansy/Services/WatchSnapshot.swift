import Foundation

/// Данные для Apple Watch и его комплекшна. Передаются с iPhone через WatchConnectivity.
nonisolated struct WatchSnapshot: Codable, Sendable, Equatable {
    struct CategoryItem: Codable, Sendable, Equatable, Identifiable {
        var id: UUID
        var name: String
        var symbol: String
        var colorHex: String
    }

    struct TaskItem: Codable, Sendable, Equatable, Identifiable {
        var id: UUID
        var title: String
        var isDone: Bool
        var time: Date?
    }

    var leftToday: Decimal
    var dailyLimit: Decimal
    var spentToday: Decimal
    var statusRaw: String
    var currency: String
    var hasBudget: Bool
    var categories: [CategoryItem]
    var tasks: [TaskItem]
    var updatedAt: Date

    static let empty = WatchSnapshot(leftToday: 0, dailyLimit: 0, spentToday: 0, statusRaw: "good", currency: "TJS", hasBudget: false, categories: [], tasks: [], updatedAt: .distantPast)

    static let storageKey = "watch.snapshot"
}

/// Сообщения с часов на iPhone.
nonisolated enum WatchCommand: Sendable {
    case expense(id: UUID, amount: Decimal, categoryID: UUID, date: Date)
    case toggleTask(id: UUID)

    var userInfo: [String: String] {
        switch self {
        case let .expense(id, amount, categoryID, date):
            ["kind": "expense", "id": id.uuidString, "amount": "\(amount)", "categoryID": categoryID.uuidString, "date": "\(date.timeIntervalSince1970)"]
        case let .toggleTask(id):
            ["kind": "toggleTask", "id": id.uuidString]
        }
    }

    init?(userInfo: [String: Any]) {
        guard let kind = userInfo["kind"] as? String, let id = (userInfo["id"] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
        switch kind {
        case "expense":
            guard let amount = (userInfo["amount"] as? String).flatMap({ Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }),
                  let categoryID = (userInfo["categoryID"] as? String).flatMap(UUID.init(uuidString:)),
                  let seconds = (userInfo["date"] as? String).flatMap(Double.init) else { return nil }
            self = .expense(id: id, amount: amount, categoryID: categoryID, date: Date(timeIntervalSince1970: seconds))
        case "toggleTask":
            self = .toggleTask(id: id)
        default:
            return nil
        }
    }
}
