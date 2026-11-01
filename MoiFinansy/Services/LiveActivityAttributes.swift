import ActivityKit
import Foundation

/// Live Activity: остаток на сегодня на экране блокировки и в Dynamic Island.
nonisolated struct HisobActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var leftToday: Decimal
        var dailyLimit: Decimal
        var spentToday: Decimal
        var statusRaw: String
        var currency: String

        var progress: Double {
            guard dailyLimit > 0 else { return 1 }
            return min(max((spentToday / dailyLimit).chartValue, 0), 1)
        }
    }
}
