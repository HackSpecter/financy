import Combine
import SwiftUI

/// Аят на Главной — открывает раздел «Аяты».
struct AyahDashboardCard: View {
    @Environment(AyahModel.self) private var model
    @State private var now = Date.now

    var body: some View {
        NavigationLink { AyatHomeView() } label: {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(title: "Аят", symbol: "book.closed.fill", tint: Color(red: 0.55, green: 0.14, blue: 0.24)) {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                if let pick = AyahPicker.current(settings: model.settings, favorites: model.favorites, date: now) {
                    Text(AyahTypography.russian(pick.text))
                        .font(model.settings.style.font.font(size: 17, bold: model.settings.style.bold))
                        .lineSpacing(2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(pick.title)
                        .font(.caption2.weight(.medium))
                        .tracking(1.3)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Тексты загружаются…").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }
}
