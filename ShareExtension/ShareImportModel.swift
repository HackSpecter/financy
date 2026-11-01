import CoreTransferable
import Foundation
import Observation
import UIKit
import UniformTypeIdentifiers

/// Загрузка общего содержимого: текст как есть, скриншот — через распознавание текста.
@Observable
final class ShareImportModel {
    enum State {
        case loading
        case ready(text: String)
        case failed(String)
    }

    var state: State = .loading
    var image: UIImage?
    private let providers: [NSItemProvider]

    init(providers: [NSItemProvider]) {
        self.providers = providers
    }

    func load() async {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
               let data = try? await Self.load(Data.self, from: provider),
               let picked = UIImage(data: data) {
                image = picked
                guard let cgImage = ImageTools.cgImage(from: picked) else { continue }
                let text = (try? await TextRecognizer.recognize(cgImage)) ?? ""
                state = text.isEmpty ? .failed("На изображении не нашлось текста") : .ready(text: text)
                return
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let text = try? await Self.load(String.self, from: provider) {
                state = .ready(text: text)
                return
            }
        }
        state = .failed("Поделитесь текстом SMS или скриншотом операции")
    }

    private static func load<T: Transferable & Sendable>(_ type: T.Type, from provider: NSItemProvider) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadTransferable(type: type) { continuation.resume(with: $0) }
        }
    }
}
