import Foundation

/// Автоподсказка категории по тексту заметки: сначала история пользователя, затем ключевые слова.
nonisolated enum CategorySuggester {
    nonisolated struct Candidate: Sendable {
        var id: UUID
        var name: String
        var keywords: String
    }

    static func suggest(note: String, history: [(note: String, categoryID: UUID)], categories: [Candidate]) -> UUID? {
        let words = tokens(note)
        guard !words.isEmpty else { return nil }

        var scores: [UUID: Int] = [:]
        for item in history {
            let overlap = tokens(item.note).intersection(words).count
            if overlap > 0 { scores[item.categoryID, default: 0] += overlap * 3 }
        }
        for category in categories {
            let keywords = Set(category.keywords.split(separator: ",").map { normalize(String($0)) }.filter { !$0.isEmpty })
                .union(tokens(category.name))
            for word in words where keywords.contains(where: { word.hasPrefix($0) || $0.hasPrefix(word) && word.count >= 4 }) {
                scores[category.id, default: 0] += 2
            }
        }
        return scores.max { $0.value < $1.value }?.key
    }

    static func tokens(_ text: String) -> Set<String> {
        Set(
            text.split { !$0.isLetter && !$0.isNumber }
                .map { normalize(String($0)) }
                .filter { $0.count >= 3 }
        )
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "ё", with: "е")
    }
}
