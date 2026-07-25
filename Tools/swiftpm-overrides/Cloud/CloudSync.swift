import Combine
import Foundation

/// `CloudSync`'in Swift Playgrounds sürümü için boş karşılığı.
///
/// Swift Playgrounds projelerine CloudKit yetkisi verilemiyor. Gerçek
/// `CloudSync` bu yetki olmadan `CKContainer` oluşturmaya kalkıştığında
/// uygulama daha ilk kareyi çizmeden çöküyor — bu yüzden Playgrounds
/// sürümünde yerine bu sınıf konuyor.
///
/// Arayüzü gerçeğiyle birebir aynı; uygulamanın geri kalanı hangi sürümde
/// çalıştığını bilmiyor. Yalnızca hiçbir şey yapmıyor: günlük yine cihazda
/// saklanıyor, sadece yedeklenmiyor.
///
/// Bu dosya elle düzenlenmemeli — `Tools/make-swiftpm.sh` tarafından
/// yerleştiriliyor.
@MainActor
final class CloudSync: ObservableObject {

    enum Status: Equatable {
        case disabled
        case unavailable
        case waiting
        case syncing
        case synced(Date)
        case failed(String)
    }

    @Published private(set) var status: Status = .failed("Swift Playgrounds sürümünde kapalı")
    @Published var isEnabled: Bool = false

    init(store: DiaryStore, photos: PhotoStore, voices: VoiceStore) {}

    func markChanged(day: Int) {}
    func markDeleted(day: Int) {}
    func markPhotoChanged(id: String) {}
    func markPhotoDeleted(id: String) {}
    func markVoiceChanged(id: String) {}
    func markVoiceDeleted(id: String) {}
    func uploadEverything() {}
    func syncNow() async {}
}
