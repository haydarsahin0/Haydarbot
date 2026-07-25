import SwiftUI

@main
@MainActor
struct GunlukApp: App {

    @StateObject private var store: DiaryStore
    @StateObject private var photos: PhotoStore
    @StateObject private var lock = AppLock()
    @StateObject private var reminders = Reminders()
    @StateObject private var cloud: CloudSync
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // CloudSync depoya ve fotoğraflara ihtiyaç duyduğu için üçü burada
        // birlikte kuruluyor; @StateObject varsayılan değerleriyle bu
        // bağımlılık kurulamıyor.
        let store = DiaryStore()
        let photos = PhotoStore()
        let cloud = CloudSync(store: store, photos: photos)

        store.onDayChanged = { [weak cloud] day in cloud?.markChanged(day: day) }
        store.onDayRemoved = { [weak cloud] day in cloud?.markDeleted(day: day) }
        store.onPhotoAdded = { [weak cloud] id in cloud?.markPhotoChanged(id: id) }
        store.onPhotoRemoved = { [weak cloud] id in cloud?.markPhotoDeleted(id: id) }

        _store = StateObject(wrappedValue: store)
        _photos = StateObject(wrappedValue: photos)
        _cloud = StateObject(wrappedValue: cloud)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(store)
                    .environmentObject(photos)
                    .environmentObject(lock)
                    .environmentObject(reminders)
                    .environmentObject(cloud)
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
                await cloud.syncNow()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                lock.applicationDidBecomeActive()
                Task { await cloud.syncNow() }
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
