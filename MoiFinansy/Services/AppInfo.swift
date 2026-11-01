import Foundation

/// Название приложения из настроек сборки (`APP_DISPLAY_NAME`).
nonisolated enum AppInfo {
    static let name = Bundle.main.object(forInfoDictionaryKey: "AppDisplayName") as? String ?? "Hisob"
}
