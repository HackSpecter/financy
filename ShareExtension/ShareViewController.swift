import SwiftData
import SwiftUI
import UIKit

/// Точка входа «Поделиться → Добавить в приложение».
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?.flatMap { $0.attachments ?? [] } ?? []
        let model = ShareImportModel(providers: providers)
        let root = ShareImportView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        .modelContainer(DataStore.shared)
        .environment(AppSettings.shared)

        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}
