import PhotosUI
import SwiftUI

/// Живой макет экрана блокировки поверх ваших обоев: часы и виджет «Аят» в реальном размере.
struct LockScreenPreviewView: View {
    @Environment(AyahModel.self) private var model
    @State private var photo: PhotosPickerItem?
    @State private var wallpaper: UIImage? = LockScreenPreviewView.loadWallpaper()

    /// Размер экрана iPhone в точках — макет рисуется в нём и масштабируется под ширину.
    private let screen = CGSize(width: 440, height: 956)

    var body: some View {
        let mock = self.mock
        let screen = self.screen
        let pickerTitle = wallpaper == nil ? "Выбрать мои обои" : "Сменить обои"
        VStack(spacing: 16) {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / screen.width, proxy.size.height / screen.height)
                mock
                    .frame(width: screen.width, height: screen.height)
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            PhotosPicker(selection: $photo, matching: .images) {
                Label(pickerTitle, systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(16)
        .navigationTitle("Превью")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photo) {
            Task {
                guard let data = try? await photo?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                wallpaper = image
                Self.saveWallpaper(image)
            }
        }
    }

    private var mock: some View {
        ZStack {
            Group {
                if let wallpaper {
                    Image(uiImage: wallpaper).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Color(red: 0.12, green: 0.18, blue: 0.32), Color(red: 0.35, green: 0.22, blue: 0.40), Color(red: 0.08, green: 0.08, blue: 0.12)], startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(width: screen.width, height: screen.height)
            .clipped()

            TimelineView(.everyMinute) { context in
                VStack(spacing: 2) {
                    Text(context.date.appFormatted("EEEEdMMMM").capitalizedFirst)
                        .font(.system(size: 20, weight: .semibold))
                    Text(context.date.appFormatted("HHmm"))
                        .font(.system(size: 104, weight: .semibold, design: .rounded))
                    if let pick = AyahPicker.current(settings: model.settings, favorites: model.favorites, date: context.date) {
                        AyahLockView(text: pick.text, title: pick.title, style: model.settings.style)
                            .frame(width: AyahLayout.lockBox.width, height: AyahLayout.lockBox.height)
                            .padding(.top, 6)
                    }
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.25), radius: 6)
                .padding(.top, 70)
            }
        }
        .clipShape(.rect(cornerRadius: 56, style: .continuous))
    }

    private static var wallpaperURL: URL? {
        QuranStore.groupFolder?.deletingLastPathComponent().appending(path: "ayah-wallpaper.jpg")
    }

    static func loadWallpaper() -> UIImage? {
        wallpaperURL.flatMap { UIImage(contentsOfFile: $0.path) }
    }

    static func saveWallpaper(_ image: UIImage) {
        guard let url = wallpaperURL, let data = ImageTools.jpegData(from: image, maxDimension: 1600, quality: 0.8) else { return }
        try? data.write(to: url)
    }
}

/// Пошаговая инструкция и рекомендуемая раскладка экрана блокировки.
struct HowToAddAyahView: View {
    private let steps: [(String, String)] = [
        ("lock.iphone", "Заблокируйте iPhone и нажмите на экран блокировки с удержанием."),
        ("slider.horizontal.3", "Нажмите «Настроить» → «Экран блокировки»."),
        ("textformat.size.smaller", "Нажмите на дату над часами → выберите \(AppInfo.name) → «Сура»."),
        ("plus.rectangle.on.rectangle", "Нажмите на поле под часами → \(AppInfo.name) → сначала «Аят», затем «Сегодня можно» — он встанет справа."),
        ("checkmark.circle", "Нажмите «Готово». Сура, аят и сумма обновляются каждую минуту вместе с часами."),
    ]

    var body: some View {
        List {
            Section {
                LockLayoutScheme()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Рекомендуемая раскладка")
            }
            Section("Как добавить") {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: step.0)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(Color(red: 0.55, green: 0.14, blue: 0.24).gradient, in: .rect(cornerRadius: 12, style: .continuous))
                            Text("\(index + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(.black.opacity(0.7), in: .circle)
                                .offset(x: 6, y: -6)
                        }
                        Text(step.1).font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                Label("Место виджетов выбирает iOS: под часами или внизу. Чтобы переставить — «Настроить» → «Экран блокировки», нажмите «−» на виджете и добавьте его заново в нужное поле. Порядок в ряду — в порядке добавления.", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                Label("Когда над часами стоит «Сура», заголовок в «Аяте» скрывается сам — весь размер под текст. Изменить: Аяты → Оформление → «Заголовок суры на экране блокировки».", systemImage: "textformat")
                Label("«Аят по времени»: 13:39 — сура 13, аят 39; в 00:ММ — сура 24; в ЧЧ:00 — аят 1. Если в суре меньше аятов — счёт по кругу, в заголовке настоящий номер.", systemImage: "clock")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Как добавить")
    }
}

/// Схема: «Сура» над часами, под часами в ряд — «Аят» и «Сегодня можно».
struct LockLayoutScheme: View {
    var body: some View {
        let settings = AyahSettings.current.resolvedForLock(inlineInstalled: true)
        let pick = AyahPicker.current(settings: settings, surface: .lock(AyahLayout.lockBox))
        let scale: CGFloat = 0.82
        VStack(spacing: 4) {
            Text(pick?.inlineTitle ?? "Ар-Раад 13:39")
                .font(.system(size: 15, weight: .semibold))
                .overlay(alignment: .trailing) { tag("Сура").offset(x: 52) }
            Text(Date.now.appFormatted("HHmm"))
                .font(.system(size: 78, weight: .semibold, design: .rounded))
            HStack(spacing: 12) {
                widget(label: "Аят") {
                    AyahLockView(text: pick?.text ?? "", title: pick?.title ?? "", style: settings.style)
                }
                widget(label: "Сегодня можно") {
                    AllowanceLockView(left: 532, dailyLimit: 795, spent: 263, currency: "TJS")
                }
            }
            .scaleEffect(scale)
            .frame(height: (AyahLayout.lockBox.height + 30) * scale)
        }
        .foregroundStyle(.white.opacity(0.94))
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(red: 0.12, green: 0.18, blue: 0.32), Color(red: 0.35, green: 0.22, blue: 0.40), Color(red: 0.08, green: 0.08, blue: 0.12)], startPoint: .top, endPoint: .bottom),
            in: .rect(cornerRadius: 28, style: .continuous)
        )
    }

    private func widget<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6) {
            content()
                .frame(width: AyahLayout.lockBox.width, height: AyahLayout.lockBox.height)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            tag(label)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.white.opacity(0.2), in: .capsule)
    }
}

#Preview {
    NavigationStack { LockScreenPreviewView() }
        .environment(AyahModel.shared)
}
