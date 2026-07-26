import AVFoundation
import Foundation

/// Sayfa çevirme, dokunma ve kaydırma sesleri.
///
/// `Haptics` ile aynı biçimde, statik bir enum: çağrı yerleri tek satır kalsın
/// diye hiçbir yere enjekte edilmiyor. Sesler `Resources/Sounds` altındaki
/// kısa WAV dosyaları; çalarlar önceden yüklenip saklanıyor, yoksa ilk sayfa
/// çevirişinde dosya okuma gecikmesi animasyonun ortasına denk geliyor.
@MainActor
enum SoundEffects {

    // MARK: - Sesler

    enum Effect: String, CaseIterable {
        case pageTurn1 = "page-turn-1"
        case pageTurn2 = "page-turn-2"
        case pageTurn3 = "page-turn-3"
        case tap = "page-tap"
        case tick = "tick"

        /// Efektler arka planda kalmalı; hiçbiri tam ses düzeyinde çalmıyor.
        var volume: Float {
            switch self {
            case .pageTurn1, .pageTurn2, .pageTurn3: return 0.55
            case .tap: return 0.30
            case .tick: return 0.16
            }
        }
    }

    private static let pageTurns: [Effect] = [.pageTurn1, .pageTurn2, .pageTurn3]

    // MARK: - Durum

    nonisolated static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "sounds.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "sounds.enabled") }
    }

    private static var players: [Effect: AVAudioPlayer] = [:]
    private static var didActivateSession = false
    /// Ses kaydı/çalma sürerken efektler susuyor — bkz. `suspend()`.
    private static var suspendCount = 0
    /// Aynı sayfa sesi peş peşe çalmasın diye son çalınanın sırası.
    private static var lastPageTurn = -1
    /// Kaydırıcı saniyede onlarca değer değiştirebiliyor; tıklar seyreltiliyor.
    private static var lastTickAt: TimeInterval = 0
    private static let minimumTickInterval: TimeInterval = 0.045

    // MARK: - Çağrılar

    /// Sayfa çevrilirken. Üç kağıt sesinden biri dönüşümlü çalıyor; tek ses
    /// olsaydı arka arkaya çevirmelerde makine gibi duyulurdu.
    static func pageTurn() {
        var index = Int.random(in: 0..<pageTurns.count)
        if index == lastPageTurn {
            index = (index + 1) % pageTurns.count
        }
        lastPageTurn = index
        play(pageTurns[index])
    }

    /// Bir güne, düğmeye veya karta dokunulduğunda.
    static func tap() {
        play(.tap)
    }

    /// Kaydırıcıda değer değiştikçe.
    static func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTickAt >= minimumTickInterval else { return }
        lastTickAt = now
        play(.tick)
    }

    /// Uygulama açılırken çağrılıyor: dosyaları önceden okuyup çözer.
    static func warmUp() {
        guard isEnabled else { return }
        for effect in Effect.allCases {
            _ = player(for: effect)
        }
    }

    // MARK: - Kayıt/çalma ile çakışmayı önleme

    /// Sesli günlük kaydı ya da çalması başlarken çağrılıyor.
    ///
    /// `AudioRecorder` oturumu `.playAndRecord`, `AudioPlayer` `.playback`
    /// yapıyor. Araya giren bir efekt kategoriyi `.ambient`'a çevirirse kayıt
    /// kesiliyor; o yüzden bu sürede efektler tamamen susuyor.
    static func suspend() {
        suspendCount += 1
        // Oturum kategorisi başkasına geçtiğinde bizimki artık geçerli değil.
        didActivateSession = false
    }

    static func resume() {
        suspendCount = max(0, suspendCount - 1)
    }

    // MARK: - Çalma

    private static func play(_ effect: Effect) {
        guard isEnabled, suspendCount == 0 else { return }
        guard let player = player(for: effect) else { return }

        activateSessionIfNeeded()
        player.volume = effect.volume
        player.currentTime = 0
        player.play()
    }

    private static func player(for effect: Effect) -> AVAudioPlayer? {
        if let existing = players[effect] { return existing }
        guard let url = bundle.url(forResource: effect.rawValue, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return nil
        }
        player.volume = effect.volume
        player.prepareToPlay()
        players[effect] = player
        return player
    }

    /// `.ambient` + `.mixWithOthers`: efektler zil/sessiz anahtarına uyuyor ve
    /// kullanıcının müziğini kesmiyor.
    private static func activateSessionIfNeeded() {
        guard !didActivateSession else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        didActivateSession = true
    }

    private static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}
