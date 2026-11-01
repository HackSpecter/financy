import Foundation
import Testing
@testable import MoiFinansy

struct CategorySuggesterTests {
    let taxi = CategorySuggester.Candidate(id: UUID(), name: "Такси", keywords: "такси,яндекс,uber")
    let cafe = CategorySuggester.Candidate(id: UUID(), name: "Кафе и рестораны", keywords: "кафе,обед,кофе")
    let food = CategorySuggester.Candidate(id: UUID(), name: "Продукты", keywords: "магазин,хлеб")

    @Test func matchesKeywords() {
        #expect(CategorySuggester.suggest(note: "Яндекс до работы", history: [], categories: [taxi, cafe, food]) == taxi.id)
        #expect(CategorySuggester.suggest(note: "обед с коллегами", history: [], categories: [taxi, cafe, food]) == cafe.id)
    }

    @Test func matchesWordForms() {
        #expect(CategorySuggester.suggest(note: "хлеба и молока", history: [], categories: [taxi, cafe, food]) == food.id)
    }

    @Test func historyBeatsKeywords() {
        let history = [(note: "кофе Dodo", categoryID: food.id), (note: "кофе Dodo", categoryID: food.id)]
        #expect(CategorySuggester.suggest(note: "кофе", history: history, categories: [taxi, cafe, food]) == food.id)
    }

    @Test func emptyNoteGivesNothing() {
        #expect(CategorySuggester.suggest(note: "  ", history: [], categories: [taxi]) == nil)
    }
}
