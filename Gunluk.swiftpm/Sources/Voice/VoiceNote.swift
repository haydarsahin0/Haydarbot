import Foundation

/// Bir güne eklenen sesli günlük kaydı.
///
/// Sesin kendisi ayrı bir `.m4a` dosyasında; burada yalnızca kimliği, süresi
/// ve kayıt sırasında toplanan ses seviyeleri duruyor. Seviyeler sayesinde
/// kaydın dalga biçimi sonradan dosyayı çözümlemeye gerek kalmadan
/// çizilebiliyor.
struct VoiceNote: Codable, Equatable, Identifiable, Sendable {

    var id: String
    var duration: TimeInterval
    /// 0...1 aralığında, dalga çubukları için örneklenmiş ses seviyeleri.
    var waveform: [Double]
    var createdAt: Date

    init(id: String = UUID().uuidString,
         duration: TimeInterval,
         waveform: [Double] = [],
         createdAt: Date = Date()) {
        self.id = id
        self.duration = duration
        self.waveform = waveform
        self.createdAt = createdAt
    }

    /// "1:23"
    var durationText: String {
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
