import SwiftUI

@main
@MainActor
struct GunlukApp: App {

    @StateObject private var store: DiaryStore
    @StateObject private var photos: PhotoStore
    @StateObject private var voices: VoiceStore
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var player = AudioPlayer()
    @StateObject private var subscriptions = SubscriptionStore()
    @AppStorage("theme.preference") private var themePreference = ThemePreference.system.rawValue
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
        let voices = VoiceStore()
        let cloud = CloudSync(store: store, photos: photos, voices: voices)

        store.onDayChanged = { [weak cloud] day in cloud?.markChanged(day: day) }
        store.onDayRemoved = { [weak cloud] day in cloud?.markDeleted(day: day) }
        store.onPhotoAdded = { [weak cloud] id in cloud?.markPhotoChanged(id: id) }
        store.onPhotoRemoved = { [weak cloud] id in cloud?.markPhotoDeleted(id: id) }
        store.onVoiceAdded = { [weak cloud] id in cloud?.markVoiceChanged(id: id) }
        store.onVoiceRemoved = { [weak cloud] id in cloud?.markVoiceDeleted(id: id) }

        _store = StateObject(wrappedValue: store)
        _photos = StateObject(wrappedValue: photos)
        _voices = StateObject(wrappedValue: voices)
        _cloud = StateObject(wrappedValue: cloud)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(store)
                    .environmentObject(photos)
                    .environmentObject(voices)
                    .environmentObject(recorder)
                    .environmentObject(player)
                    .environmentObject(lock)
                    .environmentObject(reminders)
                    .environmentObject(cloud)
                    .environmentObject(subscriptions)
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
            .preferredColorScheme(
                ThemePreference(rawValue: themePreference)?.colorScheme
            )
            .task {
                // Kayıtlardan silinmiş ama diskte kalmış fotoğrafları temizle.
                photos.removeOrphans(keeping: store.allPhotoIDs)
                voices.removeOrphans(keeping: store.allVoiceIDs)
                // Ses dosyalarını önden çöz; ilk sayfa çevirişi sessiz kalmasın.
                SoundEffects.warmUp()
                // Hatırlatma açıksa saati her açılışta tazele; sistem
                // güncellemeleri sonrası zamanlama düşmüş olabiliyor.
                if reminders.isEnabled {
                    await reminders.apply()
                }
                await cloud.syncNow()
                await subscriptions.refresh()
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
                player.stop()
                lock.applicationDidEnterBackground()
            @unknown default:
                store.flush()
            }
        }
    }
}
