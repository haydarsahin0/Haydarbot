import Foundation
import LocalAuthentication

/// Face ID / Touch ID kilidi.
///
/// Günlük mahrem bir şey; uygulama arka plana alındığında kilitleniyor ve
/// yeniden açıldığında yüz ya da parmak izi, olmazsa cihaz şifresi isteniyor.
@MainActor
final class AppLock: ObservableObject {

    /// Ekranın kilitli olup olmadığı. `true` iken defter gösterilmiyor.
    @Published private(set) var isLocked: Bool
    @Published private(set) var lastError: String?
    /// Kimlik doğrulama isteği havada mı — üst üste iki istem açılmasın diye.
    @Published private(set) var isAuthenticating = false

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if !isEnabled {
                isLocked = false
                lastError = nil
            }
        }
    }

    private enum Keys {
        static let enabled = "lock.enabled"
    }

    /// Arka plana kısa süreliğine düşmek (bildirim merkezi, fotoğraf seçici)
    /// kilitlemesin diye tanınan süre.
    private let graceInterval: TimeInterval = 20
    private var backgroundedAt: Date?

    init() {
        let enabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        isEnabled = enabled
        isLocked = enabled
    }

    /// Cihaz Face ID / Touch ID / şifre destekliyor mu.
    var isBiometryAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Ayarlar ekranında doğru simgeyi göstermek için.
    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Cihaz şifresi"
        }
    }

    // MARK: - Yaşam döngüsü

    func applicationDidEnterBackground() {
        guard isEnabled else { return }
        backgroundedAt = Date()
    }

    func applicationDidBecomeActive() {
        guard isEnabled, !isLocked else { return }
        guard let backgroundedAt else { return }

        if Date().timeIntervalSince(backgroundedAt) > graceInterval {
            isLocked = true
        }
        self.backgroundedAt = nil
    }

    // MARK: - Kilit açma

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Vazgeç"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Cihazda ne biyometri ne şifre varsa kilit anlamsız; kullanıcıyı
            // dışarıda bırakmamak için açılıyor.
            lastError = nil
            isLocked = false
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Günlüğünü açmak için kimliğini doğrula"
            )
            if success {
                lastError = nil
                isLocked = false
            }
        } catch {
            lastError = "Kimlik doğrulanamadı"
        }
    }
}
