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

/// Uygulamanın renk paleti. Videodaki sıcak, kağıt hissi veren tonlar
/// esas alındı; karanlık mod için aynı sıcaklıkta koyu karşılıkları var.
enum Theme {

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // Arka plan (defterin durduğu yüzey)
    static let surfaceTop = adaptive(light: 0xF3EEE8, dark: 0x1C1A18)
    static let surfaceBottom = adaptive(light: 0xDCD4CA, dark: 0x100F0E)

    // Kağıt
    static let paper = adaptive(light: 0xFCFAF6, dark: 0x272320)
    static let paperShade = adaptive(light: 0xF2EEE7, dark: 0x211E1B)
    static let paperEdge = adaptive(light: 0xE6DFD4, dark: 0x322D29)
    static let rule = adaptive(light: 0xDAD2C6, dark: 0x3A342F)

    // Mürekkep
    static let ink = adaptive(light: 0x2B2622, dark: 0xEFE9E1)
    static let inkSoft = adaptive(light: 0x6E655C, dark: 0xA79E94)
    static let inkFaint = adaptive(light: 0xA79C90, dark: 0x746B62)

    // Vurgu
    static let accent = adaptive(light: 0xB4674A, dark: 0xE29070)
    static let accentSoft = adaptive(light: 0xE8D3C6, dark: 0x4A3529)

    static let surface = LinearGradient(
        colors: [surfaceTop, surfaceBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Kağıdın hafif dokusu — düz beyaz yerine üstten alta çok hafif bir geçiş.
    static func paperGradient(for side: PageSide) -> LinearGradient {
        LinearGradient(
            colors: side == .left ? [paperShade, paper] : [paper, paperShade],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

enum PageSide {
    case left
    case right
}
