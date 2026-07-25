import Foundation

/// Bir güne ait günlük kaydı: serbest metin + soruların puanları.
struct DiaryEntry: Codable, Identifiable, Equatable, Sendable {

    /// `"yyyy-MM-dd"` — diskteki kalıcı kimlik.
    var dateKey: String
    var text: String
    /// Soru kimliği -> 1...100 arası puan.
    var ratings: [String: Int]
    var createdAt: Date
    var updatedAt: Date

    var id: String { dateKey }

    init(dateKey: String,
         text: String = "",
         ratings: [String: Int] = [:],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.dateKey = dateKey
        self.text = text
        self.ratings = ratings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ratings.isEmpty
    }

    var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sorulardan kaçının puanlandığı.
    var ratedQuestionCount: Int { ratings.count }
}

/// Diskteki dosyanın kök yapısı. `version` ileride biçim değişirse göç için.
struct DiaryArchive: Codable, Sendable {
    var version: Int
    var entries: [DiaryEntry]

    init(version: Int = 1, entries: [DiaryEntry] = []) {
        self.version = version
        self.entries = entries
    }
}
