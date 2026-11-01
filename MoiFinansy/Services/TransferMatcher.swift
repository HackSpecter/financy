import Foundation
import SwiftData

/// Связывает ручные переводы между своими счетами с SMS банка, чтобы не было дублей:
/// перевод с Alif в Копилку + SMS «Списание» с Alif = один перевод, а не перевод и «Покупки».
enum TransferMatcher {
    static let window: TimeInterval = 2 * 60 * 60

    /// Ручной перевод, который уже описывает это SMS (та же сумма, тот же счёт, ±2 часа).
    static func manualTransfer(for amount: Decimal, outgoing: Bool, account: Account, near date: Date, in context: ModelContext) -> Transaction? {
        let from = date.addingTimeInterval(-window)
        let to = date.addingTimeInterval(window)
        let transfer = TransactionType.transfer.rawValue
        let sms = TransactionSource.sms.rawValue
        let candidates = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.typeRaw == transfer && $0.sourceRaw != sms && $0.date >= from && $0.date <= to
        }))) ?? []
        return candidates.first { candidate in
            if outgoing {
                return candidate.account?.id == account.id && candidate.amount == amount && (candidate.importLogs ?? []).isEmpty
            }
            return candidate.toAccount?.id == account.id && (candidate.toAmount ?? candidate.amount) == amount && (candidate.importLogs ?? []).isEmpty
        }
    }

    /// Новый ручной перевод: SMS-расход с этого счёта (или доход на счёт назначения) на ту же сумму
    /// превращается в этот перевод — SMS-операция удаляется, журнал SMS ссылается на перевод.
    static func absorbSMSOperations(into transfer: Transaction, in context: ModelContext) {
        guard transfer.type == .transfer else { return }
        let from = transfer.date.addingTimeInterval(-window)
        let to = transfer.date.addingTimeInterval(window)
        let sms = TransactionSource.sms.rawValue
        let candidates = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.sourceRaw == sms && $0.date >= from && $0.date <= to
        }))) ?? []
        let outgoing = candidates.first {
            $0.type == .expense && $0.account?.id == transfer.account?.id && $0.amount == transfer.amount
        }
        let incoming = candidates.first {
            $0.type == .income && $0.account?.id == transfer.toAccount?.id && $0.amount == (transfer.toAmount ?? transfer.amount)
        }
        for smsOperation in [outgoing, incoming].compactMap({ $0 }) {
            if transfer.cardLast4.isEmpty { transfer.cardLast4 = smsOperation.cardLast4 }
            for log in smsOperation.importLogs ?? [] {
                log.transaction = transfer
                log.status = .merged
                log.summary = "Перевод \(transfer.displayTitle): \(Money.format(transfer.amount))"
            }
            context.delete(smsOperation)
        }
        try? context.save()
    }
}
