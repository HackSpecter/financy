import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Резервная копия всех данных в JSON.
enum BackupService {
    struct Backup: Codable {
        var version = 2
        var exportedAt = Date.now
        var currency: String
        var categories: [CategoryDTO]
        var accounts: [AccountDTO]
        var transactions: [TransactionDTO]
        var budgets: [BudgetDTO]
        var rules: [RuleDTO]
        var templates: [TemplateDTO]
        var planner: [PlannerDTO]
        // Версия 2: всё новое необязательно — копии v1 читаются как раньше.
        var cards: [CardDTO]? = nil
        var smsRules: [SMSRuleDTO]? = nil
        var merchantRules: [MerchantRuleDTO]? = nil
        var importLogs: [ImportLogDTO]? = nil
        var attachments: [AttachmentDTO]? = nil
        var goals: [GoalDTO]? = nil
        var debts: [DebtDTO]? = nil
        var envelopes: [EnvelopeDTO]? = nil
        var closures: [ClosureDTO]? = nil
        var settings: [String: String]? = nil
    }

    struct CardDTO: Codable { var id: UUID, last4: String, name: String, bankName: String, isActive: Bool, accountID: UUID? }
    struct SMSRuleDTO: Codable { var id: UUID, order: Int, isEnabled: Bool, isBuiltIn: Bool, definition: SMSRuleDefinition }
    struct MerchantRuleDTO: Codable { var id: UUID, pattern: String, categoryID: UUID?, useCount: Int, isUserDefined: Bool }
    struct ImportLogDTO: Codable {
        var id: UUID, receivedAt: Date, sender: String, text: String, status: String, summary: String, ruleName: String
        var cardLast4: String, amount: Decimal?, balance: Decimal?, balanceDifference: Decimal?, operationDate: Date?, source: String, transactionID: UUID?
    }
    struct AttachmentDTO: Codable { var id: UUID, data: Data, kind: String, createdAt: Date, transactionID: UUID? }
    struct GoalDTO: Codable {
        struct Contribution: Codable { var id: UUID, amount: Decimal, date: Date, note: String }
        var id: UUID, name: String, targetAmount: Decimal, deadline: Date?, symbol: String, colorHex: String, createdAt: Date, isArchived: Bool, contributions: [Contribution]
    }
    struct DebtDTO: Codable {
        struct Payment: Codable { var id: UUID, amount: Decimal, date: Date, note: String, transactionID: UUID? }
        var id: UUID, personName: String, contactIdentifier: String, direction: String, amount: Decimal, currencyCode: String
        var date: Date, dueDate: Date?, note: String, isClosed: Bool, createdAt: Date, payments: [Payment]
    }
    struct EnvelopeDTO: Codable { var id: UUID, name: String, symbol: String, colorHex: String, monthlyAmount: Decimal, order: Int, categoryIDs: [UUID] }
    struct ClosureDTO: Codable { var id: UUID, month: Date, createdAt: Date, income: Decimal, expense: Decimal, saved: Decimal, summaryData: Data }

    struct CategoryDTO: Codable {
        var id: UUID, name: String, symbol: String, colorHex: String, kind: String, order: Int, archived: Bool, keywords: String
    }

    struct AccountDTO: Codable {
        var id: UUID, name: String, symbol: String, colorHex: String, initialBalance: Decimal, order: Int, archived: Bool
        var currencyCode: String? = nil, isSavings: Bool? = nil, balanceInclusion: Int? = nil
    }

    struct TransactionDTO: Codable {
        var id: UUID, type: String, amount: Decimal, categoryID: UUID?, accountID: UUID?, toAccountID: UUID?
        var date: Date, note: String, isRecurring: Bool, createdAt: Date
        var merchant: String? = nil, needsReview: Bool? = nil, source: String? = nil, cardLast4: String? = nil, tags: String? = nil, toAmount: Decimal? = nil
    }

    struct BudgetDTO: Codable {
        var id: UUID, limit: Decimal, categoryID: UUID?
    }

    struct RuleDTO: Codable {
        var id: UUID, title: String, type: String, amount: Decimal, categoryID: UUID?, accountID: UUID?
        var frequency: String, dayOfMonth: Int, startDate: Date, nextDate: Date, isActive: Bool, isMandatory: Bool
        var isSubscription: Bool? = nil, remindDaysBefore: Int? = nil
    }

    struct TemplateDTO: Codable {
        var id: UUID, title: String, type: String, amount: Decimal, categoryID: UUID?, accountID: UUID?, order: Int, useCount: Int
    }

    struct PlannerDTO: Codable {
        var id: UUID, title: String, type: String, date: Date, time: Date?, note: String
        var isDone: Bool, doneAt: Date?, reminder: Date?, priority: Int, createdAt: Date
    }

    static func makeBackup(from context: ModelContext) throws -> Backup {
        Backup(
            currency: SharedDefaults.currencyCode,
            categories: try context.fetch(FetchDescriptor<Category>()).map {
                CategoryDTO(id: $0.id, name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex, kind: $0.kindRaw, order: $0.order, archived: $0.archived, keywords: $0.keywords)
            },
            accounts: try context.fetch(FetchDescriptor<Account>()).map {
                AccountDTO(id: $0.id, name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex, initialBalance: $0.initialBalance, order: $0.order, archived: $0.archived, currencyCode: $0.currencyCode, isSavings: $0.isSavings, balanceInclusion: $0.balanceInclusionRaw)
            },
            transactions: try context.fetch(FetchDescriptor<Transaction>()).map {
                TransactionDTO(id: $0.id, type: $0.typeRaw, amount: $0.amount, categoryID: $0.category?.id, accountID: $0.account?.id, toAccountID: $0.toAccount?.id, date: $0.date, note: $0.note, isRecurring: $0.isRecurring, createdAt: $0.createdAt, merchant: $0.merchant, needsReview: $0.needsReview, source: $0.sourceRaw, cardLast4: $0.cardLast4, tags: $0.tagsRaw, toAmount: $0.toAmount)
            },
            budgets: try context.fetch(FetchDescriptor<Budget>()).map {
                BudgetDTO(id: $0.id, limit: $0.limit, categoryID: $0.category?.id)
            },
            rules: try context.fetch(FetchDescriptor<RecurringRule>()).map {
                RuleDTO(id: $0.id, title: $0.title, type: $0.typeRaw, amount: $0.amount, categoryID: $0.category?.id, accountID: $0.account?.id, frequency: $0.frequencyRaw, dayOfMonth: $0.dayOfMonth, startDate: $0.startDate, nextDate: $0.nextDate, isActive: $0.isActive, isMandatory: $0.isMandatory, isSubscription: $0.isSubscription, remindDaysBefore: $0.remindDaysBefore)
            },
            templates: try context.fetch(FetchDescriptor<Template>()).map {
                TemplateDTO(id: $0.id, title: $0.title, type: $0.typeRaw, amount: $0.amount, categoryID: $0.category?.id, accountID: $0.account?.id, order: $0.order, useCount: $0.useCount)
            },
            planner: try context.fetch(FetchDescriptor<PlannerItem>()).map {
                PlannerDTO(id: $0.id, title: $0.title, type: $0.typeRaw, date: $0.date, time: $0.time, note: $0.note, isDone: $0.isDone, doneAt: $0.doneAt, reminder: $0.reminder, priority: $0.priorityRaw, createdAt: $0.createdAt)
            },
            cards: try context.fetch(FetchDescriptor<BankCard>()).map {
                CardDTO(id: $0.id, last4: $0.last4, name: $0.name, bankName: $0.bankName, isActive: $0.isActive, accountID: $0.account?.id)
            },
            smsRules: try context.fetch(FetchDescriptor<BankSMSRule>()).map {
                SMSRuleDTO(id: $0.id, order: $0.order, isEnabled: $0.isEnabled, isBuiltIn: $0.isBuiltIn, definition: $0.definition)
            },
            merchantRules: try context.fetch(FetchDescriptor<MerchantRule>()).map {
                MerchantRuleDTO(id: $0.id, pattern: $0.pattern, categoryID: $0.category?.id, useCount: $0.useCount, isUserDefined: $0.isUserDefined)
            },
            importLogs: try context.fetch(FetchDescriptor<SMSImportLog>()).map {
                ImportLogDTO(id: $0.id, receivedAt: $0.receivedAt, sender: $0.sender, text: $0.text, status: $0.statusRaw, summary: $0.summary, ruleName: $0.ruleName, cardLast4: $0.cardLast4, amount: $0.amount, balance: $0.balance, balanceDifference: $0.balanceDifference, operationDate: $0.operationDate, source: $0.sourceRaw, transactionID: $0.transaction?.id)
            },
            attachments: try context.fetch(FetchDescriptor<Attachment>()).map {
                AttachmentDTO(id: $0.id, data: $0.data, kind: $0.kind, createdAt: $0.createdAt, transactionID: $0.transaction?.id)
            },
            goals: try context.fetch(FetchDescriptor<SavingsGoal>()).map { goal in
                GoalDTO(id: goal.id, name: goal.name, targetAmount: goal.targetAmount, deadline: goal.deadline, symbol: goal.symbol, colorHex: goal.colorHex, createdAt: goal.createdAt, isArchived: goal.isArchived,
                        contributions: (goal.contributions ?? []).map { .init(id: $0.id, amount: $0.amount, date: $0.date, note: $0.note) })
            },
            debts: try context.fetch(FetchDescriptor<Debt>()).map { debt in
                DebtDTO(id: debt.id, personName: debt.personName, contactIdentifier: debt.contactIdentifier, direction: debt.directionRaw, amount: debt.amount, currencyCode: debt.currencyCode, date: debt.date, dueDate: debt.dueDate, note: debt.note, isClosed: debt.isClosed, createdAt: debt.createdAt,
                        payments: (debt.payments ?? []).map { .init(id: $0.id, amount: $0.amount, date: $0.date, note: $0.note, transactionID: $0.transaction?.id) })
            },
            envelopes: try context.fetch(FetchDescriptor<Envelope>()).map {
                EnvelopeDTO(id: $0.id, name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex, monthlyAmount: $0.monthlyAmount, order: $0.order, categoryIDs: ($0.categories ?? []).map(\.id))
            },
            closures: try context.fetch(FetchDescriptor<MonthClosure>()).map {
                ClosureDTO(id: $0.id, month: $0.month, createdAt: $0.createdAt, income: $0.income, expense: $0.expense, saved: $0.saved, summaryData: $0.summaryData)
            },
            settings: settingsSnapshot()
        )
    }

    static func encode(_ backup: Backup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Backup.self, from: data)
    }

    /// Полностью заменяет данные содержимым копии.
    static func restore(_ backup: Backup, into context: ModelContext) throws {
        try context.delete(model: SMSImportLog.self)
        try context.delete(model: Attachment.self)
        try context.delete(model: DebtPayment.self)
        try context.delete(model: Debt.self)
        try context.delete(model: GoalContribution.self)
        try context.delete(model: SavingsGoal.self)
        try context.delete(model: MerchantRule.self)
        try context.delete(model: BankSMSRule.self)
        try context.delete(model: BankCard.self)
        try context.delete(model: Envelope.self)
        try context.delete(model: MonthClosure.self)
        try context.delete(model: Transaction.self)
        try context.delete(model: Budget.self)
        try context.delete(model: RecurringRule.self)
        try context.delete(model: Template.self)
        try context.delete(model: PlannerItem.self)
        try context.delete(model: Category.self)
        try context.delete(model: Account.self)

        var categories: [UUID: Category] = [:]
        for dto in backup.categories {
            let category = Category(name: dto.name, symbol: dto.symbol, colorHex: dto.colorHex, kind: CategoryKind(rawValue: dto.kind) ?? .expense, order: dto.order, keywords: dto.keywords)
            category.id = dto.id
            category.archived = dto.archived
            context.insert(category)
            categories[dto.id] = category
        }
        var accounts: [UUID: Account] = [:]
        for dto in backup.accounts {
            let account = Account(name: dto.name, symbol: dto.symbol, colorHex: dto.colorHex, initialBalance: dto.initialBalance, order: dto.order)
            account.id = dto.id
            account.archived = dto.archived
            account.currencyCode = dto.currencyCode ?? account.currencyCode
            account.isSavings = dto.isSavings ?? false
            account.balanceInclusionRaw = dto.balanceInclusion ?? 0
            context.insert(account)
            accounts[dto.id] = account
        }
        var transactions: [UUID: Transaction] = [:]
        for dto in backup.transactions {
            let transaction = Transaction(
                type: TransactionType(rawValue: dto.type) ?? .expense,
                amount: dto.amount,
                category: dto.categoryID.flatMap { categories[$0] },
                account: dto.accountID.flatMap { accounts[$0] },
                toAccount: dto.toAccountID.flatMap { accounts[$0] },
                date: dto.date,
                note: dto.note,
                isRecurring: dto.isRecurring
            )
            transaction.id = dto.id
            transaction.createdAt = dto.createdAt
            transaction.merchant = dto.merchant ?? ""
            transaction.needsReview = dto.needsReview ?? false
            transaction.sourceRaw = dto.source ?? TransactionSource.manual.rawValue
            transaction.cardLast4 = dto.cardLast4 ?? ""
            transaction.tagsRaw = dto.tags ?? ""
            transaction.toAmount = dto.toAmount
            context.insert(transaction)
            transactions[dto.id] = transaction
        }
        for dto in backup.budgets {
            let budget = Budget(limit: dto.limit, category: dto.categoryID.flatMap { categories[$0] })
            budget.id = dto.id
            context.insert(budget)
        }
        for dto in backup.rules {
            let rule = RecurringRule(
                title: dto.title,
                type: TransactionType(rawValue: dto.type) ?? .expense,
                amount: dto.amount,
                category: dto.categoryID.flatMap { categories[$0] },
                account: dto.accountID.flatMap { accounts[$0] },
                frequency: RecurrenceFrequency(rawValue: dto.frequency) ?? .monthly,
                dayOfMonth: dto.dayOfMonth,
                startDate: dto.startDate,
                isMandatory: dto.isMandatory
            )
            rule.id = dto.id
            rule.nextDate = dto.nextDate
            rule.isActive = dto.isActive
            rule.isSubscription = dto.isSubscription ?? false
            rule.remindDaysBefore = dto.remindDaysBefore ?? 0
            context.insert(rule)
        }
        for dto in backup.templates {
            let template = Template(title: dto.title, type: TransactionType(rawValue: dto.type) ?? .expense, amount: dto.amount, category: dto.categoryID.flatMap { categories[$0] }, account: dto.accountID.flatMap { accounts[$0] }, order: dto.order)
            template.id = dto.id
            template.useCount = dto.useCount
            context.insert(template)
        }
        for dto in backup.planner {
            let item = PlannerItem(title: dto.title, type: PlannerItemType(rawValue: dto.type) ?? .task, date: dto.date, time: dto.time, note: dto.note, priority: PlannerPriority(rawValue: dto.priority) ?? .none, reminder: dto.reminder)
            item.id = dto.id
            item.isDone = dto.isDone
            item.doneAt = dto.doneAt
            item.createdAt = dto.createdAt
            context.insert(item)
        }
        restoreVersion2(backup, categories: categories, accounts: accounts, transactions: transactions, into: context)
        try context.save()
        SharedDefaults.store.set(backup.currency, forKey: SharedDefaults.Key.currency)
        for (key, value) in backup.settings ?? [:] where settingsKeys.contains(key) {
            if boolSettings.contains(key) {
                SharedDefaults.store.set(value == "1" || value == "true", forKey: key)
            } else if intSettings.contains(key), let number = Int(value) {
                SharedDefaults.store.set(number, forKey: key)
            } else {
                SharedDefaults.store.set(value, forKey: key)
            }
        }
        WidgetRefresher.reload()
    }

    private static func restoreVersion2(_ backup: Backup, categories: [UUID: Category], accounts: [UUID: Account], transactions: [UUID: Transaction], into context: ModelContext) {
        for dto in backup.cards ?? [] {
            let card = BankCard(last4: dto.last4, name: dto.name, bankName: dto.bankName, account: dto.accountID.flatMap { accounts[$0] })
            card.id = dto.id
            card.isActive = dto.isActive
            context.insert(card)
        }
        for dto in backup.smsRules ?? [] {
            let rule = BankSMSRule(name: dto.definition.name, senderKeywords: dto.definition.senderKeywords, order: dto.order, isBuiltIn: dto.isBuiltIn)
            rule.id = dto.id
            rule.apply(dto.definition)
            rule.isEnabled = dto.isEnabled
            context.insert(rule)
        }
        for dto in backup.merchantRules ?? [] {
            let rule = MerchantRule(pattern: dto.pattern, category: dto.categoryID.flatMap { categories[$0] }, isUserDefined: dto.isUserDefined)
            rule.id = dto.id
            rule.useCount = dto.useCount
            context.insert(rule)
        }
        for dto in backup.importLogs ?? [] {
            let log = SMSImportLog(text: dto.text, sender: dto.sender, source: TransactionSource(rawValue: dto.source) ?? .sms)
            log.id = dto.id
            log.receivedAt = dto.receivedAt
            log.statusRaw = dto.status
            log.summary = dto.summary
            log.ruleName = dto.ruleName
            log.cardLast4 = dto.cardLast4
            log.amount = dto.amount
            log.balance = dto.balance
            log.balanceDifference = dto.balanceDifference
            log.operationDate = dto.operationDate
            log.transaction = dto.transactionID.flatMap { transactions[$0] }
            context.insert(log)
        }
        for dto in backup.attachments ?? [] {
            let attachment = Attachment(data: dto.data, kind: dto.kind, transaction: dto.transactionID.flatMap { transactions[$0] })
            attachment.id = dto.id
            attachment.createdAt = dto.createdAt
            context.insert(attachment)
        }
        for dto in backup.goals ?? [] {
            let goal = SavingsGoal(name: dto.name, targetAmount: dto.targetAmount, deadline: dto.deadline, symbol: dto.symbol, colorHex: dto.colorHex)
            goal.id = dto.id
            goal.createdAt = dto.createdAt
            goal.isArchived = dto.isArchived
            context.insert(goal)
            for item in dto.contributions {
                let contribution = GoalContribution(amount: item.amount, date: item.date, note: item.note, goal: goal)
                contribution.id = item.id
                context.insert(contribution)
            }
        }
        for dto in backup.debts ?? [] {
            let debt = Debt(personName: dto.personName, direction: DebtDirection(rawValue: dto.direction) ?? .theyOwe, amount: dto.amount, currencyCode: dto.currencyCode, date: dto.date, dueDate: dto.dueDate, note: dto.note)
            debt.id = dto.id
            debt.contactIdentifier = dto.contactIdentifier
            debt.isClosed = dto.isClosed
            debt.createdAt = dto.createdAt
            context.insert(debt)
            for item in dto.payments {
                let payment = DebtPayment(amount: item.amount, date: item.date, note: item.note, debt: debt)
                payment.id = item.id
                payment.transaction = item.transactionID.flatMap { transactions[$0] }
                context.insert(payment)
            }
        }
        for dto in backup.envelopes ?? [] {
            let envelope = Envelope(name: dto.name, symbol: dto.symbol, colorHex: dto.colorHex, monthlyAmount: dto.monthlyAmount, order: dto.order)
            envelope.id = dto.id
            context.insert(envelope)
            for id in dto.categoryIDs { categories[id]?.envelope = envelope }
        }
        for dto in backup.closures ?? [] {
            let closure = MonthClosure(summary: MonthSummary(month: dto.month, income: dto.income, expense: dto.expense, saved: dto.saved, previousExpense: 0, topCategories: [], best: [], worst: [], insights: []))
            closure.id = dto.id
            closure.createdAt = dto.createdAt
            closure.summaryData = dto.summaryData
            context.insert(closure)
        }
    }

    /// Настройки автоматизации, которые попадают в копию.
    static let settingsKeys = [
        "savings.percent", "savings.roundUp", "savings.roundUpStep", "sms.onlyKnownCards", "sms.keepDays",
        "envelopes.enabled", "alerts.enabled", "weekly.enabled", "fx.rate.USD", "fx.rate.EUR", "fx.rate.RUB", "fx.rate.TJS",
    ]

    private static let boolSettings: Set<String> = ["savings.roundUp", "sms.onlyKnownCards", "envelopes.enabled", "alerts.enabled", "weekly.enabled"]
    private static let intSettings: Set<String> = ["savings.percent", "savings.roundUpStep", "sms.keepDays"]

    private static func settingsSnapshot() -> [String: String] {
        var result: [String: String] = [:]
        for key in settingsKeys {
            if let value = SharedDefaults.store.object(forKey: key) { result[key] = "\(value)" }
        }
        return result
    }
}

/// Файл резервной копии для `fileExporter`.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
