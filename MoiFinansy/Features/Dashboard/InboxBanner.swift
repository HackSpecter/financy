import SwiftUI

/// Плашка «Входящие: N — выберите категории».
struct InboxBanner: View {
    var count: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "tray.full.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.gradient, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Входящие: \(count)").font(.headline)
                    Text("Операции из SMS ждут категорию").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card(padding: 14)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InboxBanner(count: 3) {}.cardPreview()
}
