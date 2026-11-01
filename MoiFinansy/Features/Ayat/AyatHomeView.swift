import Combine
import SwiftUI

/// Раздел «Аяты»: аят сейчас, оформление виджета, поиск, избранное, суры.
struct AyatHomeView: View {
    @Environment(AyahModel.self) private var model
    @State private var now = Date.now

    var body: some View {
        List {
            if let pick = AyahPicker.current(settings: model.settings, favorites: model.favorites, date: now) {
                Section {
                    NavigationLink { AyahDetailView(index: pick.index) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            AyahTitleView(title: pick.title, style: model.settings.style, size: 11)
                            Text(AyahTypography.russian(pick.text))
                                .font(model.settings.style.font.font(size: 19, bold: model.settings.style.bold))
                                .lineSpacing(3)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("Сейчас на экране блокировки")
                }
            }
            Section {
                NavigationLink { AyahSettingsView() } label: { Label("Оформление виджета", systemImage: "textformat") }
                NavigationLink { LockScreenPreviewView() } label: { Label("Превью на моих обоях", systemImage: "iphone") }
                NavigationLink { HowToAddAyahView() } label: { Label("Как добавить на экран блокировки", systemImage: "questionmark.circle") }
            }
            Section {
                NavigationLink { AyatSearchView() } label: { Label("Поиск", systemImage: "magnifyingglass") }
                NavigationLink { FavoriteAyatView() } label: {
                    LabeledContent { Text("\(model.favorites.count)") } label: { Label("Избранное", systemImage: "heart") }
                }
                NavigationLink { SuraListView() } label: { Label("Читать суры", systemImage: "book") }
            }
            Section {
                NavigationLink { AyahSourcesView() } label: { Label("Источники", systemImage: "info.circle") }
            }
        }
        .navigationTitle("Аяты")
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
    }
}

/// Аят полностью: арабский текст, перевод, избранное, поделиться, читать суру.
struct AyahDetailView: View {
    var index: Int
    @Environment(AyahModel.self) private var model
    @State private var shareImage: Image?

    var body: some View {
        let settings = model.settings
        let ref = QuranStore.ref(at: index)
        let sura = QuranStore.sura(ref.sura)
        let translation = QuranStore.translation(settings.translation, at: index)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AyahTypography.title(sura: sura, ref: ref))
                        .font(.caption.weight(.medium))
                        .tracking(1.6)
                        .foregroundStyle(.secondary)
                    if let sura { Text("\(sura.meaning) · \(sura.type)").font(.footnote).foregroundStyle(.tertiary) }
                }
                Text(QuranStore.arabic(at: index))
                    .font(settings.arabicFont.font(size: 30))
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(AyahTypography.russian(translation))
                    .font(settings.style.font.font(size: 21, bold: settings.style.bold))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                Text("Перевод: \(settings.translation.translator)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        model.toggleFavorite(index)
                    } label: {
                        Label(model.isFavorite(index) ? "В избранном" : "В избранное", systemImage: model.isFavorite(index) ? "heart.fill" : "heart")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview(AyahTypography.title(sura: sura, ref: ref, uppercased: false), image: shareImage)) {
                            Label("Поделиться", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                }
                .controlSize(.large)
                .sensoryFeedback(.success, trigger: model.isFavorite(index))

                NavigationLink {
                    SuraReaderView(suraNumber: ref.sura, focus: ref.ayah)
                } label: {
                    Label("Читать суру \(sura?.ru ?? "")", systemImage: "book").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            .padding(20)
        }
        .navigationTitle(sura?.ru ?? "Аят")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: index) {
            shareImage = AyahShareCard.render(text: translation, title: AyahTypography.title(sura: sura, ref: ref), arabic: QuranStore.arabic(at: index), settings: settings)
        }
    }
}

/// Карточка для «Поделиться» — в выбранном шрифте, на бордово-белом градиенте.
struct AyahShareCard: View {
    var text: String
    var title: String
    var arabic: String
    var settings: AyahSettings

    var body: some View {
        VStack(spacing: 28) {
            Text(arabic)
                .font(settings.arabicFont.font(size: 40))
                .lineSpacing(14)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
            Text(AyahTypography.russian(text))
                .font(settings.style.font.font(size: 34, bold: settings.style.bold))
                .lineSpacing(8)
                .multilineTextAlignment(.center)
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .tracking(4)
                .opacity(0.75)
            Text("\(AppInfo.name)")
                .font(.system(size: 13, weight: .regular))
                .opacity(0.5)
        }
        .foregroundStyle(.white)
        .padding(64)
        .frame(width: 1080 / 2)
        .background(
            LinearGradient(colors: [Color(red: 0.45, green: 0.10, blue: 0.19), Color(red: 0.16, green: 0.04, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    static func render(text: String, title: String, arabic: String, settings: AyahSettings) -> Image? {
        let renderer = ImageRenderer(content: AyahShareCard(text: text, title: title, arabic: arabic, settings: settings))
        renderer.scale = 2
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

#Preview {
    NavigationStack { AyatHomeView() }
        .environment(AyahModel.shared)
}
