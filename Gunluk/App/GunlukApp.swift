import SwiftUI

@main
@MainActor
struct GunlukApp: App {

    @StateObject private var store = DiaryStore()
    @StateObject private var photos = PhotoStore()
    @StateObject private var lock = AppLock()
    @StateObject private var reminders = Reminders()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(store)
                    .environmentObject(photos)
                    .environmentObject(lock)
                    .environmentObject(reminders)
                    // Kilitliyken defterin içeriği ekran değiştiricide de
                    // görünmesin diye gizleniyor.
                    .opacity(lock.isLocked ? 0 : 1)

                if lock.isLocked {
                    LockScreenView(lock: lock)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
            .tint(Theme.accent)
            .task {
                // Kayıtlardan silinmiş ama diskte kalmış fotoğrafları temizle.
                photos.removeOrphans(keeping: store.allPhotoIDs)
                // Hatırlatma açıksa saati her açılışta tazele; sistem
                // güncellemeleri sonrası zamanlama düşmüş olabiliyor.
                if reminders.isEnabled {
                    await reminders.apply()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                lock.applicationDidBecomeActive()
            case .background, .inactive:
                // Uygulama arka plana alınırken bekleyen yazma işini tamamla.
                store.flush()
                lock.applicationDidEnterBackground()
            @unknown default:
                store.flush()
            }
        }
    }
}
