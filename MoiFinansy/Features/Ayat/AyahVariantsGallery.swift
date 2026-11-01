import SwiftUI

/// Три варианта оформления виджета «Аят»: экран блокировки и главный экран.
struct AyahVariantsGallery: View {
    var samples: [AyahSample] = AyahSample.load()

    private let variants: [(String, AyahStyle)] = [
        ("1 · Классика — New York, по центру", .classic),
        ("2 · Книга — Cormorant Garamond, подпись снизу", .book),
        ("3 · Современный — SF Pro Rounded, полужирный", .modern),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(variants, id: \.0) { name, style in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name).font(.subheadline.weight(.semibold))
                        HStack(spacing: 10) {
                            if let first = samples.first { LockScreenMock(sample: first, style: style) }
                            if let last = samples.last { HomeWidgetMock(sample: last, style: style) }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Варианты «Аят»")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Пример аята для превью.
struct AyahSample: Identifiable {
    var ref: AyahRef
    var text: String
    var title: String
    var arabic: String
    var id: AyahRef { ref }

    static func load(_ refs: [AyahRef] = [AyahRef(sura: 94, ayah: 5), AyahRef(sura: 93, ayah: 5)]) -> [AyahSample] {
        refs.map { ref in
            let index = QuranStore.index(of: ref) ?? 0
            return AyahSample(
                ref: ref,
                text: QuranStore.translation(.kuliev, at: index),
                title: AyahTypography.title(sura: QuranStore.sura(ref.sura), ref: ref),
                arabic: QuranStore.arabic(at: index)
            )
        }
    }
}

/// Макет экрана блокировки: обои, дата, часы и виджет.
private struct LockScreenMock: View {
    var sample: AyahSample
    var style: AyahStyle

    var body: some View {
        VStack(spacing: 2) {
            Text("Среда, 29 октября").font(.system(size: 11, weight: .semibold))
            Text("12:47").font(.system(size: 54, weight: .semibold, design: .rounded))
            AyahLockView(text: sample.text, title: sample.title, style: style)
                .frame(width: 150, height: 76)
                .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.top, 14)
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.18, blue: 0.32), Color(red: 0.35, green: 0.22, blue: 0.40), Color(red: 0.08, green: 0.08, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: .rect(cornerRadius: 22, style: .continuous)
        )
    }
}

/// Макет виджета главного экрана (systemMedium) в светлой и тёмной теме.
private struct HomeWidgetMock: View {
    var sample: AyahSample
    var style: AyahStyle

    var body: some View {
        ZStack {
            AyahHomeBackground()
            AyahHomeCard(text: sample.text, title: sample.title, arabic: nil, style: style).padding(8)
        }
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
    }
}

#Preview("Варианты") {
    NavigationStack { AyahVariantsGallery() }
}
