import UIKit

/// Dokunsal geri bildirim. Üreteçler tekrar tekrar oluşturulmasın diye saklanır;
/// `prepare()` gecikmeyi azaltır.
@MainActor
enum Haptics {

    private static let selection = UISelectionFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    nonisolated static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "haptics.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "haptics.enabled") }
    }

    /// Kaydırıcı sürüklenmeye başlamadan hemen önce çağrılır.
    static func prepare() {
        guard isEnabled else { return }
        selection.prepare()
        light.prepare()
    }

    /// Kaydırıcıda değer değiştikçe.
    static func tick() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    /// Sayfa çevrilirken kağıdın "kapanma" hissi.
    static func pageTurn() {
        guard isEnabled else { return }
        soft.impactOccurred(intensity: 0.7)
    }

    /// 1 veya 100 gibi uç değerlere gelindiğinde.
    static func edge() {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: 0.6)
    }

    static func tap() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.5)
    }

    static func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }
}
