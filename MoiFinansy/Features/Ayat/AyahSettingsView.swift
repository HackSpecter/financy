import SwiftUI

/// Оформление виджета «Аят» с живым превью.
struct AyahSettingsView: View {
    @Environment(AyahModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                AyahLivePreview(settings: model.settings)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Готовые варианты") {
                HStack(spacing: 8) {
                    preset("Классика", .classic)
                    preset("Книга", .book)
                    preset("Современный", .modern)
                }
                .buttonStyle(.glass)
            }

            Section("Текст") {
                Picker("Перевод", selection: $model.settings.translation) {
                    ForEach(QuranTranslation.allCases) { Text($0.title).tag($0) }
                }
                Picker("Шрифт", selection: $model.settings.style.font) {
                    ForEach(AyahFont.allCases) { font in
                        Text(font.title).font(font.font(size: 17, bold: false)).tag(font)
                    }
                }
                Picker("Размер", selection: $model.settings.style.size) {
                    ForEach(AyahStyle.Size.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("Полужирный", isOn: $model.settings.style.bold)
                VStack(alignment: .leading) {
                    Text("Межстрочный интервал")
                    Slider(value: $model.settings.style.lineSpacing, in: 0...6, step: 0.5)
                }
            }

            Section {
                Picker("Выравнивание", selection: $model.settings.style.alignment) {
                    Text("Слева").tag(AyahStyle.Alignment.leading)
                    Text("По центру").tag(AyahStyle.Alignment.center)
                }
                .pickerStyle(.segmented)
                Picker("Заголовок суры на экране блокировки", selection: $model.settings.lockTitle) {
                    ForEach(AyahLockTitle.allCases) { Text($0.title).tag($0) }
                }
                Picker("Заголовок", selection: $model.settings.style.titlePosition) {
                    Text("Сверху").tag(AyahStyle.TitlePosition.top)
                    Text("Снизу").tag(AyahStyle.TitlePosition.bottom)
                    Text("Скрыт").tag(AyahStyle.TitlePosition.hidden)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Вёрстка")
            } footer: {
                Text("Размер — максимальный: если аят иначе не помещается, виджет уменьшит шрифт до 11 pt (до 4 строк). «Авто» скрывает заголовок, когда над часами стоит виджет «Сура», — весь размер уходит под текст.")
            }

            Section("Смена аята каждую минуту") {
                Picker("Режим", selection: $model.settings.mode) {
                    ForEach(AyahMode.allCases) { Text($0.title).tag($0) }
                }
                if model.settings.mode == .sura {
                    Picker("Сура", selection: $model.settings.sura) {
                        ForEach(QuranStore.suras) { sura in Text("\(sura.n). \(sura.ru)").tag(sura.n) }
                    }
                }
                if model.settings.mode == .byTime {
                    Picker("Если аят не помещается", selection: $model.settings.overflow) {
                        ForEach(AyahOverflow.allCases) { Text($0.title).tag($0) }
                    }
                }
                if model.settings.mode == .favorites, model.favorites.isEmpty {
                    Text("Избранного пока нет — пока показываются все аяты по порядку.").font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Арабский текст", isOn: $model.settings.showArabicOnHome)
                Picker("Арабский шрифт", selection: $model.settings.arabicFont) {
                    ForEach(ArabicFont.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Виджет главного экрана")
            } footer: {
                Text("На экране блокировки показывается только русский перевод.")
            }

            Section("Ежедневное уведомление") {
                Toggle("Аят дня", isOn: $model.settings.dailyNotification)
                    .onChange(of: model.settings.dailyNotification) { _, on in
                        if on { Task { await NotificationService.requestAuthorization() } }
                    }
                if model.settings.dailyNotification {
                    DatePicker("Время", selection: notificationTime, displayedComponents: .hourAndMinute)
                }
            }
        }
        .navigationTitle("Оформление")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func preset(_ title: String, _ style: AyahStyle) -> some View {
        Button(title) {
            var updated = style
            updated.size = model.settings.style.size
            model.settings.style = updated
        }
        .font(.subheadline)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
    }

    private var notificationTime: Binding<Date> {
        Binding(
            get: { AppCalendar.calendar.startOfDay(for: .now).addingTimeInterval(TimeInterval(model.settings.notificationMinutes * 60)) },
            set: {
                let parts = AppCalendar.calendar.dateComponents([.hour, .minute], from: $0)
                model.settings.notificationMinutes = (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

/// Превью: экран блокировки (тёмный фон) и карточка главного экрана.
struct AyahLivePreview: View {
    var settings: AyahSettings

    var body: some View {
        let lockSettings = settings.resolvedForLock()
        let lock = AyahPicker.current(settings: lockSettings, surface: .lock(AyahLayout.lockBox))
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                Text("12:47").font(.system(size: 48, weight: .semibold, design: .rounded))
                if let lock {
                    AyahLockView(text: lock.text, title: lock.title, style: lockSettings.style)
                        .frame(width: AyahLayout.lockBox.width, height: AyahLayout.lockBox.height)
                }
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(red: 0.12, green: 0.18, blue: 0.32), Color(red: 0.08, green: 0.08, blue: 0.12)], startPoint: .top, endPoint: .bottom), in: .rect(cornerRadius: 22, style: .continuous))

            let homeBox = CGSize(width: 338, height: 158)
            if let home = AyahPicker.current(settings: settings, surface: .home(homeBox, arabic: settings.showArabicOnHome)) {
                ZStack {
                    AyahHomeBackground()
                    AyahHomeCard(text: home.text, title: home.title, arabic: home.arabic, style: settings.style, arabicFont: settings.arabicFont).padding(8)
                }
                .frame(width: homeBox.width, height: homeBox.height)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.smooth, value: settings)
    }
}

#Preview {
    NavigationStack { AyahSettingsView() }
        .environment(AyahModel.shared)
}
