import Foundation

/// Курсы валют к базовой (TJS): ручной ввод + обновление из открытого API, кеш в App Group.
nonisolated enum CurrencyService {
    static let supported = ["TJS", "USD", "RUB", "EUR"]

    /// Сколько базовой валюты за 1 единицу валюты.
    static func rate(for currency: String) -> Decimal {
        if currency == SharedDefaults.currencyCode { return 1 }
        if let stored = SharedDefaults.store.string(forKey: key(currency)), let value = Decimal(string: stored), value > 0 {
            return value
        }
        return defaultRates[currency] ?? 1
    }

    static func setRate(_ rate: Decimal, for currency: String) {
        SharedDefaults.store.set("\(rate)", forKey: key(currency))
    }

    static func toBase(_ amount: Decimal, from currency: String) -> Decimal {
        CurrencyConverter.convert(amount, from: currency, to: SharedDefaults.currencyCode, rateToBase: rate(for:))
    }

    /// Приблизительные курсы на случай, если пользователь ничего не ввёл и нет сети.
    static let defaultRates: [String: Decimal] = ["USD": Decimal(string: "10.9")!, "EUR": Decimal(string: "11.8")!, "RUB": Decimal(string: "0.13")!, "TJS": 1]

    static var lastUpdate: Date? {
        get { SharedDefaults.store.object(forKey: "fx.updatedAt") as? Date }
        set { SharedDefaults.store.set(newValue, forKey: "fx.updatedAt") }
    }

    private static func key(_ currency: String) -> String { "fx.rate.\(currency)" }
}

/// Чистая конвертация через базовую валюту.
nonisolated enum CurrencyConverter {
    static func convert(_ amount: Decimal, from: String, to: String, rateToBase: (String) -> Decimal) -> Decimal {
        guard from != to else { return amount }
        let inBase = amount * rateToBase(from)
        let target = rateToBase(to)
        guard target > 0 else { return inBase }
        return (inBase / target).rounded(2)
    }
}
