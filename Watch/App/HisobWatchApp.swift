import SwiftUI

@main
struct HisobWatchApp: App {
    @State private var store = WatchStore.shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(store)
                .task { store.activate() }
        }
    }
}
