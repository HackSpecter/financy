import SwiftUI

/// Список сур.
struct SuraListView: View {
    var body: some View {
        List(QuranStore.suras) { sura in
            NavigationLink {
                SuraReaderView(suraNumber: sura.n, focus: nil)
            } label: {
                HStack(spacing: 12) {
                    Text("\(sura.n)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sura.ru).font(.body.weight(.medium))
                        Text("\(sura.meaning) · \(sura.ayas) аятов").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(sura.ar).font(ArabicFont.amiriQuran.font(size: 20))
                }
            }
        }
        .navigationTitle("Суры")
    }
}

/// Чтение суры: арабский текст и перевод, с прокруткой к нужному аяту.
struct SuraReaderView: View {
    var suraNumber: Int
    var focus: Int?
    @Environment(AyahModel.self) private var model

    var body: some View {
        let settings = model.settings
        let sura = QuranStore.sura(suraNumber)
        ScrollViewReader { proxy in
            List {
                if let sura {
                    Section {
                        VStack(spacing: 4) {
                            Text(sura.ar).font(settings.arabicFont.font(size: 34))
                            Text("\(sura.meaning) · \(sura.type) · \(sura.ayas) аятов").font(.footnote).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    ForEach(1...sura.ayas, id: \.self) { number in
                        let index = sura.start + number - 1
                        NavigationLink { AyahDetailView(index: index) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("\(sura.n):\(number)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    if model.isFavorite(index) { Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink) }
                                }
                                Text(QuranStore.arabic(at: index))
                                    .font(settings.arabicFont.font(size: 24))
                                    .lineSpacing(8)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .multilineTextAlignment(.trailing)
                                Text(AyahTypography.russian(QuranStore.translation(settings.translation, at: index)))
                                    .font(settings.style.font.font(size: 17, bold: false))
                                    .lineSpacing(3)
                            }
                            .padding(.vertical, 6)
                        }
                        .id(number)
                    }
                }
            }
            .navigationTitle(sura?.ru ?? "Сура")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if let focus { proxy.scrollTo(focus, anchor: .top) } }
        }
    }
}

/// Поиск по переводу и по номеру: «94», «94:5», «облегчение».
struct AyatSearchView: View {
    @Environment(AyahModel.self) private var model
    @State private var query = ""
    @State private var results: [Int] = []

    var body: some View {
        List {
            if let sura = suraFromQuery {
                NavigationLink { SuraReaderView(suraNumber: sura.n, focus: refFromQuery?.ayah) } label: {
                    Label("Сура \(sura.n). \(sura.ru)", systemImage: "book")
                }
            }
            ForEach(results, id: \.self) { index in
                NavigationLink { AyahDetailView(index: index) } label: {
                    AyahRow(index: index, translation: model.settings.translation)
                }
            }
        }
        .overlay {
            if query.isEmpty {
                ContentUnavailableView("Поиск аятов", systemImage: "magnifyingglass", description: Text("Слово из перевода или номер: «94», «94:5»."))
            }
        }
        .searchable(text: $query, prompt: "Облегчение, 94:5…")
        .navigationTitle("Поиск")
        .task(id: query) {
            let text = query.trimmingCharacters(in: .whitespaces)
            let translation = model.settings.translation
            guard text.count >= 3, refFromQuery == nil, Int(text) == nil else { results = []; return }
            results = await Task.detached { Self.search(text, translation: translation) }.value
        }
    }

    private var refFromQuery: AyahRef? {
        let parts = query.split(separator: ":").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 else { return nil }
        return AyahRef(sura: parts[0], ayah: parts[1])
    }

    private var suraFromQuery: SuraInfo? {
        if let ref = refFromQuery { return QuranStore.sura(ref.sura) }
        return Int(query.trimmingCharacters(in: .whitespaces)).flatMap(QuranStore.sura)
    }

    nonisolated static func search(_ text: String, translation: QuranTranslation) -> [Int] {
        guard let source = QuranStore.text(translation.rawValue) else { return [] }
        var found: [Int] = []
        for index in 0..<QuranText.ayahCount where source.text(at: index).localizedCaseInsensitiveContains(text) {
            found.append(index)
            if found.count >= 200 { break }
        }
        return found
    }
}

/// Избранные аяты.
struct FavoriteAyatView: View {
    @Environment(AyahModel.self) private var model

    var body: some View {
        List {
            ForEach(model.favorites, id: \.self) { index in
                NavigationLink { AyahDetailView(index: index) } label: {
                    AyahRow(index: index, translation: model.settings.translation)
                }
            }
            .onDelete { model.favorites.remove(atOffsets: $0) }
        }
        .overlay {
            if model.favorites.isEmpty {
                ContentUnavailableView("Избранного нет", systemImage: "heart", description: Text("Откройте аят и нажмите «В избранное»."))
            }
        }
        .navigationTitle("Избранное")
    }
}

struct AyahRow: View {
    var index: Int
    var translation: QuranTranslation

    var body: some View {
        let ref = QuranStore.ref(at: index)
        VStack(alignment: .leading, spacing: 4) {
            Text(AyahTypography.title(sura: QuranStore.sura(ref.sura), ref: ref))
                .font(.caption2.weight(.medium))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(AyahTypography.russian(QuranStore.translation(translation, at: index)))
                .font(.subheadline)
                .lineLimit(3)
        }
    }
}

/// Источники текстов и шрифтов, обязательные атрибуции.
struct AyahSourcesView: View {
    var body: some View {
        List {
            Section {
                Text("Tanzil Quran Text (Uthmani, Version 1.1). Copyright © 2007–2026 Tanzil Project. License: Creative Commons Attribution 3.0. Текст воспроизводится без изменений.")
                Link("tanzil.net", destination: URL(string: "https://tanzil.net")!)
                Link("Обновления текста: tanzil.net/updates", destination: URL(string: "https://tanzil.net/updates/")!)
            } header: {
                Text("Арабский текст")
            }
            Section {
                ForEach(QuranTranslation.allCases) { translation in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(translation.title).font(.body.weight(.medium))
                        Text("Переводчик: \(translation.translator). Источник: Tanzil.net (\(translation.rawValue)).").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Условия Tanzil: переводы предоставлены только для некоммерческого использования; для иного использования нужно разрешение переводчика или издателя. Тексты переводов не изменяются — в приложении меняется только оформление: кавычки, тире и пробелы.")
                    .font(.footnote)
                Link("tanzil.net/trans", destination: URL(string: "https://tanzil.net/trans/")!)
            } header: {
                Text("Переводы на русский")
            }
            Section {
                ForEach(Self.fonts, id: \.file) { font in
                    NavigationLink {
                        ScrollView {
                            Text(Self.license(font.file)).font(.footnote.monospaced()).padding()
                        }
                        .navigationTitle(font.name)
                    } label: {
                        LabeledContent(font.name, value: "SIL OFL 1.1")
                    }
                }
                Text("New York и SF Pro Rounded — системные шрифты Apple.").font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("Шрифты")
            }
        }
        .navigationTitle("Источники")
    }

    static let fonts: [(name: String, file: String)] = [
        ("Cormorant Garamond", "OFL-cormorantgaramond"), ("Lora", "OFL-lora"), ("PT Serif", "OFL-ptserif"),
        ("Playfair Display", "OFL-playfairdisplay"), ("Amiri Quran", "OFL-amiriquran"),
        ("Scheherazade New", "OFL-scheherazadenew"), ("Noto Naskh Arabic", "OFL-notonaskharabic"),
    ]

    static func license(_ file: String) -> String {
        Bundle.main.url(forResource: file, withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }
}

#Preview {
    NavigationStack { AyahSourcesView() }
}
