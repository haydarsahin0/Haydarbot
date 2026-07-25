import SwiftUI

/// Kullanıcıya her gün sorulan, 1-100 arası kaydırarak puanlanan sorular.
///
/// Yeni bir soru eklemek için `all` dizisine bir eleman eklemek yeterli;
/// `id` değeri kayıtlarda saklandığı için bir kez belirlendikten sonra
/// asla değiştirilmemeli.
struct RatingQuestion: Identifiable, Hashable {

    let id: String
    /// Kartın üstünde görünen soru.
    let title: String
    /// Puan seçilince görünen kısa etiket, örn. "Mutluluk".
    let shortTitle: String
    let symbol: String
    let startColor: Color
    let endColor: Color
    /// Düşük ve yüksek uçların anlamı, kaydırıcının altında görünür.
    let lowLabel: String
    let highLabel: String

    var gradient: LinearGradient {
        LinearGradient(colors: [startColor, endColor],
                       startPoint: .leading,
                       endPoint: .trailing)
    }

    /// Puana göre renk — küçük rozetlerde tek renk gerektiğinde kullanılır.
    func color(for value: Int) -> Color {
        let t = Double(max(1, min(100, value)) - 1) / 99.0
        return startColor.mixed(with: endColor, amount: t)
    }

    static let all: [RatingQuestion] = [
        RatingQuestion(
            id: "mood",
            title: "Bugün ne kadar mutluydun?",
            shortTitle: "Mutluluk",
            symbol: "sun.max.fill",
            startColor: Color(hex: 0xFFC062),
            endColor: Color(hex: 0xFF7A59),
            lowLabel: "Hiç",
            highLabel: "Çok"
        ),
        RatingQuestion(
            id: "importance",
            title: "Bugün senin için ne kadar önemliydi?",
            shortTitle: "Önem",
            symbol: "star.fill",
            startColor: Color(hex: 0xB0A2FF),
            endColor: Color(hex: 0x6C63FF),
            lowLabel: "Sıradan",
            highLabel: "Unutulmaz"
        ),
        RatingQuestion(
            id: "energy",
            title: "Enerjin nasıldı?",
            shortTitle: "Enerji",
            symbol: "bolt.fill",
            startColor: Color(hex: 0x7BE0D3),
            endColor: Color(hex: 0x2BA79A),
            lowLabel: "Tükenmiş",
            highLabel: "Zinde"
        ),
        RatingQuestion(
            id: "productivity",
            title: "Bugün ne kadar üretkendin?",
            shortTitle: "Üretkenlik",
            symbol: "checkmark.seal.fill",
            startColor: Color(hex: 0x8FCBFF),
            endColor: Color(hex: 0x3D7BFD),
            lowLabel: "Durgun",
            highLabel: "Verimli"
        )
    ]

    static func question(id: String) -> RatingQuestion? {
        all.first { $0.id == id }
    }
}
