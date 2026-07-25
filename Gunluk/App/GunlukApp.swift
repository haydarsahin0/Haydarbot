import SwiftUI

@main
@MainActor
struct GunlukApp: App {

    @StateObject private var store = DiaryStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            // Uygulama arka plana alınırken bekleyen yazma işini tamamla.
            if phase != .active {
                store.flush()
            }
        }
    }
}
