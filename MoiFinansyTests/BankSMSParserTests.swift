import Foundation
import Testing
@testable import MoiFinansy

/// Тесты парсера SMS.
/// «Типичный формат» — SMS вида «Списание со счета / Карта / Сумма / Остаток» (данные условные).
/// Остальные — правдоподобные форматы: правила нужно будет поправить по настоящим SMS этих банков.
struct BankSMSParserTests {
    let calendar = TestCalendar.calendar

    // MARK: Типичный формат (карта условная)

    let realDebit = """
    22.10.2026 20:52:50
    Списание со счета
    Карта 4*4242
    Сумма 263.00 TJS
    Остаток 129.50 TJS
    """

    let realCredit = """
    22.10.2026 19:26:26
    Пополнение счета
    Карта 4*4242
    Сумма 300.00 TJS
    Остаток 392.50 TJS
    """

    @Test func realDebitSMS() throws {
        let parsed = try #require(BankSMSParser.parse(realDebit, calendar: calendar).parsed)
        #expect(parsed.kind == .debit)
        #expect(parsed.kind.transactionType == .expense)
        #expect(parsed.amount == 263)
        #expect(parsed.currency == "TJS")
        #expect(parsed.cardLast4 == "4242")
        #expect(parsed.balance == dec("129.5"))
        #expect(parsed.date == TestCalendar.date(2026, 10, 22, 20, 52).addingTimeInterval(50))
        #expect(parsed.merchant == nil)
    }

    @Test func realCreditSMS() throws {
        let parsed = try #require(BankSMSParser.parse(realCredit, calendar: calendar).parsed)
        #expect(parsed.kind == .credit)
        #expect(parsed.kind.transactionType == .income)
        #expect(parsed.amount == 300)
        #expect(parsed.cardLast4 == "4242")
        #expect(parsed.balance == dec("392.5"))
        #expect(parsed.date == TestCalendar.date(2026, 10, 22, 19, 26).addingTimeInterval(26))
    }

    @Test func realSMSOnOneLine() throws {
        let oneLine = realDebit.replacingOccurrences(of: "\n", with: " ")
        let parsed = try #require(BankSMSParser.parse(oneLine, calendar: calendar).parsed)
        #expect(parsed.amount == 263)
        #expect(parsed.balance == dec("129.5"))
        #expect(parsed.cardLast4 == "4242")
    }

    @Test func highlightsPointToValues() throws {
        let parsed = try #require(BankSMSParser.parse(realDebit, calendar: calendar).parsed)
        let ns = realDebit as NSString
        #expect(ns.substring(with: try #require(parsed.highlights[.amount])) == "263.00")
        #expect(ns.substring(with: try #require(parsed.highlights[.balance])) == "129.50")
        #expect(ns.substring(with: try #require(parsed.highlights[.card])) == "4242")
    }

    // MARK: Правдоподобные форматы других банков (поправить по реальным SMS)

    @Test func purchaseWithMerchantRussian() throws {
        let text = "Alif: Покупка 45,00 TJS, карта *1234, YANDEX GO. 12.09.26 13:05. Доступно 1 250,50 TJS"
        let parsed = try #require(BankSMSParser.parse(text, calendar: calendar).parsed)
        #expect(parsed.kind == .purchase)
        #expect(parsed.amount == 45)
        #expect(parsed.cardLast4 == "1234")
        #expect(parsed.balance == dec("1250.5"))
        #expect(parsed.date == TestCalendar.date(2026, 9, 12, 13, 5))
    }

    @Test func purchaseInlineMerchant() throws {
        let text = "Оплата 120.50 сом в KAFE RAVSHAN. Карта 4*5678. Остаток 980.00 сом"
        let parsed = try #require(BankSMSParser.parse(text, calendar: calendar).parsed)
        #expect(parsed.amount == dec("120.5"))
        #expect(parsed.merchant == "KAFE RAVSHAN")
        #expect(parsed.balance == 980)
    }

    @Test func englishPurchase() throws {
        let text = "Purchase 1,250.50 TJS card ****4321 at GLOBUS MARKET. Balance: 3,000.00 TJS"
        let parsed = try #require(BankSMSParser.parse(text, calendar: calendar).parsed)
        #expect(parsed.kind == .purchase)
        #expect(parsed.amount == dec("1250.5"))
        #expect(parsed.cardLast4 == "4321")
        #expect(parsed.merchant == "GLOBUS MARKET")
        #expect(parsed.balance == 3000)
    }

    @Test func tajikCredit() throws {
        let text = "Ба корти *7788 маблағи 500 смн ворид шуд. Бақия: 1500 смн"
        let parsed = try #require(BankSMSParser.parse(text, calendar: calendar).parsed)
        #expect(parsed.kind == .credit)
        #expect(parsed.amount == 500)
        #expect(parsed.cardLast4 == "7788")
        #expect(parsed.balance == 1500)
    }

    @Test func cashWithdrawal() throws {
        let text = "Снятие наличных 1000 TJS. Карта 4*4242. Банкомат DC Rudaki. Остаток 200 TJS"
        let parsed = try #require(BankSMSParser.parse(text, calendar: calendar).parsed)
        #expect(parsed.kind == .cashWithdrawal)
        #expect(parsed.amount == 1000)
    }

    @Test func incomingTransfer() throws {
        let text = "Получен перевод 250 TJS на карту *4242 от ALI V. Остаток 379.50 TJS"
        let parsed = try #require(BankSMSParser.parse(text, calendar: calendar).parsed)
        #expect(parsed.kind == .transferIn)
        #expect(parsed.kind.transactionType == .income)
    }

    @Test func outgoingTransfer() throws {
        let text = "Перевод 100 TJS с карты *4242 на карту *1111. Остаток 29.50 TJS"
        let parsed = try #require(BankSMSParser.parse(text, calendar: calendar).parsed)
        #expect(parsed.kind == .transferOut)
        #expect(parsed.cardLast4 == "4242")
    }

    @Test func dollarAmount() throws {
        let text = "Списание $12.99 карта *4242 NETFLIX.COM"
        let parsed = try #require(BankSMSParser.parse(text, calendar: calendar).parsed)
        #expect(parsed.currency == "USD")
        #expect(parsed.amount == dec("12.99"))
    }

    // MARK: Не операции

    @Test(arguments: [
        "Код подтверждения 4821 для оплаты 45 TJS. Никому не сообщайте код.",
        "Ваш код: 123456",
        "Акция! Скидка 20% на всё до 31.10. Кэшбэк до 500 TJS",
        "Уважаемый клиент, спасибо что вы с нами!",
    ])
    func ignoresNonTransactions(text: String) {
        if case .transaction = BankSMSParser.parse(text, calendar: calendar) {
            Issue.record("Должно быть пропущено: \(text)")
        }
    }

    // MARK: Правила из данных

    @Test func customRuleOverridesGeneric() throws {
        var rule = SMSRuleDefinition(name: "Тест-банк", senderKeywords: "testbank")
        rule.amountPattern = #"Spisano:\s*([0-9.]+)"#
        rule.expenseKeywords = "spisano"
        let text = "TESTBANK Spisano: 77.70 Ostatok 10"
        let parsed = try #require(BankSMSParser.parse(text, sender: "TESTBANK", rules: [rule], calendar: calendar).parsed)
        #expect(parsed.ruleName == "Тест-банк")
        #expect(parsed.amount == dec("77.7"))
        #expect(parsed.kind == .debit)
    }

    @Test func numberFormats() {
        #expect(BankSMSParser.parseNumber("1 250,50") == dec("1250.5"))
        #expect(BankSMSParser.parseNumber("1250.50") == dec("1250.5"))
        #expect(BankSMSParser.parseNumber("1,250.50") == dec("1250.5"))
        #expect(BankSMSParser.parseNumber("45,5") == dec("45.5"))
        #expect(BankSMSParser.parseNumber("12,500") == 12500)
    }

    // MARK: Обучение

    @Test func learnerBuildsWorkingRule() throws {
        let sample = RuleLearner.Sample(
            text: "MYBANK\nSpisanie: 263.00\nKarta: 4*4242\nOstatok: 129.50\nMagazin: KORVON",
            name: "Мой банк",
            senderKeywords: "mybank",
            amount: "263.00",
            balance: "129.50",
            card: "4242",
            merchant: "KORVON",
            kind: .debit,
            typePhrase: "Spisanie"
        )
        let rule = RuleLearner.makeRule(from: sample)
        let other = "MYBANK\nSpisanie: 45.50\nKarta: 4*1111\nOstatok: 84.00\nMagazin: YANDEX GO"
        let parsed = try #require(BankSMSParser.parse(other, rules: [rule], calendar: calendar).parsed)
        #expect(parsed.amount == dec("45.5"))
        #expect(parsed.balance == 84)
        #expect(parsed.cardLast4 == "1111")
        #expect(parsed.merchant == "YANDEX GO")
        #expect(parsed.kind == .debit)
    }
}
