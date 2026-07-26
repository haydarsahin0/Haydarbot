import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    /// İki rengi doğrusal olarak karıştırır (0 = self, 1 = other).
    func mixed(with other: Color, amount: Double) -> Color {
        let t = max(0, min(1, amount))
        let a = UIColor(self).rgba
        let b = UIColor(other).rgba
        return Color(
            .sRGB,
            red: a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue: a.b + (b.b - a.b) * t,
            opacity: a.a + (b.a - a.a) * t
        )
    }
}

extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1
        )
    }
}

/// Uygulamanın renk paleti.
///
/// İki ayrı tema var, biri diğerinin ters çevrilmişi değil:
///
/// **Aydınlık** — güneşte duran krem kağıt. Zemin sıcak ve hafif dokulu,
/// kağıt neredeyse beyaz ama sarıya çalıyor, mürekkep siyah değil koyu
/// kahve. Vurgu pişmiş toprak.
///
/// **Karanlık** — gece lambası altındaki deri ciltli defter. Zemin soğuk
/// griye kaçmıyor, kahverengiye çalan çok koyu bir ton; kağıt da öyle.
/// Mürekkep saf beyaz değil sıcak krem, çünkü koyu zeminde saf beyaz
/// gözü yoruyor. Vurgu kehribar — koyunun üzerinde parlıyor.
enum Theme {

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // MARK: - Zemin (defterin üzerinde durduğu yüzey)

    static let surfaceTop = adaptive(light: 0xF6F2EB, dark: 0x181510)
    static let surfaceMid = adaptive(light: 0xEDE6DB, dark: 0x121009)
    static let surfaceBottom = adaptive(light: 0xE2D9CC, dark: 0x0B0A07)

    // MARK: - Kağıt

    static let paper = adaptive(light: 0xFFFDF8, dark: 0x241F18)
    static let paperShade = adaptive(light: 0xF7F1E6, dark: 0x1E1A14)
    static let paperEdge = adaptive(light: 0xE9DFD0, dark: 0x363025)
    static let rule = adaptive(light: 0xDED4C3, dark: 0x3B3428)

    // MARK: - Mürekkep

    static let ink = adaptive(light: 0x29221E, dark: 0xF2EADB)
    static let inkSoft = adaptive(light: 0x6C6156, dark: 0xADA08B)
    static let inkFaint = adaptive(light: 0xA59889, dark: 0x7C7160)

    // MARK: - Vurgu

    static let accent = adaptive(light: 0xB0603C, dark: 0xE59A6C)
    static let accentSoft = adaptive(light: 0xF1DFD3, dark: 0x3C2B1E)

    /// Zemin: üç duraklı, ortası hafif açık. Düz iki renk geçişinden daha
    /// derin duruyor, defterin arkasında yumuşak bir ışık varmış gibi.
    static let surface = LinearGradient(
        stops: [
            .init(color: surfaceTop, location: 0),
            .init(color: surfaceMid, location: 0.45),
            .init(color: surfaceBottom, location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Kağıdın hafif dokusu — düz beyaz yerine sırta doğru koyulaşan geçiş.
    static func paperGradient(for side: PageSide) -> LinearGradient {
        LinearGradient(
            colors: side == .left ? [paperShade, paper] : [paper, paperShade],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// Kullanıcının tema tercihi. Premium uygulamalarda beklenen bir ayar;
/// sistemi izlemek varsayılan ama zorunlu değil.
enum ThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var symbol: String {
        switch self {
        case .system: return "iphone"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var title: String {
        switch self {
        case .system: return String(localized: "Sistem")
        case .light: return String(localized: "Aydınlık")
        case .dark: return String(localized: "Karanlık")
        }
    }
}

enum PageSide {
    case left
    case right
}

/// Dokunulduğunda hafifçe içeri çöken düğme.
///
/// Sistem düğmelerinin varsayılan solma efekti bu tasarımda cansız kalıyor;
/// küçük bir ölçek değişimi dokunuşa fiziksel bir karşılık veriyor.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}
