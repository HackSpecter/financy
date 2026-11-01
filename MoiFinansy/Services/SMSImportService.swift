import Foundation
import SwiftData

/// Импорт операции из текста SMS (или распознанного скриншота): карта → счёт, дубли, категории, сверка баланса.
enum SMSImportService {
    struct Result {
        var log: SMSImportLog
        var transaction: Transaction?
        var message: String
    }

    static let duplicateWindow: TimeInterval = 120

    /// Читать SMS только по карточкам из настроек.
    static var onlyKnownCards: Bool {
        get { SharedDefaults.store.object(forKey: "sms.onlyKnownCards") as? Bool ?? true }
        set { SharedDefaults.store.set(newValue, forKey: "sms.onlyKnownCards") }
    }

    /// Баланс счёта всегда равен «Остатку» из SMS банка (корректировка создаётся сама).
    static var autoReconcile: Bool {
        get { SharedDefaults.store.object(forKey: "sms.autoReconcile") as? Bool ?? true }
        set { SharedDefaults.store.set(newValue, forKey: "sms.autoReconcile") }
    }

    @discardableResult
    static func process(
        text rawText: String,
        sender: String? = nil,
        source: TransactionSource = .sms,
        receivedAt: Date = .now,
        in context: ModelContext
    ) -> Result {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = SMSImportLog(text: text, sender: sender ?? "", source: source)
        log.receivedAt = receivedAt
        context.insert(log)

        func finish(_ status: SMSImportStatus, _ message: String, _ transaction: Transaction? = nil) -> Result {
            log.status = status
            log.summary = message
            log.transaction = transaction
            try? context.save()
            if transaction != nil { TransactionService.didChange(in: context, category: transaction?.category) }
            return Result(log: log, transaction: transaction, message: message)
        }

        let outcome = BankSMSParser.parse(text, sender: sender, rules: enabledRules(in: context), baseCurrency: SharedDefaults.currencyCode)
        let parsed: BankSMSParser.Parsed
        switch outcome {
        case .ignored(let reason):
            // Коды подтверждения и реклама не хранятся: остаётся только причина.
            log.text = ""
            return finish(.ignored, reason)
        case .unrecognized(let reason): return finish(.unrecognized, reason)
        case .transaction(let value): parsed = value
        }

        log.amount = parsed.amount
        log.balance = parsed.balance
        log.cardLast4 = parsed.cardLast4 ?? ""
        log.ruleName = parsed.ruleName
        log.operationDate = parsed.date
        let date = parsed.date ?? receivedAt

        // Карта → счёт.
        let cards = ((try? context.fetch(FetchDescriptor<BankCard>())) ?? [])
        let card: BankCard?
        if let last4 = parsed.cardLast4 {
            card = cards.first { $0.last4 == last4 }
            if card == nil || card?.isActive == false, onlyKnownCards, !cards.isEmpty {
                return finish(.unknownCard, "Карта •\(last4) не отслеживается — добавьте её в настройках SMS")
            }
        } else {
            // Нет номера карты: при «только мои карты» такое SMS не меняет счета.
            if onlyKnownCards, !cards.isEmpty {
                return finish(.unknownCard, "В SMS нет номера карты — операция не записана")
            }
            let active = cards.filter(\.isActive)
            card = active.count == 1 ? active.first : nil
        }
        guard let account = card?.account ?? TransactionService.lastAccount(in: context) else {
            return finish(.unrecognized, "Нет счёта для записи операции")
        }

        // Дубли: та же сумма + карта ± 2 минуты (если остаток другой — это разные операции).
        if isDuplicate(parsed, date: date, excluding: log, in: context) {
            return finish(.duplicate, "Уже записано: \(Money.format(parsed.amount, currency: parsed.currency))")
        }

        // Перевод между своими картами: пара «списание + зачисление» на одну сумму.
        if let pair = ownTransferPair(for: parsed, account: account, date: date, in: context) {
            let from = parsed.kind.isOutgoing ? account : pair.account
            let to = parsed.kind.isOutgoing ? pair.account : account
            pair.type = .transfer
            pair.account = from
            pair.toAccount = to
            pair.category = nil
            pair.needsReview = false
            pair.merchant = ""
            pair.note = "Перевод между своими картами"
            reconcile(log: log, parsed: parsed, account: account)
            if autoReconcile, log.hasBalanceMismatch { adjustBalance(for: log, account: account, in: context) }
            return finish(.merged, "Перевод \(from?.name ?? "") → \(to?.name ?? ""): \(Money.format(parsed.amount, currency: parsed.currency))", pair)
        }

        // Перевод между своими счетами, записанный вручную: SMS только подтверждает его.
        if [.debit, .purchase, .transferOut, .credit, .transferIn].contains(parsed.kind),
           let manual = TransferMatcher.manualTransfer(for: parsed.amount, outgoing: parsed.kind.isOutgoing, account: account, near: date, in: context) {
            if manual.cardLast4.isEmpty { manual.cardLast4 = parsed.cardLast4 ?? "" }
            reconcile(log: log, parsed: parsed, account: account)
            if autoReconcile, log.hasBalanceMismatch { adjustBalance(for: log, account: account, in: context) }
            return finish(.merged, "Перевод \(manual.displayTitle): \(Money.format(parsed.amount, currency: parsed.currency)) — уже записан", manual)
        }

        // Зарплата по SMS: обновляем уже созданную запланированную «Зарплату» вместо второго дохода.
        if parsed.kind.transactionType == .income,
           let rule = SalaryMatcher.rule(forIncome: parsed.amount, at: date, in: context),
           let planned = SalaryMatcher.plannedTransaction(for: rule, near: date, in: context) {
            planned.amount = parsed.amount
            planned.account = account
            planned.date = date
            planned.source = source
            planned.cardLast4 = parsed.cardLast4 ?? ""
            planned.needsReview = false
            try? context.save()
            reconcile(log: log, parsed: parsed, account: account)
            if autoReconcile, log.hasBalanceMismatch { adjustBalance(for: log, account: account, in: context) }
            return finish(.imported, "Зарплата \(Money.format(parsed.amount, currency: parsed.currency)) — обновлена по SMS", planned)
        }

        let transaction: Transaction
        if parsed.kind == .cashWithdrawal, let cash = cashAccount(excluding: account, in: context) {
            transaction = Transaction(type: .transfer, amount: parsed.amount, account: account, toAccount: cash, date: date, note: "Снятие наличных")
        } else {
            let type = parsed.kind.transactionType
            let category = suggestCategory(for: parsed, type: type, in: context)
            transaction = Transaction(type: type, amount: parsed.amount, category: category, account: account, date: date, note: parsed.merchant ?? "")
            transaction.needsReview = category == nil
        }
        transaction.merchant = parsed.merchant ?? ""
        transaction.cardLast4 = parsed.cardLast4 ?? ""
        transaction.source = source
        context.insert(transaction)
        try? context.save()
        SavingsService.handleIncome(transaction, in: context)
        MotivationService.checkSpending(transaction, in: context)

        reconcile(log: log, parsed: parsed, account: account)
        if autoReconcile, log.hasBalanceMismatch {
            adjustBalance(for: log, account: account, in: context)
        }

        let message = summary(for: transaction, parsed: parsed)
        let result = finish(transaction.needsReview ? .needsReview : .imported, message, transaction)
        if transaction.needsReview {
            InboxNotifications.notify(transaction)
        }
        return result
    }

    // MARK: Шаги

    static func enabledRules(in context: ModelContext) -> [SMSRuleDefinition] {
        let rules = (try? context.fetch(FetchDescriptor<BankSMSRule>(sortBy: [SortDescriptor(\.order)]))) ?? []
        return rules.filter(\.isEnabled).map(\.definition)
    }

    private static func isDuplicate(_ parsed: BankSMSParser.Parsed, date: Date, excluding log: SMSImportLog, in context: ModelContext) -> Bool {
        let from = date.addingTimeInterval(-duplicateWindow)
        let to = date.addingTimeInterval(duplicateWindow)
        let descriptor = FetchDescriptor<SMSImportLog>(predicate: #Predicate { log in
            log.operationDate != nil
        })
        let logs = (try? context.fetch(descriptor)) ?? []
        let card = parsed.cardLast4 ?? ""
        return logs.contains { other in
            guard other.id != log.id,
                  other.transaction != nil,
                  let otherDate = other.operationDate, otherDate >= from, otherDate <= to,
                  other.amount == parsed.amount,
                  other.cardLast4 == card else { return false }
            if let balance = parsed.balance, let otherBalance = other.balance, balance != otherBalance { return false }
            return true
        }
    }

    private static func ownTransferPair(for parsed: BankSMSParser.Parsed, account: Account, date: Date, in context: ModelContext) -> Transaction? {
        guard [.transferOut, .transferIn, .debit, .credit].contains(parsed.kind) else { return nil }
        let from = date.addingTimeInterval(-duplicateWindow)
        let to = date.addingTimeInterval(duplicateWindow)
        let amount = parsed.amount
        let sms = TransactionSource.sms.rawValue
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { transaction in
            transaction.date >= from && transaction.date <= to && transaction.amount == amount && transaction.sourceRaw == sms
        })
        let candidates = (try? context.fetch(descriptor)) ?? []
        let opposite: TransactionType = parsed.kind.isOutgoing ? .income : .expense
        return candidates.first { candidate in
            candidate.type == opposite && candidate.account != nil && candidate.account?.id != account.id && !candidate.cardLast4.isEmpty
        }
    }

    private static func cashAccount(excluding account: Account, in context: ModelContext) -> Account? {
        let accounts = (try? context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))) ?? []
        return accounts.first { $0.id != account.id && !$0.archived && !$0.isSavings && ($0.name.localizedCaseInsensitiveContains("налич") || $0.symbol == "banknote.fill") && ($0.cards ?? []).isEmpty }
    }

    /// Правила «магазин → категория», затем ключевые слова категорий; зарплату узнаём по сумме.
    static func suggestCategory(for parsed: BankSMSParser.Parsed, type: TransactionType, in context: ModelContext) -> Category? {
        if let merchant = parsed.merchant, let category = MerchantRuleService.category(for: merchant, type: type, in: context) {
            return category
        }
        if type == .income, let salary = SalaryMatcher.rule(forIncome: parsed.amount, at: parsed.date ?? .now, in: context) {
            return salary.category
        }
        // Магазина нет — категория по типу SMS из настроек.
        return SMSKindDefaults.category(for: parsed.kind, in: context)
    }

    /// Сравнение остатка из SMS с балансом счёта в приложении.
    static func reconcile(log: SMSImportLog, parsed: BankSMSParser.Parsed, account: Account) {
        guard let balance = parsed.balance else { return }
        let difference = balance - account.balance
        log.balanceDifference = abs(difference) >= Decimal(string: "0.01")! ? difference : nil
    }

    /// Операция-корректировка, чтобы баланс совпал с банком.
    @discardableResult
    /// `account` — счёт карты из этого SMS (для склеенного перевода это не обязательно `transaction.account`).
    static func adjustBalance(for log: SMSImportLog, account explicitAccount: Account? = nil, in context: ModelContext) -> Transaction? {
        let cardAccount = explicitAccount ?? cardAccount(for: log, in: context)
        guard let difference = log.balanceDifference, let account = cardAccount ?? log.transaction?.account ?? log.transaction?.toAccount else { return nil }
        let adjustment = Transaction(type: .adjustment, amount: difference, account: account, date: .now, note: "Сверка с банком")
        context.insert(adjustment)
        log.balanceDifference = nil
        try? context.save()
        WidgetRefresher.reload()
        return adjustment
    }

    private static func cardAccount(for log: SMSImportLog, in context: ModelContext) -> Account? {
        guard !log.cardLast4.isEmpty else { return nil }
        let last4 = log.cardLast4
        return try? context.fetch(FetchDescriptor<BankCard>(predicate: #Predicate { $0.last4 == last4 })).first?.account
    }

    static func summary(for transaction: Transaction, parsed: BankSMSParser.Parsed) -> String {
        let amount = Money.format(parsed.amount, currency: parsed.currency)
        let where_ = transaction.account.map { ", \($0.name)" } ?? ""
        switch transaction.type {
        case .transfer:
            return "Перевод \(amount): \(transaction.displayTitle)"
        default:
            let category = transaction.category?.name ?? "во «Входящих»"
            return "\(transaction.type.title) \(amount) — \(category)\(where_)"
        }
    }

    /// Удаляет тексты SMS старше N дней (0 — хранить всегда).
    static func purgeOldLogs(in context: ModelContext, now: Date = .now) {
        let days = SharedDefaults.store.object(forKey: "sms.keepDays") as? Int ?? 30
        guard days > 0, let cutoff = AppCalendar.calendar.date(byAdding: .day, value: -days, to: now) else { return }
        let descriptor = FetchDescriptor<SMSImportLog>(predicate: #Predicate { $0.receivedAt < cutoff })
        for log in (try? context.fetch(descriptor)) ?? [] {
            context.delete(log)
        }
        try? context.save()
    }

    /// Пробный разбор без записи — для экранов настройки.
    static func preview(_ text: String, sender: String? = nil, in context: ModelContext) -> BankSMSParser.Outcome {
        BankSMSParser.parse(text, sender: sender, rules: enabledRules(in: context), baseCurrency: SharedDefaults.currencyCode)
    }
}

/// Правила «магазин → категория».
enum MerchantRuleService {
    static func normalize(_ merchant: String) -> String {
        merchant
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(.whitespaces))
            .joined()
            .components(separatedBy: .decimalDigits)
            .joined()
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Ключ без привязки к SwiftData — для чистых расчётов.
    nonisolated static func normalizeKey(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .filter { $0.isLetter || $0 == " " }
            .split(separator: " ")
            .joined(separator: " ")
    }

    static func category(for merchant: String, type: TransactionType, in context: ModelContext) -> Category? {
        let name = normalize(merchant)
        guard !name.isEmpty else { return nil }
        let kind: CategoryKind = type == .income ? .income : .expense
        let rules = (try? context.fetch(FetchDescriptor<MerchantRule>())) ?? []
        // Пользовательские правила важнее встроенных, длинные — точнее коротких.
        let match = rules
            .filter { !$0.pattern.isEmpty && name.contains($0.pattern) && $0.category?.kind == kind && $0.category?.archived == false }
            .sorted { ($0.isUserDefined ? 1 : 0, $0.pattern.count) > ($1.isUserDefined ? 1 : 0, $1.pattern.count) }
            .first
        if let match {
            match.useCount += 1
            return match.category
        }
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let candidates = categories
            .filter { $0.kind == kind && !$0.archived }
            .map { CategorySuggester.Candidate(id: $0.id, name: $0.name, keywords: $0.keywords) }
        guard let id = CategorySuggester.suggest(note: merchant, history: [], categories: candidates) else { return nil }
        return categories.first { $0.id == id }
    }

    /// Запоминает выбор пользователя: в следующий раз категория подставится сама.
    static func learn(merchant: String, category: Category, in context: ModelContext) {
        let pattern = normalize(merchant)
        guard pattern.count >= 2 else { return }
        let rules = (try? context.fetch(FetchDescriptor<MerchantRule>())) ?? []
        if let existing = rules.first(where: { $0.pattern == pattern }) {
            existing.category = category
            existing.isUserDefined = true
        } else {
            context.insert(MerchantRule(pattern: pattern, category: category, isUserDefined: true))
        }
        try? context.save()
    }
}

/// Папка «Входящие»: разбор операций без категории.
enum InboxService {
    static func categorize(_ transaction: Transaction, as category: Category, in context: ModelContext) {
        transaction.category = category
        transaction.needsReview = false
        if !transaction.merchant.isEmpty {
            MerchantRuleService.learn(merchant: transaction.merchant, category: category, in: context)
        }
        for log in transaction.importLogs ?? [] where log.status == .needsReview {
            log.status = .imported
            log.summary = "\(transaction.type.title) \(Money.format(transaction.amount)) — \(category.name)"
        }
        try? context.save()
        InboxNotifications.remove(transaction)
        TransactionService.didChange(in: context, category: category)
    }

    static func count(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<Transaction>(predicate: #Predicate { $0.needsReview }))) ?? 0
    }
}
