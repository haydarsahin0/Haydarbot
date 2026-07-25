import Foundation

/// Bir güne ait günlük kaydı: serbest metin, soruların puanları ve fotoğraflar.
struct DiaryEntry: Codable, Identifiable, Equatable, Sendable {

    /// `"yyyy-MM-dd"` — diskteki kalıcı kimlik.
    var dateKey: String
    var text: String
    /// Soru kimliği -> 1...100 arası puan.
    var ratings: [String: Int]
    /// O güne eklenen fotoğrafların kimlikleri, eklenme sırasına göre.
    /// Görsellerin kendisi `PhotoStore` tarafından ayrı dosyalarda tutuluyor.
    var photoIDs: [String]
    /// O güne alınan sesli kayıtlar. Ses dosyaları `VoiceStore`'da.
    var voiceNotes: [VoiceNote]
    var createdAt: Date
    var updatedAt: Date

    var id: String { dateKey }

    init(dateKey: String,
         text: String = "",
         ratings: [String: Int] = [:],
         photoIDs: [String] = [],
         voiceNotes: [VoiceNote] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.dateKey = dateKey
        self.text = text
        self.ratings = ratings
        self.photoIDs = photoIDs
        self.voiceNotes = voiceNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Eski sürümlerde `photoIDs` yoktu. Codable'ın ürettiği çözümleyici eksik
    // anahtarda hata verdiği için elle yazılıyor; böylece güncelleme sonrası
    // kullanıcının mevcut günlüğü okunmaya devam ediyor.
    private enum CodingKeys: String, CodingKey {
        case dateKey, text, ratings, photoIDs, voiceNotes, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        ratings = try container.decodeIfPresent([String: Int].self, forKey: .ratings) ?? [:]
        photoIDs = try container.decodeIfPresent([String].self, forKey: .photoIDs) ?? []
        voiceNotes = try container.decodeIfPresent([VoiceNote].self, forKey: .voiceNotes) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ratings.isEmpty
            && photoIDs.isEmpty
            && voiceNotes.isEmpty
    }

    var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasPhotos: Bool { !photoIDs.isEmpty }
    var hasVoice: Bool { !voiceNotes.isEmpty }
}

/// Diskteki dosyanın kök yapısı. `version` ileride biçim değişirse göç için.
struct DiaryArchive: Codable, Sendable {
    var version: Int
    var entries: [DiaryEntry]

    init(version: Int = 3, entries: [DiaryEntry] = []) {
        self.version = version
        self.entries = entries
    }
}
