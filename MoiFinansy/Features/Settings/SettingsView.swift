import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var exportDocument: BackupDocument?
    @State private var showsExporter = false
    @State private var showsImporter = false
    @State private var pendingImport: BackupService.Backup?
    @State private var message: String?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Оформление") {
                    Picker("Тема", selection: $settings.appearanceRaw) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Основное") {
                    Picker("Базовая валюта", selection: $settings.currencyCode) {
                        ForEach(AppSettings.currencies, id: \.self) { Text($0).tag($0) }
                    }
                    NavigationLink { CurrencyRatesView() } label: { Label("Курсы валют", systemImage: "dollarsign.arrow.circlepath") }
                    NavigationLink { AccountsSettingsView() } label: { Label("Счета", systemImage: "wallet.bifold.fill") }
                    NavigationLink { CategoriesSettingsView() } label: { Label("Категории", systemImage: "square.grid.2x2.fill") }
                    NavigationLink { RecurringRulesView() } label: { Label("Регулярные операции", systemImage: "repeat.circle.fill") }
                    NavigationLink { TemplatesSettingsView() } label: { Label("Шаблоны", systemImage: "bolt.fill") }
                    NavigationLink { BudgetsView() } label: { Label("Бюджеты", systemImage: "gauge.with.dots.needle.67percent") }
                    NavigationLink { SavingsView() } label: { Label("Накопления и цели", systemImage: "building.columns.fill") }
                    NavigationLink { DebtsView() } label: { Label("Долги", systemImage: "person.2.fill") }
                }

                Section("Коран") {
                    NavigationLink { AyatHomeView() } label: { Label("Аяты и виджет", systemImage: "book.closed") }
                }

                Section("Автоимпорт") {
                    NavigationLink { SMSSettingsView() } label: { Label("SMS банков", systemImage: "message.badge.filled.fill") }
                }

                Section("Анализ") {
                    Toggle("Предупреждать о крупных тратах и темпе", isOn: Binding(get: { MotivationService.warningsEnabled }, set: { MotivationService.warningsEnabled = $0 }))
                    Toggle("Недельный разбор по воскресеньям", isOn: Binding(get: { MotivationService.weeklyReviewEnabled }, set: { MotivationService.weeklyReviewEnabled = $0; MotivationService.scheduleWeeklyReview() }))
                    NavigationLink { WeeklyReviewView() } label: { Label("Итоги недели", systemImage: "calendar.badge.checkmark") }
                }

                Section {
                    Toggle("Напоминать вносить расходы", isOn: $settings.dailyReminderEnabled)
                    if settings.dailyReminderEnabled {
                        DatePicker("Время", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Напоминание")
                } footer: {
                    Text("Каждый вечер: «Внеси расходы за сегодня».")
                }

                Section {
                    Toggle("Live Activity: остаток на сегодня", isOn: Binding(get: { LiveActivityService.isEnabled }, set: { LiveActivityService.isEnabled = $0; LiveActivityService.refresh() }))
                } footer: {
                    Text("Показывает «Можно потратить сегодня» на экране блокировки и в Dynamic Island.")
                }

                Section {
                    Toggle("Блокировка \(BiometricService.biometryName)", isOn: faceIDBinding)
                        .disabled(!BiometricService.isAvailable)
                    Toggle("Режим приватности", isOn: privacyBinding(\.privacyEnabled))
                    if settings.privacyEnabled {
                        Toggle("Показывать суммы по \(BiometricService.biometryName)", isOn: privacyBinding(\.privacyRequiresFaceID))
                    }
                } header: {
                    Text("Безопасность")
                } footer: {
                    Text("В режиме приватности суммы размыты, в том числе в виджетах и уведомлениях. Тап по сумме показывает их на минуту. Все данные хранятся только на устройстве.")
                }

                Section {
                    Toggle("Синхронизация iCloud", isOn: $settings.iCloudSyncEnabled)
                } footer: {
                    Text("Данные хранятся в вашем личном iCloud. Изменение вступит в силу после перезапуска приложения.")
                }

                Section("Резервная копия") {
                    Button("Экспорт в файл (JSON)", systemImage: "square.and.arrow.up", action: exportBackup)
                    Button("Импорт из файла", systemImage: "square.and.arrow.down") { showsImporter = true }
                }

                #if DEBUG
                Section("Отладка") {
                    Button("Загрузить тестовые данные за 3 месяца", systemImage: "wand.and.stars") {
                        DemoData.populate(context)
                        WidgetRefresher.reload()
                        message = "Тестовые данные добавлены"
                    }
                    Button("Показать онбординг", systemImage: "arrow.counterclockwise") {
                        settings.hasOnboarded = false
                        dismiss()
                    }
                }
                #endif

                Section {
                    LabeledContent("Версия", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .themedBackground()
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", systemImage: "checkmark") { dismiss() }
                }
            }
            .onChange(of: settings.dailyReminderEnabled) { updateReminder() }
            .onChange(of: settings.dailyReminderMinutes) { updateReminder() }
            .fileExporter(
                isPresented: $showsExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "MoiFinansy-\(Date.now.appFormatted("yyyyMMdd"))"
            ) { result in
                if case .success = result { message = "Резервная копия сохранена" }
            }
            .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .confirmationDialog(
                "Заменить все данные копией?",
                isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                titleVisibility: .visible
            ) {
                Button("Заменить", role: .destructive) { restore() }
            } message: {
                if let pendingImport {
                    Text("Операций в копии: \(pendingImport.transactions.count). Текущие данные будут удалены.")
                }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") {}
            }
        }
    }

    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { settings.faceIDEnabled },
            set: { newValue in
                Task {
                    if await BiometricService.authenticate(reason: "Подтвердите изменение блокировки") {
                        settings.faceIDEnabled = newValue
                    }
                }
            }
        )
    }

    /// Ослабить защиту сумм можно только после Face ID, если он сейчас требуется.
    private func privacyBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                guard !newValue, settings.privacyEnabled, settings.privacyRequiresFaceID else {
                    settings[keyPath: keyPath] = newValue
                    return
                }
                Task {
                    if await BiometricService.authenticate(reason: "Подтвердите отключение защиты сумм") {
                        settings[keyPath: keyPath] = newValue
                    }
                }
            }
        )
    }

    private func updateReminder() {
        if settings.dailyReminderEnabled {
            let minutes = settings.dailyReminderMinutes
            Task {
                await NotificationService.requestAuthorization()
                await NotificationService.scheduleDailyReminder(minutes: minutes)
            }
        } else {
            NotificationService.cancelDailyReminder()
        }
    }

    private func exportBackup() {
        do {
            let data = try BackupService.encode(BackupService.makeBackup(from: context))
            exportDocument = BackupDocument(data: data)
            showsExporter = true
        } catch {
            message = "Не удалось создать копию: \(error.localizedDescription)"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try BackupService.decode(Data(contentsOf: url))
        } catch {
            message = "Файл не похож на резервную копию \(AppInfo.name)"
        }
    }

    private func restore() {
        guard let backup = pendingImport else { return }
        do {
            try BackupService.restore(backup, into: context)
            settings.currencyCode = backup.currency
            message = "Данные восстановлены"
        } catch {
            message = "Ошибка восстановления: \(error.localizedDescription)"
        }
        pendingImport = nil
    }
}

#Preview {
    SettingsView()
        .modelContainer(DemoData.previewContainer)
        .environment(AppSettings.shared)
}
