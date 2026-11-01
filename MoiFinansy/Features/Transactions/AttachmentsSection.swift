import PhotosUI
import SwiftData
import SwiftUI

/// Фото и вложения операции: просмотр, добавление, удаление.
struct AttachmentsSection: View {
    var transaction: Transaction
    @Environment(\.modelContext) private var context
    @State private var picked: PhotosPickerItem?
    @State private var viewing: Attachment?

    var body: some View {
        Section("Фото и чеки") {
            if let attachments = transaction.attachments, !attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(attachments) { attachment in
                            if let image = UIImage(data: attachment.data) {
                                Button { viewing = attachment } label: {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 84, height: 84)
                                        .clipShape(.rect(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Удалить", systemImage: "trash", role: .destructive) {
                                        context.delete(attachment)
                                        try? context.save()
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            PhotosPicker(selection: $picked, matching: .images) {
                Label("Добавить фото", systemImage: "photo.badge.plus")
            }
        }
        .onChange(of: picked) {
            Task {
                guard let data = try? await picked?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpeg = ImageTools.jpegData(from: image) else { return }
                context.insert(Attachment(data: jpeg, transaction: transaction))
                try? context.save()
                picked = nil
            }
        }
        .fullScreenCover(item: $viewing) { attachment in
            AttachmentViewer(attachment: attachment)
        }
    }
}

private struct AttachmentViewer: View {
    var attachment: Attachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let image = UIImage(data: attachment.data) {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть", systemImage: "xmark") { dismiss() } }
                if let image = UIImage(data: attachment.data) {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("Чек", image: Image(uiImage: image)))
                    }
                }
            }
        }
    }
}
