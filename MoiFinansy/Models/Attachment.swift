import Foundation
import SwiftData

/// Фото чека или другое вложение операции.
@Model
final class Attachment {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data = Data()
    var kind: String = "image"
    var createdAt: Date = Date.now
    var transaction: Transaction?

    init(data: Data, kind: String = "image", transaction: Transaction?) {
        self.data = data
        self.kind = kind
        self.transaction = transaction
        self.createdAt = .now
    }
}
