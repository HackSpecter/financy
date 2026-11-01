import PhotosUI
import SwiftData
import SwiftUI
import VisionKit

/// Сканер чеков: камера документов или фото → сумма, магазин, дата → операция с фото чека.
struct ReceiptScannerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(ToastCenter.self) private var toasts
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Account.order) private var accounts: [Account]

    @State private var showsCamera = false
    @State private var photo: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var isRecognizing = false
    @State private var recognizedText = ""
    @State private var amountText = ""
    @State private var merchant = ""
    @State private var date = Date.now
    @State private var category: Category?
    @State private var account: Account?

    var body: some View {
        NavigationStack {
            Form {
                if let image {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(.rect(cornerRadius: 12))
                            .frame(maxWidth: .infinity)
                        if isRecognizing {
                            ProgressView("Распознаю текст…")
                        }
                    }
                    Section("Операция") {
                        HStack {
                            TextField("Сумма", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.title2.weight(.semibold))
                                .fontDesign(.rounded)
                            Text(settings.currencyCode).foregroundStyle(.secondary)
                        }
                        TextField("Магазин", text: $merchant)
                        DatePicker("Дата", selection: $date)
                        Picker("Категория", selection: $category) {
                            Text("Во «Входящие»").tag(Category?.none)
                            ForEach(categories.filter { $0.kind == .expense && !$0.archived }) { Label($0.name, systemImage: $0.symbol).tag(Optional($0)) }
                        }
                        Picker("Счёт", selection: $account) {
                            ForEach(accounts.filter { !$0.archived }) { Text($0.name).tag(Optional($0)) }
                        }
                    }
                    if !recognizedText.isEmpty {
                        Section("Распознанный текст") {
                            Text(recognizedText).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        EmptyStateView(title: "Сканер чеков", symbol: "doc.text.viewfinder", message: "Сфотографируйте чек — \(AppInfo.name) найдёт сумму, магазин и дату и прикрепит фото к операции.")
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    if VNDocumentCameraViewController.isSupported {
                        Button("Сканировать камерой", systemImage: "camera.viewfinder") { showsCamera = true }
                    }
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("Выбрать фото чека", systemImage: "photo.on.rectangle")
                    }
                }
            }
            .themedBackground()
            .navigationTitle("Чек")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", systemImage: "checkmark", action: save)
                        .disabled(Money.parse(amountText) == nil || account == nil)
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                DocumentCamera { scanned in
                    showsCamera = false
                    if let scanned { load(scanned) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photo) {
                Task {
                    if let data = try? await photo?.loadTransferable(type: Data.self), let picked = UIImage(data: data) {
                        load(picked)
                    }
                }
            }
            .onAppear { account = TransactionService.lastAccount(in: context) }
        }
    }

    private func load(_ picked: UIImage) {
        image = picked
        guard let cgImage = ImageTools.cgImage(from: picked) else { return }
        isRecognizing = true
        Task {
            let text = (try? await TextRecognizer.recognize(cgImage)) ?? ""
            recognizedText = text
            let result = ReceiptParser.parse(text)
            if let total = result.total { amountText = Money.formatNumber(total).replacingOccurrences(of: "\u{00A0}", with: "") }
            merchant = result.merchant ?? ""
            if let parsedDate = result.date { date = parsedDate }
            if !merchant.isEmpty { category = MerchantRuleService.category(for: merchant, type: .expense, in: context) }
            isRecognizing = false
        }
    }

    private func save() {
        guard let amount = Money.parse(amountText), let account else { return }
        let transaction = Transaction(type: .expense, amount: amount, category: category, account: account, date: date, note: merchant)
        transaction.merchant = merchant
        transaction.source = .receipt
        transaction.needsReview = category == nil
        context.insert(transaction)
        if let image, let data = ImageTools.jpegData(from: image) {
            context.insert(Attachment(data: data, transaction: transaction))
        }
        if let category, !merchant.isEmpty {
            MerchantRuleService.learn(merchant: merchant, category: category, in: context)
        }
        try? context.save()
        TransactionService.didChange(in: context, category: category)
        toasts.show("Чек сохранён: \(Money.format(amount, currency: account.currencyCode))")
        dismiss()
    }
}

/// Камера документов VisionKit.
struct DocumentCamera: UIViewControllerRepresentable {
    var onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish(nil)
        }
    }
}

#Preview {
    ReceiptScannerView()
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
        .environment(ToastCenter.shared)
}
