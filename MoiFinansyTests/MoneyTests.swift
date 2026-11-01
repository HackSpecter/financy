import Foundation
import Testing
@testable import MoiFinansy

struct MoneyTests {
    private let nbsp = "\u{00A0}"

    @Test func formatsWithGroupingAndKopecks() {
        #expect(Money.format(dec("1250.5"), currency: "TJS") == "1\(nbsp)250,50 TJS")
    }

    @Test func formatsWholeAmountsWithoutKopecks() {
        #expect(Money.format(25_000, currency: "TJS") == "25\(nbsp)000 TJS")
        #expect(Money.format(45, currency: "TJS") == "45 TJS")
    }

    @Test func showsPlusSignWhenAsked() {
        #expect(Money.format(120, currency: "TJS", showsPlus: true) == "+120 TJS")
        #expect(Money.format(-120, currency: "TJS", showsPlus: true) == "-120 TJS")
    }

    @Test(arguments: [
        ("1250,5", "1250.5"),
        ("1 250.50", "1250.5"),
        ("1\u{00A0}250,50", "1250.5"),
        ("45", "45"),
    ])
    func parsesUserInput(input: String, expected: String) {
        #expect(Money.parse(input) == dec(expected))
    }

    @Test func rejectsGarbage() {
        #expect(Money.parse("") == nil)
        #expect(Money.parse("abc") == nil)
    }

    @Test func roundsDecimalsExactly() {
        #expect(dec("0.1") + dec("0.2") == dec("0.3"))
        #expect(dec("10.555").rounded(2) == dec("10.56"))
        #expect(dec("3249").rounded(-2) == 3200)
    }

    @Test func compactFormat() {
        #expect(Money.compact(950) == "950")
        #expect(Money.compact(3200) == "3,2 тыс.")
        #expect(Money.compact(25_000) == "25 тыс.")
    }

    @Test func percent() {
        #expect(Money.percent(dec("0.184")) == "18%")
        #expect(Money.percent(dec("-0.4")) == "-40%")
    }

    @Test func amountInputLimitsKopecks() {
        var input = AmountInput()
        for key: AmountKeypad.Key in [.digit(1), .digit(2), .digit(5), .digit(0), .comma, .digit(5), .digit(0), .digit(9)] {
            input.press(key)
        }
        #expect(input.decimal == dec("1250.5"))
        #expect(input.display == "1\(nbsp)250,50")
        input.press(.delete)
        input.press(.delete)
        input.press(.delete)
        #expect(input.decimal == 1250)
    }
}
