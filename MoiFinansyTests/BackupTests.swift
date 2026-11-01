import Foundation
import SwiftData
import Testing
@testable import MoiFinansy

@MainActor
struct BackupTests {
    @Test func roundTripKeepsNewEntities() throws {
        let sourceContainer = DataStore.makeContainer(inMemory: true)
        let source = sourceContainer.mainContext
        DefaultData.seed(in: source)
        let card = try #require(try source.fetch(FetchDescriptor<Account>()).first { $0.name == "Карта" })
        card.currencyCode = "USD"
        source.insert(BankCard(last4: "4242", account: card))
        let rule = BankSMSRule(name: "Мой банк", senderKeywords: "mybank", order: 0)
        rule.amountPattern = #"Sum:\s*([0-9.]+)"#
        source.insert(rule)
        let goal = SavingsGoal(name: "Телефон", targetAmount: 6000, deadline: nil, symbol: "iphone", colorHex: "#007AFF")
        source.insert(goal)
        source.insert(GoalContribution(amount: 500, goal: goal))
        let debt = Debt(personName: "Али", direction: .theyOwe, amount: 1000, currencyCode: "TJS")
        source.insert(debt)
        source.insert(DebtPayment(amount: 300, debt: debt))
        let transaction = Transaction(type: .expense, amount: 45, account: card, note: "обед")
        transaction.tags = ["работа"]
        transaction.merchant = "KAFE"
        transaction.needsReview = true
        source.insert(transaction)
        source.insert(Attachment(data: Data([1, 2, 3]), transaction: transaction))
        try source.save()

        let data = try BackupService.encode(BackupService.makeBackup(from: source))
        let targetContainer = DataStore.makeContainer(inMemory: true)
        let target = targetContainer.mainContext
        try BackupService.restore(BackupService.decode(data), into: target)

        let restoredCard = try #require(try target.fetch(FetchDescriptor<BankCard>()).first)
        #expect(restoredCard.last4 == "4242")
        #expect(restoredCard.account?.currencyCode == "USD")
        #expect(try target.fetch(FetchDescriptor<BankSMSRule>()).first?.amountPattern == #"Sum:\s*([0-9.]+)"#)
        #expect(try target.fetch(FetchDescriptor<SavingsGoal>()).first?.saved == 500)
        #expect(try target.fetch(FetchDescriptor<Debt>()).first?.remaining == 700)
        let restored = try #require(try target.fetch(FetchDescriptor<Transaction>()).first)
        #expect(restored.tags == ["работа"])
        #expect(restored.merchant == "KAFE")
        #expect(restored.needsReview)
        #expect(restored.attachments?.first?.data == Data([1, 2, 3]))
    }

    @Test func readsVersionOneBackup() throws {
        let json = """
        {"version":1,"exportedAt":"2026-10-01T10:00:00Z","currency":"TJS","categories":[],"accounts":[{"id":"6B0C7F0E-1111-4C3B-9C55-2E2C2A1B0001","name":"Наличные","symbol":"banknote.fill","colorHex":"#34C759","initialBalance":100,"order":0,"archived":false}],
        "transactions":[],"budgets":[],"rules":[],"templates":[],"planner":[]}
        """
        let backup = try BackupService.decode(Data(json.utf8))
        let targetContainer = DataStore.makeContainer(inMemory: true)
        let target = targetContainer.mainContext
        try BackupService.restore(backup, into: target)
        let account = try #require(try target.fetch(FetchDescriptor<Account>()).first)
        #expect(account.initialBalance == 100)
        #expect(account.currencyCode == "TJS")
    }
}
