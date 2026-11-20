import SwiftUI

@main
struct PureScanApp: App {
    @StateObject private var history = HistoryStore()
    @StateObject private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(history)
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
