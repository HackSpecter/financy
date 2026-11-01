import WidgetKit

/// Какие виджеты «Аята» стоят на экране — для режима заголовка «Авто».
enum AyahWidgetsState {
    static func refresh() async {
        guard let configurations = try? await WidgetCenter.shared.currentConfigurations() else { return }
        let installed = configurations.contains { $0.kind == "AyahTitleWidget" }
        guard installed != AyahSettings.inlineWidgetInstalled else { return }
        AyahSettings.inlineWidgetInstalled = installed
        WidgetCenter.shared.reloadTimelines(ofKind: "AyahLockWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "AyahTitleWidget")
    }
}
