import Foundation
import SwiftData

/// Один раз после обновления: баланс каждой карты = последний «Остаток» из её SMS.
enum SMSBalanceSync {
    static func alignOnceIfNeeded(in context: ModelContext) {
        let flag = "seed.sms.v3"
        guard !SharedDefaults.store.bool(forKey: flag) else { return }
        SharedDefaults.store.set(true, forKey: flag)
        guard SMSImportService.autoReconcile else { return }

        let cards = (try? context.fetch(FetchDescriptor<BankCard>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<SMSImportLog>())) ?? []
        for card in cards {
            guard let account = card.account,
                  let latest = logs
                    .filter({ $0.cardLast4 == card.last4 && $0.balance != nil })
                    .max(by: { ($0.operationDate ?? $0.receivedAt) < ($1.operationDate ?? $1.receivedAt) }),
                  let balance = latest.balance else { continue }
            let difference = balance - account.balance
            guard abs(difference) >= Decimal(string: "0.01")! else { continue }
            context.insert(Transaction(type: .adjustment, amount: difference, account: account, date: .now, note: "Сверка с банком"))
        }
        for log in logs { log.balanceDifference = nil }
        try? context.save()
        WidgetRefresher.reload()
    }
}
