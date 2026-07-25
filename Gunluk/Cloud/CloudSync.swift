import CloudKit
import Foundation
import UIKit

/// iCloud yedekleme ve cihazlar arası eşitleme.
///
/// ## Tasarım
/// Yerel JSON dosyası her zaman doğruluk kaynağı olmayı sürdürüyor. Bu sınıf
/// onun üzerine bir katman: yazılan her değişikliği iCloud'a yolluyor ve
/// iCloud'dan geleni yerele işliyor. Böylece iCloud kapalıyken, kullanıcının
/// hesabı yokken ya da ağ yokken uygulama hiç etkilenmeden çalışıyor —
/// eşitlemeye dair her hata sessizce yutuluyor, kullanıcının yazdığı asla
/// kaybolmuyor.
///
/// Değişiklik jetonlarını, yeniden denemeleri ve toplu göndermeyi iOS 17 ile
/// gelen `CKSyncEngine` üstleniyor; elle jeton yönetimi yapılmıyor.
///
/// ## Çakışma
/// Aynı gün iki cihazda düzenlenirse `updatedAt` değeri yeni olan kazanıyor.
/// Günlük için makul: aynı günü aynı anda iki telefondan yazmak nadir, ve
/// alternatifi olan metin birleştirme kullanıcıya karmaşa olarak dönüyor.
@MainActor
final class CloudSync: NSObject, ObservableObject {

    enum Status: Equatable {
        case disabled
        case waiting
        case syncing
        case synced(Date)
        case failed(String)
    }

    @Published private(set) var status: Status = .waiting
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if isEnabled {
                start()
            } else {
                engine = nil
                status = .disabled
            }
        }
    }

    private enum Keys {
        static let enabled = "cloud.enabled"
        static let state = "cloud.syncEngineState"
    }

    private enum RecordType {
        static let entry = "Entry"
        static let photo = "Photo"
    }

    private static let zoneName = "Gunluk"
    private let zoneID = CKRecordZone.ID(zoneName: CloudSync.zoneName,
                                         ownerName: CKCurrentUserDefaultName)

    private let container = CKContainer(identifier: "iCloud.com.haydarsahin.gunluk")
    private unowned let store: DiaryStore
    private unowned let photos: PhotoStore
    private var engine: CKSyncEngine?

    init(store: DiaryStore, photos: PhotoStore) {
        self.store = store
        self.photos = photos
        let enabled = UserDefaults.standard.object(forKey: Keys.enabled) as? Bool ?? true
        self.isEnabled = enabled
        super.init()

        if enabled {
            start()
        } else {
            status = .disabled
        }
    }

    // MARK: - Kurulum

    private func start() {
        guard engine == nil else { return }
        status = .waiting

        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: savedState(),
            delegate: self
        )
        configuration.automaticallySync = true
        let engine = CKSyncEngine(configuration)
        self.engine = engine

        // Kayıtlar özel bir bölgede duruyor; bölge yoksa ilk gönderim
        // başarısız olur, bu yüzden oluşturulması kuyruğa ekleniyor.
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
    }

    private func savedState() -> CKSyncEngine.State.Serialization? {
        guard let data = UserDefaults.standard.data(forKey: Keys.state) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func persist(_ serialization: CKSyncEngine.State.Serialization) {
        guard let data = try? JSONEncoder().encode(serialization) else { return }
        UserDefaults.standard.set(data, forKey: Keys.state)
    }

    // MARK: - Dışarıdan tetikleme

    /// Bir gün değiştiğinde çağrılıyor: o günün kaydı gönderim kuyruğuna giriyor.
    func markChanged(day: Int) {
        guard isEnabled, let engine else { return }
        let recordID = CKRecord.ID(recordName: DayIndex.key(for: day), zoneID: zoneID)
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }

    func markDeleted(day: Int) {
        guard isEnabled, let engine else { return }
        let recordID = CKRecord.ID(recordName: DayIndex.key(for: day), zoneID: zoneID)
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
    }

    func markPhotoChanged(id: String) {
        guard isEnabled, let engine else { return }
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }

    func markPhotoDeleted(id: String) {
        guard isEnabled, let engine else { return }
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
    }

    /// Uygulama öne geldiğinde elle bir tur eşitleme.
    func syncNow() async {
        guard isEnabled, let engine else { return }
        status = .syncing
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
            status = .synced(Date())
        } catch {
            status = .failed(Self.message(for: error))
        }
    }

    /// Henüz hiç eşitlenmemiş bir kurulumda mevcut günlüğü tamamen yükler.
    func uploadEverything() {
        guard isEnabled, let engine else { return }
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for day in store.entries.keys {
            changes.append(.saveRecord(CKRecord.ID(recordName: DayIndex.key(for: day), zoneID: zoneID)))
        }
        for photoID in store.allPhotoIDs {
            changes.append(.saveRecord(CKRecord.ID(recordName: photoID, zoneID: zoneID)))
        }
        guard !changes.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    // MARK: - Kayıt dönüşümleri

    /// Gün kaydını CKRecord'a yazar. Fotoğraflar ayrı kayıtlarda tutuluyor;
    /// tek bir kayda yığılsalardı 1 MB'lık alan sınırına takılırdı.
    private func populate(entryRecord record: CKRecord, from entry: DiaryEntry) {
        record["text"] = entry.text as CKRecordValue
        record["photoIDs"] = entry.photoIDs as CKRecordValue
        record["createdAt"] = entry.createdAt as CKRecordValue
        record["updatedAt"] = entry.updatedAt as CKRecordValue

        if let data = try? JSONEncoder().encode(entry.ratings),
           let json = String(data: data, encoding: .utf8) {
            record["ratings"] = json as CKRecordValue
        }
    }

    private func entry(from record: CKRecord) -> DiaryEntry? {
        let dateKey = record.recordID.recordName
        guard DayIndex.index(forKey: dateKey) != nil else { return nil }

        var ratings: [String: Int] = [:]
        if let json = record["ratings"] as? String,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            ratings = decoded
        }

        return DiaryEntry(
            dateKey: dateKey,
            text: record["text"] as? String ?? "",
            ratings: ratings,
            photoIDs: record["photoIDs"] as? [String] ?? [],
            createdAt: record["createdAt"] as? Date ?? Date(),
            updatedAt: record["updatedAt"] as? Date ?? Date()
        )
    }

    private func populate(photoRecord record: CKRecord, id: String) -> Bool {
        let url = photos.url(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        record["asset"] = CKAsset(fileURL: url)
        return true
    }

    /// Kaydın gün mü fotoğraf mı olduğu adından anlaşılıyor: gün kayıtları
    /// `yyyy-MM-dd`, fotoğraflar UUID.
    private func isPhotoRecordName(_ name: String) -> Bool {
        DayIndex.index(forKey: name) == nil
    }

    private static func message(for error: Error) -> String {
        guard let ckError = error as? CKError else { return "Eşitlenemedi" }
        switch ckError.code {
        case .notAuthenticated: return "iCloud hesabına giriş yapılmamış"
        case .quotaExceeded: return "iCloud alanın dolu"
        case .networkUnavailable, .networkFailure: return "Ağ yok"
        default: return "Eşitlenemedi"
        }
    }
}

// MARK: - CKSyncEngineDelegate

extension CloudSync: CKSyncEngineDelegate {

    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            await persistState(update.stateSerialization)

        case .accountChange(let change):
            await handleAccountChange(change)

        case .fetchedRecordZoneChanges(let changes):
            await apply(modifications: changes.modifications, deletions: changes.deletions)

        case .sentRecordZoneChanges(let sent):
            await handleSent(sent)

        case .willFetchChanges, .willSendChanges:
            await setStatus(.syncing)

        case .didFetchChanges, .didSendChanges:
            await setStatus(.synced(Date()))

        default:
            break
        }
    }

    nonisolated func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !pending.isEmpty else { return nil }

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            await self.record(for: recordID)
        }
    }

    // MARK: - Ana aktöre geçen yardımcılar

    private func persistState(_ serialization: CKSyncEngine.State.Serialization) {
        persist(serialization)
    }

    private func setStatus(_ new: Status) {
        // Bir hata durumunu "eşitlendi" ile üzerine yazma; kullanıcı sebebini
        // görebilsin.
        if case .failed = status, case .synced = new { return }
        status = new
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            uploadEverything()
        case .signOut, .switchAccounts:
            UserDefaults.standard.removeObject(forKey: Keys.state)
            status = .failed("iCloud hesabı değişti")
        @unknown default:
            break
        }
    }

    /// Gönderilecek kaydı üretir. Kayıt sunucudan gelen sürümün üzerine
    /// yazılacağı için `CKSyncEngine`'in verdiği hazır kayıt kullanılıyor.
    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        let name = recordID.recordName

        if isPhotoRecordName(name) {
            let record = CKRecord(recordType: RecordType.photo, recordID: recordID)
            guard populate(photoRecord: record, id: name) else { return nil }
            return record
        }

        guard let day = DayIndex.index(forKey: name),
              let entry = store.entry(for: day) else {
            // Kayıt yerelde yoksa gönderilecek bir şey de yok.
            return nil
        }
        let record = CKRecord(recordType: RecordType.entry, recordID: recordID)
        populate(entryRecord: record, from: entry)
        return record
    }

    private func apply(modifications: [CKRecord], deletions: [CKSyncEngine.Event.FetchedRecordDeletion]) {
        for record in modifications {
            if record.recordType == RecordType.photo {
                applyPhoto(record)
            } else if let incoming = entry(from: record) {
                store.mergeFromCloud(incoming)
            }
        }

        for deletion in deletions {
            let name = deletion.recordID.recordName
            if isPhotoRecordName(name) {
                photos.delete(name)
            } else if let day = DayIndex.index(forKey: name) {
                store.deleteFromCloud(day: day)
            }
        }
    }

    private func applyPhoto(_ record: CKRecord) {
        let id = record.recordID.recordName
        // Zaten diskteyse tekrar yazma; aynı kimlikli fotoğrafın içeriği
        // değişmiyor.
        guard !photos.exists(id) else { return }
        guard let asset = record["asset"] as? CKAsset,
              let sourceURL = asset.fileURL,
              let data = try? Data(contentsOf: sourceURL) else { return }
        try? data.write(to: photos.url(for: id), options: .atomic)
    }

    private func handleSent(_ sent: CKSyncEngine.Event.SentRecordZoneChanges) {
        for failure in sent.failedRecordSaves {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                // Sunucudaki sürüm daha yeni; bir sonraki çekmede işlenecek.
                continue
            case .zoneNotFound:
                // Bölge silinmiş; yeniden oluşturup her şeyi yeniden yükle.
                UserDefaults.standard.removeObject(forKey: Keys.state)
                uploadEverything()
            case .unknownItem:
                continue
            default:
                engine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }
        }
    }
}
