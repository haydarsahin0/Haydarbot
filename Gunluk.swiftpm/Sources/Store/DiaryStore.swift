import Foundation
import Combine

/// Günlük kayıtlarının tek kaynağı.
///
/// Veri tamamen cihazda, Application Support klasöründe tek bir JSON dosyasında
/// tutulur. Yazma işlemi kısa bir gecikmeyle (debounce) ve arka planda yapılır;
/// böylece kullanıcı yazarken her tuşta diske gidilmez.
@MainActor
final class DiaryStore: ObservableObject {

    /// Gün numarası -> kayıt.
    @Published private(set) var entries: [Int: DiaryEntry] = [:]
    /// Arayüzde "Kaydedildi" göstergesini sürmek için.
    @Published private(set) var saveState: SaveState = .idle

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
    }

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.haydarsahin.gunluk.persistence", qos: .utility)
    private var pendingSave: DispatchWorkItem?
    private var savedStateReset: DispatchWorkItem?
    /// Son yazmadan bu yana değişiklik oldu mu. `flush()` boşuna diske gitmesin
    /// ve değişmemiş bir kapanışta "Kaydedildi" göstergesi yanıp sönmesin diye.
    private var isDirty = false

    private static let debounceInterval: TimeInterval = 0.6

    // MARK: - Bulut bağlantısı
    //
    // Depo CloudKit'i tanımıyor; yalnızca "şu gün değişti" diye haber veriyor.
    // Böylece iCloud tamamen devre dışıyken de bu sınıf olduğu gibi çalışıyor.
    var onDayChanged: ((Int) -> Void)?
    var onDayRemoved: ((Int) -> Void)?
    var onPhotoAdded: ((String) -> Void)?
    var onPhotoRemoved: ((String) -> Void)?

    /// Buluttan gelen bir değişikliği uygularken geri çağrıları susturur;
    /// yoksa aynı kayıt sonsuza kadar ileri geri gider.
    private var isApplyingRemoteChange = false

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true))
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.fileURL = base.appendingPathComponent("gunluk-kayitlar.json")
        }
        load()
    }

    // MARK: - Okuma

    func entry(for day: Int) -> DiaryEntry? { entries[day] }

    func text(for day: Int) -> String { entries[day]?.text ?? "" }

    func rating(for day: Int, question: RatingQuestion) -> Int? {
        entries[day]?.ratings[question.id]
    }

    /// O güne dair bir şey yazılmış ya da puanlanmış mı.
    func hasContent(for day: Int) -> Bool {
        guard let entry = entries[day] else { return false }
        return !entry.isEmpty
    }

    var writtenDayCount: Int {
        entries.values.filter { !$0.isEmpty }.count
    }

    /// Geriye doğru kesintisiz yazılmış gün sayısı (bugünden ya da dünden başlayarak).
    var streak: Int {
        let today = DayIndex.today
        var day = hasContent(for: today) ? today : today - 1
        var count = 0
        while hasContent(for: day) {
            count += 1
            day -= 1
        }
        return count
    }

    // MARK: - Yazma

    func setText(_ text: String, for day: Int) {
        mutate(day: day) { entry in
            guard entry.text != text else { return false }
            entry.text = text
            return true
        }
    }

    func setRating(_ value: Int, question: RatingQuestion, for day: Int) {
        let clamped = max(1, min(100, value))
        mutate(day: day) { entry in
            guard entry.ratings[question.id] != clamped else { return false }
            entry.ratings[question.id] = clamped
            return true
        }
    }

    func addPhoto(id: String, for day: Int) {
        mutate(day: day) { entry in
            guard !entry.photoIDs.contains(id) else { return false }
            entry.photoIDs.append(id)
            return true
        }
        if !isApplyingRemoteChange { onPhotoAdded?(id) }
    }

    func removePhoto(id: String, for day: Int) {
        mutate(day: day) { entry in
            guard let index = entry.photoIDs.firstIndex(of: id) else { return false }
            entry.photoIDs.remove(at: index)
            return true
        }
        if !isApplyingRemoteChange { onPhotoRemoved?(id) }
    }

    /// Kayıtlarda geçen tüm fotoğraf kimlikleri — artık kullanılmayan
    /// dosyaları temizlemek için.
    var allPhotoIDs: Set<String> {
        Set(entries.values.flatMap { $0.photoIDs })
    }

    func removeRating(question: RatingQuestion, for day: Int) {
        mutate(day: day) { entry in
            guard entry.ratings[question.id] != nil else { return false }
            entry.ratings.removeValue(forKey: question.id)
            return true
        }
    }

    /// Ortak değiştirme yolu: kaydı oluşturur/günceller, boşalmışsa siler,
    /// değişiklik olduysa diske yazmayı planlar.
    private func mutate(day: Int, _ change: (inout DiaryEntry) -> Bool) {
        var entry = entries[day] ?? DiaryEntry(dateKey: DayIndex.key(for: day))
        guard change(&entry) else { return }
        entry.updatedAt = Date()

        if entry.isEmpty {
            entries.removeValue(forKey: day)
            if !isApplyingRemoteChange { onDayRemoved?(day) }
        } else {
            entries[day] = entry
            if !isApplyingRemoteChange { onDayChanged?(day) }
        }
        scheduleSave()
    }

    // MARK: - Kalıcılık

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let archive = try? JSONDecoder.diary.decode(DiaryArchive.self, from: data) else { return }

        var loaded: [Int: DiaryEntry] = [:]
        for entry in archive.entries {
            guard let day = DayIndex.index(forKey: entry.dateKey) else { continue }
            loaded[day] = entry
        }
        entries = loaded
    }

    private func scheduleSave() {
        isDirty = true
        saveState = .saving
        pendingSave?.cancel()

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.flush() }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceInterval, execute: work)
    }

    /// Bekleyen değişiklikleri hemen diske yazar. Uygulama arka plana alınırken çağrılır.
    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        guard isDirty else { return }
        isDirty = false

        let archive = DiaryArchive(entries: entries.values.sorted { $0.dateKey < $1.dateKey })
        let url = fileURL

        queue.async {
            var succeeded = false
            do {
                let data = try JSONEncoder.diary.encode(archive)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
                succeeded = true
            } catch {
                // Yazma başarısızsa değişiklikler bellekte duruyor; kayıt bir
                // sonraki düzenlemede yeniden denenecek.
                assertionFailure("Günlük diske yazılamadı: \(error)")
            }

            let didWrite = succeeded
            Task { @MainActor [weak self] in
                guard let self else { return }
                if didWrite {
                    self.markSaved()
                } else {
                    self.isDirty = true
                    self.saveState = .idle
                }
            }
        }
    }

    private func markSaved() {
        saveState = .saved
        savedStateReset?.cancel()

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.saveState == .saved else { return }
                self.saveState = .idle
            }
        }
        savedStateReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    // MARK: - Buluttan gelen değişiklikler

    /// iCloud'dan gelen kaydı yerelle birleştirir.
    ///
    /// Çakışmada `updatedAt` değeri yeni olan kazanıyor. Günlük için makul bir
    /// kural: aynı günü iki cihazdan aynı anda yazmak nadir, metin birleştirmek
    /// ise kullanıcıya karmaşa olarak dönüyor.
    func mergeFromCloud(_ incoming: DiaryEntry) {
        guard let day = DayIndex.index(forKey: incoming.dateKey) else { return }

        if let local = entries[day], local.updatedAt >= incoming.updatedAt {
            return
        }

        isApplyingRemoteChange = true
        defer { isApplyingRemoteChange = false }

        if incoming.isEmpty {
            entries.removeValue(forKey: day)
        } else {
            entries[day] = incoming
        }
        scheduleSave()
    }

    /// iCloud'da silinmiş bir günü yerelden de kaldırır.
    func deleteFromCloud(day: Int) {
        guard entries[day] != nil else { return }
        isApplyingRemoteChange = true
        defer { isApplyingRemoteChange = false }
        entries.removeValue(forKey: day)
        scheduleSave()
    }

    // MARK: - Grafik hesapları

    /// Verilen aralıkta o soruya verilmiş puanlar, tarihe göre sıralı.
    func trendPoints(for question: RatingQuestion, in range: TrendRange) -> [TrendPoint] {
        let today = DayIndex.today
        let start = today - range.days + 1

        return (start...today).compactMap { day in
            guard let value = entries[day]?.ratings[question.id] else { return nil }
            return TrendPoint(day: day, value: value)
        }
    }

    /// Haftanın her günü için ortalama puan. Hiç puanlanmamış günler
    /// ortalamayı aşağı çekmesin diye sayıma girmiyor.
    func weekdayAverages(for question: RatingQuestion, in range: TrendRange) -> [WeekdayAverage] {
        var totals: [Int: (sum: Int, count: Int)] = [:]

        for point in trendPoints(for: question, in: range) {
            let weekday = DayIndex.calendar.component(.weekday, from: point.date)
            let current = totals[weekday] ?? (0, 0)
            totals[weekday] = (current.sum + point.value, current.count + 1)
        }

        // Pazartesiden pazara sırala (Gregoryen takvimde 1 = Pazar).
        let order = [2, 3, 4, 5, 6, 7, 1]
        let labels = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

        return zip(order, labels).map { weekday, label in
            let entry = totals[weekday]
            let average = (entry?.count ?? 0) > 0
                ? Double(entry!.sum) / Double(entry!.count)
                : 0
            return WeekdayAverage(weekday: weekday, label: label, average: average)
        }
    }

    // MARK: - Dışa aktarma

    /// Tüm günlüğü düz metin olarak verir (paylaş sayfası için).
    func exportedText() -> String {
        let sorted = entries.values
            .filter { !$0.isEmpty }
            .sorted { $0.dateKey < $1.dateKey }

        var lines: [String] = ["Günlük", ""]
        for entry in sorted {
            guard let day = DayIndex.index(forKey: entry.dateKey) else { continue }
            lines.append(DayIndex.longDescription(day))

            for question in RatingQuestion.all {
                if let value = entry.ratings[question.id] {
                    lines.append("· \(question.shortTitle): \(value)/100")
                }
            }
            if entry.hasText {
                lines.append(entry.text)
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

private extension JSONEncoder {
    static var diary: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var diary: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
