import Foundation
import SwiftData
import Testing
@testable import MoiFinansy

@MainActor
struct SMSImportServiceTests {
    let container: ModelContainer
    let context: ModelContext
    let card: Account
    let cash: Account

    init() {
        container = DataStore.makeContainer(inMemory: true)
        context = container.mainContext
        DefaultData.seed(in: context)
        let accounts = try! context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))
        cash = accounts[0]
        card = accounts[1]
        context.insert(BankCard(last4: "4242", account: card))
        try! context.save()
    }

    private func sms(_ title: String, _ time: String, amount: String, balance: String, card: String = "4242") -> String {
        "22.10.2026 \(time)\n\(title)\nКарта 4*\(card)\nСумма \(amount) TJS\nОстаток \(balance) TJS"
    }

    @Test func realSMSGoToCardAccount() throws {
        card.initialBalance = Decimal(string: "92.5")!
        let credit = SMSImportService.process(text: sms("Пополнение счета", "19:26:26", amount: "300.00", balance: "392.50"), in: context)
        let debit = SMSImportService.process(text: sms("Списание со счета", "20:52:50", amount: "263.00", balance: "129.50"), in: context)

        let expense = try #require(debit.transaction)
        #expect(expense.type == .expense)
        #expect(expense.amount == 263)
        #expect(expense.account?.id == card.id)
        #expect(expense.source == .sms)
        #expect(expense.needsReview)
        #expect(debit.log.status == .needsReview)
        #expect(credit.transaction?.type == .income)
        // Остатки из SMS совпали с балансом — предупреждения нет.
        #expect(card.balance == Decimal(string: "129.5")!)
        #expect(debit.log.hasBalanceMismatch == false)
        #expect(InboxService.count(in: context) == 2)
    }

    @Test func duplicateIsSkipped() {
        let text = sms("Списание со счета", "20:52:50", amount: "263.00", balance: "129.50")
        SMSImportService.process(text: text, in: context)
        let second = SMSImportService.process(text: text, in: context)
        #expect(second.log.status == .duplicate)
        #expect(second.transaction == nil)
    }

    @Test func sameAmountDifferentBalanceIsNotDuplicate() {
        SMSImportService.process(text: sms("Списание со счета", "20:52:50", amount: "20.00", balance: "129.50"), in: context)
        let second = SMSImportService.process(text: sms("Списание со счета", "20:53:30", amount: "20.00", balance: "109.50"), in: context)
        #expect(second.log.status != .duplicate)
    }

    @Test func unknownCardIsIgnored() {
        let result = SMSImportService.process(text: sms("Списание со счета", "20:52:50", amount: "10.00", balance: "1.00", card: "1111"), in: context)
        #expect(result.log.status == .unknownCard)
        #expect(result.transaction == nil)
    }

    @Test func ownCardsTransferIsMerged() throws {
        let second = Account(name: "Alif", symbol: "creditcard.fill", colorHex: "#FF9500", order: 2)
        context.insert(second)
        context.insert(BankCard(last4: "1111", account: second))
        SMSImportService.process(text: sms("Списание со счета", "10:00:00", amount: "100.00", balance: "29.50"), in: context)
        let result = SMSImportService.process(text: sms("Пополнение счета", "10:00:40", amount: "100.00", balance: "100.00", card: "1111"), in: context)
        #expect(result.log.status == .merged)
        let transfer = try #require(result.transaction)
        #expect(transfer.type == .transfer)
        #expect(transfer.account?.id == card.id)
        #expect(transfer.toAccount?.id == second.id)
        // Одна операция-перевод (плюс возможные корректировки баланса по остаткам из SMS).
        let all = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.type != .adjustment }
        #expect(all.count == 1)
        if SMSImportService.autoReconcile {
            #expect(card.balance == Decimal(string: "29.5")!)
            #expect(second.balance == 100)
        }
    }

    @Test func balanceMismatchCanBeAdjusted() throws {
        let previous = SMSImportService.autoReconcile
        SMSImportService.autoReconcile = false
        defer { SMSImportService.autoReconcile = previous }
        let result = SMSImportService.process(text: sms("Списание со счета", "20:52:50", amount: "263.00", balance: "129.50"), in: context)
        // В приложении было 0 → после списания −263, а банк говорит 129,50.
        #expect(result.log.balanceDifference == Decimal(string: "392.5")!)
        let adjustment = try #require(SMSImportService.adjustBalance(for: result.log, in: context))
        #expect(adjustment.type == .adjustment)
        #expect(card.balance == Decimal(string: "129.5")!)
        #expect(result.log.hasBalanceMismatch == false)
    }

    @Test func balanceFollowsBankAutomatically() throws {
        let previous = SMSImportService.autoReconcile
        SMSImportService.autoReconcile = true
        defer { SMSImportService.autoReconcile = previous }
        // В приложении 0, банк говорит: после списания 1 TJS остаток 328,50.
        let result = SMSImportService.process(text: sms("Списание со счета", "21:50:00", amount: "1.00", balance: "328.50"), in: context)
        #expect(result.transaction?.amount == 1)
        #expect(card.balance == Decimal(string: "328.5")!)
        #expect(result.log.hasBalanceMismatch == false)
        let adjustments = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.type == .adjustment }
        #expect(adjustments.count == 1)
    }

    @Test func merchantRuleIsLearned() throws {
        let taxi = try #require(try context.fetch(FetchDescriptor<MoiFinansy.Category>()).first { $0.name == "Такси" })
        let first = SMSImportService.process(text: "Оплата 25.00 TJS в KORVON TAXI SERVICE. Карта 4*4242. Остаток 100.00 TJS", in: context)
        let transaction = try #require(first.transaction)
        InboxService.categorize(transaction, as: taxi, in: context)
        let second = SMSImportService.process(text: "Оплата 30.00 TJS в KORVON TAXI SERVICE. Карта 4*4242. Остаток 70.00 TJS", in: context)
        #expect(second.transaction?.category?.id == taxi.id)
        #expect(second.transaction?.needsReview == false)
    }

    @Test func cashWithdrawalBecomesTransfer() throws {
        let result = SMSImportService.process(text: "Снятие наличных 200 TJS. Карта 4*4242. Остаток 50 TJS", in: context)
        let transfer = try #require(result.transaction)
        #expect(transfer.type == .transfer)
        #expect(transfer.toAccount?.id == cash.id)
    }

    @Test func confirmationCodeIsIgnored() {
        let result = SMSImportService.process(text: "Код подтверждения 4821 для оплаты 45 TJS", in: context)
        #expect(result.log.status == .ignored)
    }
}

@MainActor
@Suite(.serialized)
struct SMSKindDefaultsTests {
    @Test func creditAndDebitGetDefaultCategories() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        DefaultData.seed(in: context)
        let accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))
        context.insert(BankCard(last4: "4242", account: accounts[1]))
        let transfers = MoiFinansy.Category(name: "Переводы", symbol: "arrow.down.left.circle.fill", colorHex: "#5856D6", kind: .income, order: 9)
        let purchases = MoiFinansy.Category(name: "Покупки", symbol: "bag.fill", colorHex: "#FF9500", kind: .expense, order: 99)
        context.insert(transfers)
        context.insert(purchases)
        try context.save()

        let saved = SMSKindDefaults.configurableKinds.map { ($0, SMSKindDefaults.categoryID(for: $0)) }
        defer { for (kind, id) in saved { SMSKindDefaults.setCategoryID(id, for: kind) } }
        SMSKindDefaults.setCategoryID(transfers.id, for: .credit)
        SMSKindDefaults.setCategoryID(purchases.id, for: .debit)

        let credit = SMSImportService.process(text: "24.10.2026 21:42:24\nПополнение счета\nКарта 4*4242\nСумма 10.00 TJS\nОстаток 328.50 TJS", in: context)
        #expect(credit.transaction?.category?.id == transfers.id)
        #expect(credit.transaction?.needsReview == false)

        let debit = SMSImportService.process(text: "24.10.2026 22:10:00\nСписание со счета\nКарта 4*4242\nСумма 25.00 TJS\nОстаток 303.50 TJS", in: context)
        #expect(debit.transaction?.category?.id == purchases.id)

        // «Во «Входящие»» — без категории.
        SMSKindDefaults.setCategoryID(nil, for: .debit)
        let inbox = SMSImportService.process(text: "24.10.2026 22:20:00\nСписание со счета\nКарта 4*4242\nСумма 5.00 TJS\nОстаток 298.50 TJS", in: context)
        #expect(inbox.transaction?.needsReview == true)
    }
}

@MainActor
struct SalarySMSTests {
    let container: ModelContainer
    let context: ModelContext
    let card: Account
    let salary: MoiFinansy.Category

    init() throws {
        container = DataStore.makeContainer(inMemory: true)
        context = container.mainContext
        DefaultData.seed(in: context)
        let accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))
        card = accounts[1]
        context.insert(BankCard(last4: "4242", account: card))
        salary = try #require(try context.fetch(FetchDescriptor<MoiFinansy.Category>()).first { $0.name == "Зарплата" })
        // Зарплата 24 000 каждое 5-е число.
        let rule = RecurringRule(title: "Зарплата", type: .income, amount: 24_000, category: salary, account: card, frequency: .monthly, dayOfMonth: 5, startDate: TestCalendar.date(2026, 11, 1))
        context.insert(rule)
        try context.save()
    }

    private func credit(_ day: Int, _ amount: String) -> String {
        "\(String(format: "%02d", day)).11.2026 10:00:00\nПополнение счета\nКарта 4*4242\nСумма \(amount) TJS\nОстаток \(amount) TJS"
    }

    @Test func plannedSalaryIsUpdatedNotDuplicated() throws {
        // Правило уже создало «Зарплату» 24 000 на 5-е.
        RecurringService.processDue(in: context, now: TestCalendar.date(2026, 11, 5, 12))
        let result = SMSImportService.process(text: credit(6, "26500.00"), in: context)
        let incomes = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.type == .income }
        #expect(incomes.count == 1)
        #expect(incomes.first?.amount == 26_500)
        #expect(incomes.first?.category?.id == salary.id)
        #expect(result.log.status == .imported)
    }

    @Test func earlySMSSalaryPreventsPlannedDuplicate() throws {
        // Зарплата пришла 3-го, раньше дня правила.
        let result = SMSImportService.process(text: credit(3, "24000.00"), in: context)
        #expect(result.transaction?.category?.id == salary.id)
        RecurringService.processDue(in: context, now: TestCalendar.date(2026, 11, 5, 12))
        let incomes = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.type == .income }
        #expect(incomes.count == 1)
    }

    @Test func smallTopUpIsNotSalary() throws {
        let result = SMSImportService.process(text: credit(5, "300.00"), in: context)
        #expect(result.transaction?.category?.id != salary.id)
    }
}

@MainActor
struct TransferMatcherTests {
    let container: ModelContainer
    let context: ModelContext
    let alif: Account
    let piggy: Account

    init() throws {
        container = DataStore.makeContainer(inMemory: true)
        context = container.mainContext
        DefaultData.seed(in: context)
        alif = try #require(try context.fetch(FetchDescriptor<Account>()).first { $0.name == "Карта" })
        context.insert(BankCard(last4: "4242", account: alif))
        piggy = SavingsService.savingsAccount(in: context)
        try context.save()
    }

    private var debitSMS: String {
        let now = Date.now.appFormatted("ddMMyyyy").replacingOccurrences(of: "/", with: ".")
        return "\(now) \(Date.now.appFormatted("HHmm")):00\nСписание со счета\nКарта 4*4242\nСумма 500.00 TJS\nОстаток 1000.00 TJS"
    }

    @Test func smsAfterManualTransferIsLinkedNotDuplicated() throws {
        let transfer = TransactionService.add(type: .transfer, amount: 500, category: nil, account: alif, toAccount: piggy, in: context)
        let result = SMSImportService.process(text: debitSMS, in: context)
        #expect(result.log.status == .merged)
        #expect(result.transaction?.id == transfer.id)
        let operations = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.type == .expense }
        #expect(operations.isEmpty)
        #expect(piggy.balance == 500)
    }

    @Test func manualTransferAbsorbsEarlierSMSExpense() throws {
        let sms = SMSImportService.process(text: debitSMS, in: context)
        #expect(sms.transaction?.type == .expense)
        let transfer = TransactionService.add(type: .transfer, amount: 500, category: nil, account: alif, toAccount: piggy, in: context)
        let expenses = try context.fetch(FetchDescriptor<Transaction>()).filter { $0.type == .expense }
        #expect(expenses.isEmpty)
        #expect(sms.log.transaction?.id == transfer.id)
        #expect(piggy.balance == 500)
    }
}

@MainActor
struct ConvertToSavingsTests {
    @Test func smsExpenseBecomesSavingsTransfer() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        DefaultData.seed(in: context)
        let card = try #require(try context.fetch(FetchDescriptor<Account>()).first { $0.name == "Карта" })
        card.initialBalance = 24_000
        let expense = TransactionService.add(type: .expense, amount: 10_000, category: nil, account: card, in: context)
        TransactionService.convertToSavings(expense, in: context)
        #expect(expense.type == .transfer)
        #expect(card.balance == 14_000)
        #expect(SavingsService.savingsAccount(in: context).balance == 10_000)
        #expect(try context.fetch(FetchDescriptor<Transaction>()).filter { $0.type == .expense }.isEmpty)
    }
}
