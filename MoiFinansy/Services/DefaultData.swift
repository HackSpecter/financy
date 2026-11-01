import Foundation
import SwiftData

/// Набор категорий, счетов и шаблонов по умолчанию.
enum DefaultData {
    struct CategorySeed {
        var name: String
        var symbol: String
        var color: String
        var keywords: String = ""
    }

    static let expenseCategories: [CategorySeed] = [
        .init(name: "Продукты", symbol: "cart.fill", color: "#34C759", keywords: "магазин,продукты,хлеб,молоко,мясо,рынок,бозор,супермаркет,овощи,фрукты"),
        .init(name: "Кафе и рестораны", symbol: "fork.knife", color: "#FF9500", keywords: "кафе,обед,ужин,завтрак,кофе,ресторан,чайхана,плов,шашлык,пицца,доставка"),
        .init(name: "Такси", symbol: "car.fill", color: "#FFCC00", keywords: "такси,яндекс,uber,maxim,сомон"),
        .init(name: "Транспорт", symbol: "bus.fill", color: "#007AFF", keywords: "автобус,маршрутка,троллейбус,бензин,заправка,парковка,проезд"),
        .init(name: "Связь и интернет", symbol: "wifi", color: "#32ADE6", keywords: "интернет,связь,телефон,мобильный,tcell,megafon,babilon,zet,пополнение"),
        .init(name: "Аренда/Коммуналка", symbol: "house.fill", color: "#5856D6", keywords: "аренда,квартира,коммуналка,свет,электричество,вода,газ,отопление"),
        .init(name: "Одежда", symbol: "tshirt.fill", color: "#30B0C7", keywords: "одежда,обувь,куртка,рубашка,джинсы,кроссовки"),
        .init(name: "Здоровье", symbol: "cross.case.fill", color: "#FF3B30", keywords: "аптека,лекарства,врач,больница,анализы,стоматолог"),
        .init(name: "Развлечения", symbol: "gamecontroller.fill", color: "#AF52DE", keywords: "кино,игра,подписка,концерт,боулинг,netflix,spotify"),
        .init(name: "Подарки", symbol: "gift.fill", color: "#FF2D55", keywords: "подарок,цветы,праздник,день рождения,свадьба"),
        .init(name: "Семья", symbol: "figure.2.and.child.holdinghands", color: "#00C7BE", keywords: "мама,папа,дети,семья,родители,брат,сестра"),
        .init(name: "Долги", symbol: "creditcard.trianglebadge.exclamationmark", color: "#A2845E", keywords: "долг,кредит,рассрочка,займ"),
        .init(name: "Прочее", symbol: "ellipsis.circle.fill", color: "#8E8E93"),
    ]

    static let incomeCategories: [CategorySeed] = [
        .init(name: "Зарплата", symbol: "banknote.fill", color: "#34C759", keywords: "зарплата,аванс,премия"),
        .init(name: "Подработка", symbol: "briefcase.fill", color: "#30B0C7", keywords: "подработка,фриланс,заказ"),
        .init(name: "Возврат долга", symbol: "arrow.uturn.backward.circle.fill", color: "#007AFF", keywords: "вернул,возврат"),
        .init(name: "Прочее", symbol: "plus.circle.fill", color: "#8E8E93"),
    ]

    /// Создаёт стартовые данные, если база пустая.
    static func seedIfNeeded(in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard count == 0 else { return }
        seed(in: context)
    }

    static func seed(in context: ModelContext) {
        var categories: [String: Category] = [:]
        for (index, seed) in expenseCategories.enumerated() {
            let category = Category(name: seed.name, symbol: seed.symbol, colorHex: seed.color, kind: .expense, order: index, keywords: seed.keywords)
            context.insert(category)
            categories[seed.name] = category
        }
        for (index, seed) in incomeCategories.enumerated() {
            let category = Category(name: seed.name, symbol: seed.symbol, colorHex: seed.color, kind: .income, order: index, keywords: seed.keywords)
            context.insert(category)
            categories["income." + seed.name] = category
        }

        context.insert(Account(name: "Наличные", symbol: "banknote.fill", colorHex: "#34C759", order: 0))
        context.insert(Account(name: "Карта", symbol: "creditcard.fill", colorHex: "#007AFF", order: 1))

        context.insert(Template(title: "Такси", amount: 20, category: categories["Такси"], order: 0))
        context.insert(Template(title: "Обед", amount: 45, category: categories["Кафе и рестораны"], order: 1))
        context.insert(Template(title: "Хлеб", amount: 5, category: categories["Продукты"], order: 2))
        try? context.save()
    }
}

// MARK: - SMS банков

extension DefaultData {
    /// Стартовые правила банков Таджикистана. Форматы приблизительные — правятся в «Настройки → SMS банков».
    static let bankRules: [(name: String, keywords: String)] = [
        ("Alif", "alif,алиф"),
        ("Eskhata", "eskhata,эсхата,ескхата"),
        ("Душанбе Сити", "dc bank,dcbank,душанбе сити,dushanbe city"),
        ("Амонатбонк", "amonatbonk,амонатбонк,amonat"),
        ("Спитамен", "spitamen,спитамен"),
        ("Арванд", "arvand,арванд"),
        ("Humo", "humo,хумо"),
    ]

    /// «Магазин → категория» из коробки.
    static let merchantRules: [(pattern: String, category: String)] = [
        ("yandex", "Такси"), ("яндекс", "Такси"), ("uber", "Такси"), ("maxim", "Такси"), ("taxi", "Такси"), ("такси", "Такси"),
        ("tcell", "Связь и интернет"), ("megafon", "Связь и интернет"), ("babilon", "Связь и интернет"), ("zet", "Связь и интернет"),
        ("аптека", "Здоровье"), ("pharm", "Здоровье"), ("dorukhona", "Здоровье"),
        ("kafe", "Кафе и рестораны"), ("cafe", "Кафе и рестораны"), ("coffee", "Кафе и рестораны"), ("кафе", "Кафе и рестораны"),
        ("pizza", "Кафе и рестораны"), ("kfc", "Кафе и рестораны"), ("burger", "Кафе и рестораны"), ("чайхона", "Кафе и рестораны"),
        ("market", "Продукты"), ("магазин", "Продукты"), ("globus", "Продукты"), ("ашан", "Продукты"), ("пайкар", "Продукты"),
        ("netflix", "Развлечения"), ("spotify", "Развлечения"), ("apple com", "Развлечения"), ("google", "Развлечения"),
        ("бензин", "Транспорт"), ("azs", "Транспорт"), ("азс", "Транспорт"),
    ]

    /// Один раз для каждой установки (в т. ч. после обновления): правила банков и магазинов.
    static func seedSMSIfNeeded(in context: ModelContext) {
        let key = "seed.sms.v1"
        guard !SharedDefaults.store.bool(forKey: key) else { return }
        SharedDefaults.store.set(true, forKey: key)

        for (index, rule) in bankRules.enumerated() {
            context.insert(BankSMSRule(name: rule.name, senderKeywords: rule.keywords, order: index, isBuiltIn: true))
        }
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        for rule in merchantRules {
            guard let category = categories.first(where: { $0.name == rule.category && $0.kind == .expense }) else { continue }
            context.insert(MerchantRule(pattern: rule.pattern, category: category, isUserDefined: false))
        }
        try? context.save()
    }
}
