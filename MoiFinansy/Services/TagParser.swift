import Foundation

/// Теги в заметке: «обед #работа #командировка» → заметка «обед», теги [работа, командировка].
nonisolated enum TagParser {
    static func extract(from note: String) -> (note: String, tags: [String]) {
        var tags: [String] = []
        var words: [String] = []
        for word in note.split(separator: " ", omittingEmptySubsequences: true) {
            if word.hasPrefix("#"), word.count > 1 {
                let tag = word.dropFirst().trimmingCharacters(in: .punctuationCharacters).lowercased()
                if !tag.isEmpty, !tags.contains(tag) { tags.append(tag) }
            } else {
                words.append(String(word))
            }
        }
        return (words.joined(separator: " "), tags)
    }
}
